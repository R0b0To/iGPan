import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart'; // Import for debugPrint and ValueNotifier
import 'package:html/parser.dart' as html_parser;


class Account {
  final String email;
  final String password;
  final String? nickname;
  Map<String, dynamic>? fireUpData; // To store fireUp response data
  Map<String, dynamic>? raceData; // To store race data

  Account({required this.email, required this.password, this.nickname, this.fireUpData, this.raceData});

  // Factory constructor to create an Account from a JSON map
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      email: json['email'],
      password: json['password'],
      nickname: json['nickname'],
      fireUpData: json['fireUpData'], // Load existing fireUpData if available
      raceData: json['raceData'], // Load existing raceData if available
    );
  }

  // Method to convert an Account object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'nickname': nickname,
      'fireUpData': fireUpData,
      'raceData': raceData,
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
  if (accountsNotifier.value.isEmpty) return;
  
  // Create a new list copy to work with
  final updatedAccounts = List<Account>.from(accountsNotifier.value);
  bool anyAccountUpdated = false;
  
  for (int i = 0; i < updatedAccounts.length; i++) {
    var account = updatedAccounts[i];
    // Attempt to use existing cookies first by making the fireUp request
    bool sessionValid = false;
    try {
      CookieJar? cookieJar = cookieJars[account.email];
      if (cookieJar != null) {
        Dio dio = dioClients.putIfAbsent(account.email, () {
          Dio newDio = Dio();
          newDio.interceptors.add(CookieManager(cookieJar));
          return newDio;
        });
        final fireUpUrl = Uri.parse('https://igpmanager.com/index.php?action=fireUp&addon=igp&ajax=1&jsReply=fireUp&uwv=false&csrfName=&csrfToken=');
        final fireUpResponse = await dio.get(fireUpUrl.toString());
        final fireUpJson = jsonDecode(fireUpResponse.data);
        
        if (fireUpJson != null && fireUpJson['guestAccount'] == false) {
          debugPrint('Session is valid for ${account.email} using saved cookies.');
          // Update the account in our copy
          fireUpJson['drivers'] = parseDriversFromHtml(fireUpJson['preCache']['p=staff']['vars']['drivers']);
          updatedAccounts[i].fireUpData = fireUpJson;
          anyAccountUpdated = true;
          sessionValid = true;

          // Check if the account has a team and is in a league
          if (updatedAccounts[i].fireUpData != null &&
              updatedAccounts[i].fireUpData!['team'] != null &&
              updatedAccounts[i].fireUpData!['team']['_league'] != '0') {
            debugPrint('Account ${account.email} is in a league. Fetching race data.');
            
            
            // Fetch race data for this account
            await fetchRaceData(updatedAccounts[i], accountsNotifier);
          } else {
            debugPrint('Account ${account.email} is not in a league. Skipping race data fetch.');
          }

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
      // If login modifies the account, make sure to update the copy
      await login(account);
      // If login modifies account, we need to update our copy
      updatedAccounts[i] = account;
      anyAccountUpdated = true;
    }
  }
  
  // Only update the notifier if changes were made
  if (anyAccountUpdated) {
    accountsNotifier.value = updatedAccounts;
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
Future<void> claimDailyReward(Account account, ValueNotifier<List<Account>> accountsNotifier) async {
  Dio? dio = dioClients[account.email];
  if (dio == null) {
    debugPrint('Error: Dio client not found for ${account.email}. Cannot claim daily reward.');
    throw Exception('Dio client not initialized for account');
  }

  final url = Uri.parse('https://igpmanager.com/content/misc/igp/ajax/dailyReward.php');
  debugPrint('Attempting to claim daily reward for ${account.email} at $url');

  try {
    final response = await dio.get(url.toString());
    debugPrint('Daily reward response for ${account.email}: ${response.statusCode}');
    debugPrint('Response data: ${response.data}');
    
    // Assuming a successful response means the reward was claimed
    // Remove the nDailyReward key from the account's fireUpData
    if (account.fireUpData != null &&
        account.fireUpData!.containsKey('notify') &&
        account.fireUpData!['notify'] != null &&
        account.fireUpData!['notify'].containsKey('page') &&
        account.fireUpData!['notify']['page'] != null &&
        account.fireUpData!['notify']['page'].containsKey('nDailyReward')) {
      account.fireUpData!['notify']['page'].remove('nDailyReward');
      debugPrint('Removed nDailyReward key for ${account.email}');

      // Find the account in the notifier's list and update it
      final updatedAccounts = List<Account>.from(accountsNotifier.value);
      final index = updatedAccounts.indexWhere((acc) => acc.email == account.email);
      if (index != -1) {
        updatedAccounts[index] = account;
        accountsNotifier.value = updatedAccounts; // Notify listeners
        debugPrint('Accounts notifier updated after claiming daily reward for ${account.email}');
      }
    }

  } catch (e) {
    debugPrint('Error claiming daily reward for ${account.email}: $e');
    // Re-throw the error if you want the caller (_handleDailyReward) to handle it
    rethrow;
  }
}

Future<void> fetchRaceData(Account account, ValueNotifier<List<Account>> accountsNotifier) async {
  Dio? dio = dioClients[account.email];
  if (dio == null) {
    debugPrint('Error: Dio client not found for ${account.email}. Cannot fetch race data.');
    throw Exception('Dio client not initialized for account');
  }

  final url = Uri.parse('https://igpmanager.com/index.php?action=fetch&p=race&csrfName=&csrfToken=');
  debugPrint('Attempting to fetch race data for ${account.email} at $url');

  try {
    final response = await dio.get(url.toString());
    debugPrint('Race data response status for ${account.email}: ${response.statusCode}');
    //debugPrint('Response data: ${response.data}');

    final raceDataJson = jsonDecode(response.data);

    // Update the account's raceData with the fetched data
    raceDataJson['parsedStrategy'] = extractStrategyData(raceDataJson['vars']);
    account.raceData = raceDataJson;
    debugPrint('Updated raceData for ${account.email}');

    // Find the account in the notifier's list and update it
    final updatedAccounts = List<Account>.from(accountsNotifier.value);
    final index = updatedAccounts.indexWhere((acc) => acc.email == account.email);
    if (index != -1) {
      updatedAccounts[index] = account;
      accountsNotifier.value = updatedAccounts; // Notify listeners
      debugPrint('Accounts notifier updated after fetching race data for ${account.email}');
    }

  } catch (e) {
    debugPrint('Error fetching race data for ${account.email}: $e');
    rethrow;
  }
}

class Driver {
  final String name;
  final List<dynamic> attributes;
  final String contract;
  
  Driver({required this.name, required this.attributes, required this.contract});
  
  @override
  String toString() {
    return 'Driver{name: $name, attributes: $attributes, contract: $contract}';
  }
}

List<Driver> parseDriversFromHtml(String htmlString) {
  final document = html_parser.parse(htmlString);
  final List<Driver> drivers = [];
  
  // Find driver names
  final driverNameDivs = document.querySelectorAll('.driverName');
  
  // Find driver attributes from hoverData
  final driverAttributesSpans = document.querySelectorAll('.hoverData');
  
  // Find contract info
  final contractTds = document.querySelectorAll('[id^="nDriverC"]');
  
  for (int i = 0; i < driverNameDivs.length; i++) {
    // Extract name - correctly combining first name and last name
final nameElement = driverNameDivs[i];
final nameText = nameElement.text.trim();
final nameSpan = nameElement.querySelector('.medium');


String firstName, lastName;
if (nameSpan != null) {
  lastName = nameSpan.text.trim();
  // Remove the lastName and any whitespace/newlines to get firstName
  firstName = nameText.replaceAll(lastName, '').trim();
  // Further clean up any newlines
  firstName = firstName.replaceAll('\n', '').trim();
}
else {
  // Fallback if structure isn't as expected
  final parts = nameText.split('\n');
  firstName = parts[0].trim();
  lastName = parts.length > 1 ? parts[1].trim() : '';
}

final fullName = '$firstName $lastName';
    
    // Extract attributes
    final attributesData = driverAttributesSpans[i].attributes['data-driver'] ?? '';
    final attributes = attributesData.split(',').map((attr) {
      // Convert to appropriate type (number or empty string)
      if (attr.isEmpty) return '';
      return double.tryParse(attr) ?? attr;
    }).toList();
    
    // Extract contract
    final contract = contractTds[i].text.trim();
    
    drivers.add(Driver(
      name: fullName,
      attributes: attributes,
      contract: contract
    ));
  }
  
  return drivers;
}

List<List<List<dynamic>>> extractStrategyData(Map<String, dynamic> jsonData) {
  List<List<List<dynamic>>> allStrategies = [];

  // Process first strategy (d1) - always included
  allStrategies.add(_extractStrategySet(jsonData, 'd1'));
  
  // Process second strategy (d2) if d2Pits is not 0
  if (jsonData['d2Pits'] != 0) {
    allStrategies.add(_extractStrategySet(jsonData, 'd2'));
  }
  
  return allStrategies;
}

// Helper function to extract a strategy set
List<List<dynamic>> _extractStrategySet(Map<String, dynamic> jsonData, String prefix) {
  var document = html_parser.parse(jsonData['${prefix}FuelOrLaps']);
  List<List<dynamic>> strategyData = [];
  
  for (int i = 1; i <= 5; i++) {
    var lapsInput = document.querySelector('input[name="laps$i"]');
    var fuelInput = document.querySelector('input[name="fuel$i"]');
    
    strategyData.add([
      jsonData['${prefix}s${i}Tyre'],
      lapsInput?.attributes['value'] ?? '',
      fuelInput?.attributes['value'] ?? ''
    ]);
  }
  
  return strategyData;
}