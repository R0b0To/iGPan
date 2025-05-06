import 'dart:convert';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart'; // For debugPrint, consider a dedicated logger
import 'package:path_provider/path_provider.dart'; // For appDocumentPath initialization

import '../models/account.dart';
import '../utils/data_parsers.dart'; // For parseDriversFromHtml
import '../utils/helpers.dart'; // For parseFireUpData
import 'race_service.dart';
import 'sponsor_service.dart'; // Import the new SponsorService

// Global state related to API client - consider managing this with a state management solution or DI later
List<Account> accounts = [];
final _storage = const FlutterSecureStorage();
const String _accountsKey = 'accounts';

final Map<String, CookieJar> cookieJars = {};
final Map<String, Dio> dioClients = {};
String? appDocumentPath;

// Initialize appDocumentPath once
Future<void> initializeAppDocumentPath() async {
  if (appDocumentPath == null) {
    final directory = await getApplicationDocumentsDirectory();
    appDocumentPath = directory.path;
    debugPrint("App document path initialized: $appDocumentPath");
  }
}

Future<void> loadAccounts() async {
  await initializeAppDocumentPath(); // Ensure path is initialized

  try {
    final jsonString = await _storage.read(key: _accountsKey);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      accounts = jsonList.map((json) => Account.fromJson(json)).toList();
      debugPrint('Accounts loaded: ${accounts.length}');

      if (appDocumentPath != null) {
        for (var account in accounts) {
          if (!cookieJars.containsKey(account.email)) {
            cookieJars[account.email] = PersistCookieJar(
              ignoreExpires: true, // Or false, depending on desired behavior
              storage: FileStorage('$appDocumentPath/.cookies/${account.email}/'),
            );
            debugPrint('Initialized cookie jar for ${account.email}');
          }
        }
      } else {
        debugPrint("Error: appDocumentPath is null, cannot initialize persistent cookie jars.");
      }
    }
  } catch (e) {
    debugPrint('Error loading accounts: $e');
  }
}

Future<bool> startClientSessionForAccount(Account account, {VoidCallback? onSuccess}) async {
  debugPrint('Attempting to start session for ${account.email}');
  await initializeAppDocumentPath(); // Ensure path is initialized

  bool sessionValid = false;
  try {
    CookieJar? cookieJar = cookieJars[account.email];
    if (cookieJar == null && appDocumentPath != null) {
        cookieJar = PersistCookieJar(
            ignoreExpires: true,
            storage: FileStorage('$appDocumentPath/.cookies/${account.email}/'),
        );
        cookieJars[account.email] = cookieJar;
        debugPrint('Re-initialized cookie jar for ${account.email} in startClientSession');
    } else if (cookieJar == null && appDocumentPath == null) {
        debugPrint("Error: appDocumentPath is null, cannot initialize persistent cookie jar for ${account.email}. Using in-memory.");
        cookieJar = CookieJar(); // Fallback to in-memory
        cookieJars[account.email] = cookieJar;
    }


    if (cookieJar != null) {
      Dio dio = dioClients.putIfAbsent(account.email, () {
        Dio newDio = Dio();
        newDio.interceptors.add(CookieManager(cookieJar!));
        return newDio;
      });

      final fireUpUrl = Uri.parse('https://igpmanager.com/index.php?action=fireUp&addon=igp&ajax=1&jsReply=fireUp&uwv=false&csrfName=&csrfToken=');
      final fireUpResponse = await dio.get(fireUpUrl.toString());
      
      // Assuming parseFireUpData is in helpers.dart or needs to be moved/defined
      final fireUpJson = parseFireUpData(jsonDecode(fireUpResponse.data)); 

      if (fireUpJson['guestAccount'] == false) {
        debugPrint('Session is valid for ${account.email} using saved cookies.');
        fireUpJson['drivers'] = parseDriversFromHtml(fireUpJson['preCache']['p=staff']['vars']['drivers']);
        account.fireUpData = fireUpJson;
        sessionValid = true;

        final sponsorUrl = Uri.parse('https://igpmanager.com/index.php?action=fetch&p=finances&csrfName=&csrfToken=');
        try {
          final sponsorResponse = await dio.get(sponsorUrl.toString());
          final jsonSponsorResponse = jsonDecode(sponsorResponse.data);
          // Use SponsorService to get sponsors
          fireUpJson['sponsor'] = SponsorService().getSponsors(jsonSponsorResponse, account);
        } catch (e) {
          debugPrint('Error fetching sponsors for ${account.email}: $e');
        }

        if (account.fireUpData != null &&
            account.fireUpData!['team'] != null &&
            account.fireUpData!['team']['_league'] != '0') {
          // Use RaceService to fetch race data
          await RaceService().fetchRaceData(account);
        } else {
          debugPrint('Account ${account.email} is not in a league. Skipping race data fetch.');
        }
        onSuccess?.call();
      } else {
        debugPrint('Session invalid for ${account.email} based on fireUp response.');
      }
    }
  } catch (e) {
    debugPrint('Error during initial fireUp request for ${account.email}: $e. Session likely invalid.');
  }

  if (!sessionValid) {
    debugPrint('Attempting full login for ${account.email}.');
    sessionValid = await login(account, onSuccess: onSuccess);
  }
  return sessionValid;
}

Future<bool> login(Account account, {VoidCallback? onSuccess}) async {
  await initializeAppDocumentPath(); // Ensure path is initialized

  CookieJar? cookieJar = cookieJars[account.email];
  if (cookieJar == null) {
    debugPrint('No persistent cookie jar found for ${account.email}. Creating a new one.');
    if (appDocumentPath != null) {
      cookieJar = PersistCookieJar(
          ignoreExpires: true,
          storage: FileStorage('$appDocumentPath/.cookies/${account.email}/'));
    } else {
      debugPrint("Error: appDocumentPath is null, cannot initialize persistent cookie jar for ${account.email} in login. Using in-memory.");
      cookieJar = CookieJar(); // Fallback to in-memory
    }
    cookieJars[account.email] = cookieJar;
  }

  Dio dio = dioClients.putIfAbsent(account.email, () {
    Dio newDio = Dio();
    newDio.interceptors.add(CookieManager(cookieJar!));
    return newDio;
  });

  final url = Uri.parse('https://igpmanager.com/index.php?action=send&addon=igp&type=login&jsReply=login&ajax=1');
  final loginData = {
    'loginUsername': account.email,
    'loginPassword': account.password,
    'loginRemember': 'on',
    'csrfName': '',
    'csrfToken': ''
  };

  try {
    final response = await dio.post(
      url.toString(),
      data: FormData.fromMap(loginData),
    );
    debugPrint('Login API Response for ${account.email}: ${response.data}');
    final loginResponseJson = jsonDecode(response.data);

    if (loginResponseJson != null && loginResponseJson['status'] == 1) {
      debugPrint('Login successful for ${account.email}');
      // After successful login, re-attempt session start, which includes fetching initial data
      return await startClientSessionForAccount(account, onSuccess: onSuccess);
    } else {
      debugPrint('Login failed for ${account.email}. Response: ${response.data}');
      return false;
    }
  } catch (e) {
    debugPrint('Error logging in ${account.email}: $e');
    return false;
  }
}

// Function to save accounts (e.g., after adding, deleting, or modifying enabled status)
Future<void> saveAccounts() async {
  try {
    final List<Map<String, dynamic>> jsonList = accounts.map((account) => account.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await _storage.write(key: _accountsKey, value: jsonString);
    debugPrint('Accounts saved: ${accounts.length}');
  } catch (e) {
    debugPrint('Error saving accounts: $e');
  }
}