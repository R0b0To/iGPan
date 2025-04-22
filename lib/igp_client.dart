import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart'; // Import for debugPrint and ValueNotifier

class Account {
  final String email;
  final String password;
  final String? nickname;
  Map<String, dynamic>? fireUpData; // To store fireUp response data

  Account({required this.email, required this.password, this.nickname, this.fireUpData});

  // Factory constructor to create an Account from a JSON map
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      email: json['email'],
      password: json['password'],
      nickname: json['nickname'],
      fireUpData: json['fireUpData'], // Load existing fireUpData if available
    );
  }

  // Method to convert an Account object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'nickname': nickname,
      'fireUpData': fireUpData,
    };
  }
}

final Map<String, CookieJar> cookieJars = {};
final Map<String, Dio> dioClients = {};
String? appDocumentPath;

Future<void> initCookieManager() async {
  Directory appDocDir = await getApplicationDocumentsDirectory();
  appDocumentPath = appDocDir.path;
}

Future<void> loadAccounts(ValueNotifier<List<Account>> accountsNotifier) async {
  try {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/accounts.json');
    final jsonString = await file.readAsString();
    final List<dynamic> jsonList = jsonDecode(jsonString);
    accountsNotifier.value = jsonList.map((json) => Account.fromJson(json)).toList();
    debugPrint('Accounts loaded: ${accountsNotifier.value.length}');

    // Initialize persistent cookie jars for each account
    if (appDocumentPath != null) {
      for (var account in accountsNotifier.value) {
        cookieJars[account.email] = PersistCookieJar(
          storage: FileStorage('$appDocumentPath/.cookies/${account.email}/'),
        );
      }
    }

  } catch (e) {
    // Handle file not found or other errors
    debugPrint('Error loading accounts: $e');
  }
}

Future<void> startClientSessions(ValueNotifier<List<Account>> accountsNotifier) async {
  if (accountsNotifier.value.isNotEmpty) {
    for (var account in accountsNotifier.value) {
      // Attempt to use existing cookies first by making the fireUp request
      bool sessionValid = false;
      try {
        CookieJar? cookieJar = cookieJars[account.email];
         if (cookieJar != null) {
          Dio dio = dioClients.putIfAbsent(account.email, () {
            Dio newDio = Dio();
            newDio.interceptors.add(CookieManager(cookieJar!));
            return newDio;
          });
          final fireUpUrl = Uri.parse('https://igpmanager.com/index.php?action=fireUp&addon=igp&ajax=1&jsReply=fireUp&uwv=false&csrfName=&csrfToken=');
          final fireUpResponse = await dio.get(fireUpUrl.toString());
          final fireUpJson = jsonDecode(fireUpResponse.data);

          if (fireUpJson != null && fireUpJson['guestAccount'] == false) {
            debugPrint('Session is valid for ${account.email} using saved cookies.');
            account.fireUpData = fireUpJson; // Store fireUp data
            sessionValid = true;
          } else {
             debugPrint('Session invalid for ${account.email} based on fireUp response.');
          }
         }
      } catch (e) {
        debugPrint('Error during initial fireUp request for ${account.email}: $e. Session likely invalid.');
        // Error likely means session is not valid
      }

      if (!sessionValid) {
        debugPrint('Attempting full login for ${account.email}.');
        await login(account);
      }
    }
  }
}


Future<void> login(Account account) async {
    CookieJar? cookieJar = cookieJars[account.email];
    if (cookieJar == null) {
      debugPrint('No persistent cookie jar found for ${account.email}. Creating a new one.');
      // Fallback to a non-persistent cookie jar if persistent storage is not available
      cookieJar = CookieJar();
      cookieJars[account.email] = cookieJar; // Store it for potential future use (though not persistent)
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
      debugPrint('Response for ${account.email}: ${response.data}');
      final loginResponseJson = jsonDecode(response.data);

      if (loginResponseJson != null && loginResponseJson['status'] == 1) {
        debugPrint('Login successful for ${account.email}');
        // Make the fireUp request
        final fireUpUrl = Uri.parse('https://igpmanager.com/index.php?action=fireUp&addon=igp&ajax=1&jsReply=fireUp&uwv=false&csrfName=&csrfToken=');
        try {
          final fireUpResponse = await dio.get(
            fireUpUrl.toString(),
          );
          final fireUpJson = jsonDecode(fireUpResponse.data);
          debugPrint('is ${account.email} a guest? ${fireUpJson['guestAccount']}');
          account.fireUpData = fireUpJson; // Store fireUp data after successful login
        } catch (e) {
          debugPrint('Error making fireUp request for ${account.email}: $e');
        }
      } else {
        debugPrint('Login failed for ${account.email}. Response: ${response.data}');
        // Handle failed login, e.g., show an error message to the user
      }
    } catch (e) {
      debugPrint('Error logging in ${account.email}: $e');
    }
}