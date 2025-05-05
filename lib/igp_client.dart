import 'dart:convert';
import '../utils/helpers.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Import secure storage
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart'; 
import 'package:html/parser.dart' as html_parser;


 List<Account> accounts = []; // List to store accounts
final _storage = const FlutterSecureStorage(); // Create storage instance
final String _accountsKey = 'accounts'; // Key for storing accounts

class Account {
  final String email;
  final String password;
  final String? nickname;
  bool enabled; // Add enabled field

  Map<String, dynamic>? fireUpData; // To store fireUp response data
  Map<String, dynamic>? raceData; // To store race data

  Account({required this.email, required this.password, this.nickname, this.fireUpData, this.raceData, this.enabled = true}); // Initialize enabled to true

  // Factory constructor to create an Account from a JSON map
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      email: json['email'],
      password: json['password'],
      nickname: json['nickname'],
      fireUpData: null, // Load existing fireUpData if available
      raceData: null, // Load existing raceData if available
      enabled: json['enabled'] ?? true, // Load enabled state, default to true if not present
    );
  }

  // Method to convert an Account object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'nickname': nickname,
      'fireUpData': null,
      'raceData': null,
      'enabled': enabled, // Include enabled state in JSON
    };
  }
}



final Map<String, CookieJar> cookieJars = {};
final Map<String, Dio> dioClients = {};
String? appDocumentPath;


Future<void> loadAccounts() async {
  try {
    final jsonString = await _storage.read(key: _accountsKey);
    if (jsonString != null) {
      final List<dynamic> jsonList = jsonDecode(jsonString);
      accounts = jsonList.map((json) => Account.fromJson(json)).toList();
      debugPrint('Accounts loaded: ${accounts.length}');

      // Initialize persistent cookie jars for each account
      if (appDocumentPath != null) { // appDocumentPath is still needed for cookie jars
        for (var account in accounts) {
          cookieJars[account.email] = PersistCookieJar(
            storage: FileStorage('$appDocumentPath/.cookies/${account.email}/'),
          );
        }
      }
    }

  } catch (e) {
    // Handle errors
    debugPrint('Error loading accounts: $e');
  }
}



// Modified startClientSessionForAccount
Future<bool> startClientSessionForAccount(Account account, {VoidCallback? onSuccess}) async {
  debugPrint('Attempting to start session for ${account.email}');
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
              fireUpJson['sponsor'] = getSponsors(jsonSponsorResponse);
         }catch (e) {
          debugPrint('Error fetching sponsors: $e');
        }

        if (account.fireUpData != null &&
            account.fireUpData!['team'] != null &&
            account.fireUpData!['team']['_league'] != '0') {
          await fetchRaceData(account);
        } else {
          debugPrint('Account ${account.email} is not in a league. Skipping race data fetch.');
        }
        // *** Call onSuccess here ***
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
    // Pass onSuccess to login
    sessionValid = await login(account, onSuccess: onSuccess);
  }
  return sessionValid; // Return success status
}

// Modified login
Future<bool> login(Account account, {VoidCallback? onSuccess}) async {
    CookieJar? cookieJar = cookieJars[account.email];
    if (cookieJar == null) {
      debugPrint('No persistent cookie jar found for ${account.email}. Creating a new one.');
      // Use MemoryCookieJar if persistent path isn't available or needed here
      cookieJar = appDocumentPath != null
          ? PersistCookieJar(storage: FileStorage('$appDocumentPath/.cookies/${account.email}/'))
          : CookieJar(); // Fallback to in-memory
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
      debugPrint('Response for ${account.email}: ${response.data}');
      final loginResponseJson = jsonDecode(response.data);

      if (loginResponseJson != null && loginResponseJson['status'] == 1) {
        debugPrint('Login successful for ${account.email}');
        // After successful login, re-attempt session start, passing the callback
        // The recursive call will execute onSuccess if it succeeds
        return await startClientSessionForAccount(account, onSuccess: onSuccess);
      } else {
        debugPrint('Login failed for ${account.email}. Response: ${response.data}');
        return false; // Login failed
      }
    } catch (e) {
      debugPrint('Error logging in ${account.email}: $e');
      return false; // Login failed due to error
    }
}
Future<void> claimDailyReward(Account account) async {
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
    }

  } catch (e) {
    debugPrint('Error claiming daily reward for ${account.email}: $e');
    // Re-throw the error if you want the caller (_handleDailyReward) to handle it
    rethrow;
  }
}
Future<void> fetchRaceData(Account account) async {
  Dio? dio = dioClients[account.email];
  if (dio == null) {
    debugPrint('Error: Dio client not found for ${account.email}. Cannot fetch race data.');
    throw Exception('Dio client not initialized for account');
  }

  final url = Uri.parse('https://igpmanager.com/index.php?action=fetch&p=race&csrfName=&csrfToken=');
  

  try {
    final response = await dio.get(url.toString());
    final raceDataJson = jsonDecode(response.data);
    if(account.fireUpData?['team']?['_numCars']=='2'){
       raceDataJson['vars']['d2IgnoreAdvanced'] = raceDataJson['vars']['d2IgnoreAdvanced']=='0' ? true:false;
       final selectedPush = RegExp(r'<option\s+value="(\d+)"\s+selected>').firstMatch(raceDataJson['vars']['d2PushLevel'])?.group(1) ?? '60';
       raceDataJson['vars']['d2PushLevel'] = selectedPush;
       raceDataJson['vars']['d2RainStartDepth'] = RegExp(r'value="([^"]*)"').firstMatch(raceDataJson['vars']['d2RainStartDepth'])?.group(1) ?? '0';
       raceDataJson['vars']['d2RainStopLap'] =  RegExp(r'value="([^"]*)"').firstMatch(raceDataJson['vars']['d2RainStopLap'])?.group(1) ?? '0';
       raceDataJson['vars']['d2AdvancedFuel'] =  RegExp(r'value="([^"]*)"').firstMatch(raceDataJson['vars']['d2AdvancedFuel'])?.group(1) ?? '0';
    }
      raceDataJson['vars']['d1IgnoreAdvanced'] =  raceDataJson['vars']['d1IgnoreAdvanced']=='0' ? true:false;
      final selectedPush = RegExp(r'<option\s+value="(\d+)"\s+selected>').firstMatch(raceDataJson['vars']['d1PushLevel'])?.group(1) ?? '60';
      raceDataJson['vars']['d1PushLevel'] = selectedPush;
      raceDataJson['vars']['d1RainStartDepth'] = RegExp(r'value="([^"]*)"').firstMatch(raceDataJson['vars']['d1RainStartDepth'])?.group(1) ?? '0';
      raceDataJson['vars']['d1RainStopLap'] =  RegExp(r'value="([^"]*)"').firstMatch(raceDataJson['vars']['d1RainStopLap'])?.group(1) ?? '0';
      raceDataJson['vars']['d1AdvancedFuel'] =  RegExp(r'value="([^"]*)"').firstMatch(raceDataJson['vars']['d1AdvancedFuel'])?.group(1) ?? '0';
    // Update the account's raceData with the fetched data
    raceDataJson['parsedStrategy'] = extractStrategyData(raceDataJson['vars']);
    raceDataJson['vars']['rulesJson'] = jsonDecode(raceDataJson['vars']['rulesJson']);
    account.raceData = raceDataJson;

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

  // Method to convert a Driver object to a JSON map
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'attributes': attributes,
      'contract': contract,
    };
  }

  // Factory constructor to create a Driver from a JSON map
  factory Driver.fromJson(Map<String, dynamic> json) {
    return Driver(
      name: json['name'],
      attributes: json['attributes'],
      contract: json['contract'],
    );
  }

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
      fuelInput?.attributes['value'] ?? '',
      jsonData['${prefix}PushLevel']
    ]);
  }
  
  return strategyData;
}

Map<dynamic, dynamic> getSponsors(Map<String, dynamic> jsonSponsorResponse) {
  List<dynamic> parseSponsors(String html) {
    final document = html_parser.parse(html);
    final sponsors = [];
    
    // Loop through each sponsor table
    for (final sponsor in document.querySelectorAll("table.acp")) {
      final sponsorName = sponsor.querySelector("th")?.text.trim() ?? "";
      int sponsorNumber;
      String income;
      
      // Extract income
      final incomeSpan = sponsor.querySelector(".token-cost"); // Primary sponsor has token-cost class
      if (incomeSpan != null) {
        income = incomeSpan.text.trim();
        sponsorNumber = 1;
      } else {
        sponsorNumber = 2;
        final incomeTd = sponsor.querySelectorAll("tr")[1].querySelectorAll("td")[1];
        income = incomeTd.text.trim();
      }
      
      // Extract bonus
      final bonusTd = sponsor.querySelectorAll("tr")[2].querySelectorAll("td")[1];
      final bonus = bonusTd.text.trim();
      
      // Extract contract duration
      final contractTd = sponsor.querySelectorAll("tr")[3].querySelectorAll("td")[1];
      final contractDuration = contractTd.text.trim();
      
      sponsors.add({
        "number": sponsorNumber,
        "Sponsor": sponsorName,
        "Income": income,
        "Bonus": bonus,
        "Contract": contractDuration
      });
    }
    return sponsors;
  }
      
  final jsonData = jsonSponsorResponse['vars'];
  final emptySponsors = {'income': '0', 'bonus': '0', 'expire': '0', 'status': false};
  final sponsors = {
    's1': Map<String, dynamic>.from(emptySponsors),
    's2': Map<String, dynamic>.from(emptySponsors)
  };
  
  final sponsorsData = parseSponsors(jsonData['sponsors']);
  
  for (final sponsor in sponsorsData) {
    if (sponsor['number'] == 1) { // Primary sponsor
      sponsors['s1']?['income'] = sponsor['Income'];
      sponsors['s1']?['bonus'] = sponsor['Bonus'];
      sponsors['s1']?['expire'] = sponsor['Contract'];
      sponsors['s1']?['status'] = jsonData['s1Name'] != null && jsonData['s1Name'].toString().isNotEmpty;
    } else if (sponsor['number'] == 2) { // Secondary sponsor
      sponsors['s2']?['income'] = sponsor['Income'];
      sponsors['s2']?['bonus'] = sponsor['Bonus'];
      sponsors['s2']?['expire'] = sponsor['Contract'];
      sponsors['s2']?['status'] = jsonData['s2Name'] != null && jsonData['s2Name'].toString().isNotEmpty;
    }
  }
  
  // Check if primary sponsor is missing
  if (sponsors['s1']?['status'] == false) {
    debugPrint('Primary sponsor expired');
  }
  
  // Check if secondary sponsor is missing
  if (sponsors['s2']?['status'] == false) {
    debugPrint('Secondary sponsor expired');
  }
  
  return sponsors;
}

Future<List<dynamic>> pickSponsor(Account account,int number) async {
  Dio? dio = dioClients[account.email];
  if (dio == null) {
    debugPrint('Error: Dio client not found for ${account.email}. Cannot fetch pickSponsor data.');
    throw Exception('Dio client not initialized for account');
  }
  
  final url = Uri.parse('https://igpmanager.com/index.php?action=fetch&d=sponsor&location=$number&csrfName=&csrfToken=');

  try {
    final response = await dio.get(url.toString());
    final jsonData = jsonDecode(response.data);
  // Define parser based on number parameter
  final String parser = number == 1 ? 'span' : 'td';
  
  // Use a HTML parser library like html to parse the HTML content
  final incomeFragment = jsonData['vars']['row2'];
  final wrappedincomeHtml = html_parser.parse('<table><tr>$incomeFragment</tr></table>');
  final incomeSoup = wrappedincomeHtml.querySelectorAll(parser);
  final bonusFragment = jsonData['vars']['row3'];
  final wrappedBonusHtml = html_parser.parse('<table><tr>$bonusFragment</tr></table>');
  final bonusSoup = wrappedBonusHtml.querySelectorAll('td');
  final idFragment = jsonData['vars']['row1'];
  final wrappedIdHtml = html_parser.parse('<table><tr>$idFragment</tr></table>');
  final idSoup = wrappedIdHtml.querySelectorAll('img');
  
  // Extract the text content from the elements
  final incomeList = incomeSoup.map((element) => element.text).toList();
  final bonusList = bonusSoup.map((element) => element.text).toList();

  final idList = idSoup.map((e) {
  final src = e.attributes['src'] ?? '';
  final filename = src.split('/').last;
  final nameOnly = filename.split('.').first;
  return nameOnly;
}).toList();
  
  // Return the three lists as a single list of dynamic elements
  return [incomeList, bonusList, idList];
  } catch (e) {
    debugPrint('Error fetching race data for ${account.email}: $e');
    rethrow;
  }
}

Future<dynamic> saveSponsor(Account account, int number, String id, String income, String bonus) async {
    Dio? dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}. Cannot fetch saveSponsor data.');
      throw Exception('Dio client not initialized for account');
    }
  try {
  final signSponsor = Uri.parse("https://igpmanager.com/index.php?action=send&type=contract&enact=sign&eType=5&eId=$id&location=$number&jsReply=contract&csrfName=&csrfToken=");
  final response = await dio.get(signSponsor.toString());
  final jsonData = jsonDecode(response.data);
  final sponsorNumber = 's$number';
  account.fireUpData?['sponsor'][sponsorNumber]['income'] = income;
  account.fireUpData?['sponsor'][sponsorNumber]['bonus'] = bonus;
  account.fireUpData?['sponsor'][sponsorNumber]['expire'] = '10 race(s)';
  account.fireUpData?['sponsor'][sponsorNumber]['status'] = true;
  return jsonData;
    } catch (e) {
    debugPrint('Error saving sponsor ${account.email}: $e');
    rethrow;
  }
}

Future<dynamic> repairCar(Account account, int number, String repairType) async {
    Dio? dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}. Cannot fetch saveSponsor data.');
      throw Exception('Dio client not initialized for account');
    }
    int totalRemaining = -1;

  try {
    final numberKey = 'c${number}Id';
    final id = account.fireUpData?['preCache']['p=cars']['vars'][numberKey];

  if (repairType == 'parts') {
    final totalParts = int.tryParse(account.fireUpData?['preCache']?['p=cars']?['vars']?['totalParts']) ?? 0;
    final repairCost = int.tryParse(account.fireUpData?['preCache']?['p=cars']?['vars']?['c${number}CarBtn']) ?? 0;
    final carCondition = int.tryParse(account.fireUpData?['preCache']?['p=cars']?['vars']?['c${number}Condition']) ?? 100;
    if(repairCost <= totalParts && carCondition < 100)
    {
      final repairRequest = Uri.parse("https://igpmanager.com/index.php?action=send&type=fix&car=$id&btn=c${number}PartSwap&jsReply=fix&csrfName=&csrfToken=");
      final response = await dio.get(repairRequest.toString());
      final jsonData = jsonDecode(response.data);
      totalRemaining = (totalParts - repairCost);
      account.fireUpData?['preCache']['p=cars']['vars']['totalParts'] = totalRemaining.toString();
      account.fireUpData?['preCache']?['p=cars']?['vars']?['c${number}Condition'] = "100";
    }else {
      debugPrint('Repairing car is not possible: ${account.email}');
      return totalRemaining;
    }
    
  } else if (repairType == 'engine') {
    final totalEngines = int.tryParse(account.fireUpData?['preCache']?['p=cars']?['vars']?['totalEngines']) ?? 0;
    final numberKey = 'c${number}Engine';
    final currentEngineStatus = int.tryParse(account.fireUpData?['preCache']?['p=cars']?['vars']?[numberKey]) ?? 100;
    if (totalEngines > 0 && currentEngineStatus < 100)
    {
      final repairRequest = Uri.parse("https://igpmanager.com/index.php?action=send&type=engine&car=$id&btn=c${number}EngSwap&jsReply=fix&csrfName=&csrfToken=");
      final response = await dio.get(repairRequest.toString());
      final jsonData = jsonDecode(response.data);
      totalRemaining = (totalEngines - 1);
      account.fireUpData?['preCache']['p=cars']['vars']['totalEngines'] = totalRemaining.toString();
      account.fireUpData?['preCache']?['p=cars']?['vars']?['c${number}Engine'] = "100";
     
    }else {
      debugPrint('Replacing engine is not possible: ${account.email}');
      return totalRemaining;
    }

  }
      
  return totalRemaining;
    } catch (e) {
    debugPrint('Error repairing car ${account.email}: $e');
    rethrow;
  }
}


Future<dynamic> saveStrategy(Account account) async {
    Dio? dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}. Cannot saveStrategy data.');
      throw Exception('Dio client not initialized for account');
    }

    final url = Uri.parse('https://igpmanager.com/index.php?action=send&type=saveAll&addon=igp&ajax=1&jsReply=saveAll&csrfName=&csrfName=&csrfToken=&csrfToken=&pageId=race');
    Map<String, dynamic> d2Strategy;

    final Map<String, dynamic> d1Strategy ={
      'd1setup': {
        'race': account.raceData?['vars']['raceId'],
        'suspension': account.raceData?['vars']['d1Suspension'],
        'ride': account.raceData?['vars']['d1Ride'],
        'aerodynamics': account.raceData?['vars']['d1Aerodynamics'],
        'practiceTyre': 'SS'
       },
      'd1strategy': {
        "race":account.raceData?['vars']['raceId'],
         "dNum":"1",
         "numPits": account.raceData?['vars']['d1Pits'],
         "tyre1": account.raceData?['parsedStrategy'][0][0][0],
         "tyre2":account.raceData?['parsedStrategy'][0][1][0],
         "tyre3":account.raceData?['parsedStrategy'][0][2][0],
         "tyre4":account.raceData?['parsedStrategy'][0][3][0],
         "tyre5":account.raceData?['parsedStrategy'][0][4][0],
         "fuel1":account.raceData?['parsedStrategy'][0][0][2],
         "laps1":account.raceData?['parsedStrategy'][0][0][1],
         "fuel2":account.raceData?['parsedStrategy'][0][1][2],
         "laps2":account.raceData?['parsedStrategy'][0][1][1],
         "fuel3":account.raceData?['parsedStrategy'][0][2][2],
         "laps3":account.raceData?['parsedStrategy'][0][2][1],
         "fuel4":account.raceData?['parsedStrategy'][0][3][2],
         "laps4":account.raceData?['parsedStrategy'][0][3][1],
         "fuel5":account.raceData?['parsedStrategy'][0][4][2],
         "laps5":account.raceData?['parsedStrategy'][0][4][1],
        },
      "d1strategyAdvanced" : {
         "pushLevel":"${account.raceData?['vars']['d1PushLevel']}",
         "d1SavedStrategy":"1",
         "ignoreAdvancedStrategy":"${account.raceData?['vars']['d1IgnoreAdvanced']? '0':'1'}",
         "advancedFuel":"${account.raceData?['vars']['d1AdvancedFuel']}",
         "rainStartTyre":"${account.raceData?['vars']['d1RainStartTyre']}",
         "rainStartDepth":"${account.raceData?['vars']['d1RainStartDepth']}",
         "rainStopTyre":"${account.raceData?['vars']['d1RainStopTyre']}",
         "rainStopLap":"${account.raceData?['vars']['d1RainStopLap']}",
        }
    };
   
    // Check if using 2 cars
    if(account.raceData?['vars']['d2Pits'] != 0){
      d2Strategy ={
      'd2setup': {
        'race': account.raceData?['vars']['raceId'],
        'suspension': account.raceData?['vars']['d2Suspension'],
        'ride': account.raceData?['vars']['d2Ride'],
        'aerodynamics': account.raceData?['vars']['d2Aerodynamics'],
        'practiceTyre': 'SS'
       },
      'd2strategy': {
        "race":account.raceData?['vars']['raceId'],
         "dNum":"2",
         "numPits": account.raceData?['vars']['d2Pits'],
         "tyre1": account.raceData?['parsedStrategy'][1][0][0],
         "tyre2":account.raceData?['parsedStrategy'][1][1][0],
         "tyre3":account.raceData?['parsedStrategy'][1][2][0],
         "tyre4":account.raceData?['parsedStrategy'][1][3][0],
         "tyre5":account.raceData?['parsedStrategy'][1][4][0],
         "fuel1":account.raceData?['parsedStrategy'][1][0][2],
         "laps1":account.raceData?['parsedStrategy'][1][0][1],
         "fuel2":account.raceData?['parsedStrategy'][1][1][2],
         "laps2":account.raceData?['parsedStrategy'][1][1][1],
         "fuel3":account.raceData?['parsedStrategy'][1][2][2],
         "laps3":account.raceData?['parsedStrategy'][1][2][1],
         "fuel4":account.raceData?['parsedStrategy'][1][3][2],
         "laps4":account.raceData?['parsedStrategy'][1][3][1],
         "fuel5":account.raceData?['parsedStrategy'][1][4][2],
         "laps5":account.raceData?['parsedStrategy'][1][4][1],
        },
      "d2strategyAdvanced" : {
         "pushLevel":"${account.raceData?['vars']['d2PushLevel']}",
         "d2SavedStrategy":"1",
         "ignoreAdvancedStrategy":"${account.raceData?['vars']['d2IgnoreAdvanced']? '0':'1'}",
         "rainStartTyre":"${account.raceData?['vars']['d2RainStartTyre']}",
         "rainStartDepth":"${account.raceData?['vars']['d2RainStartDepth']}",
         "rainStopTyre":"${account.raceData?['vars']['d2RainStopTyre']}",
         "rainStopLap":"${account.raceData?['vars']['d2RainStopLap']}",
        }
    };
    }else
    {
        d2Strategy = {
      'd2setup': {
        'race': account.raceData?['vars']['raceId'],
        'suspension': '1',
        'ride': '0',
        'aerodynamics': '0',
        'practiceTyre': 'SS'
       },
      'd2strategy': {
        "race":account.raceData?['vars']['raceId'],
         "dNum":"2",
         "numPits":"0",
         "tyre1":"{{d2s1Tyre}}",
         "tyre2":"{{d2s2Tyre}}",
         "tyre3":"{{d2s3Tyre}}",
         "tyre4":"{{d2s4Tyre}}",
         "tyre5":"{{d2s5Tyre}}"
        },
      "d2strategyAdvanced" : {
         "d2SavedStrategy":"{{d2Saved}}",
         "ignoreAdvancedStrategy":"{{d2IgnoreAdvanced}}"
        }
    };
    
    final saveData = {
      'loginUsername': account.email,
      'loginPassword': account.password,
      'loginRemember': 'on',
      'csrfName': '',
      'csrfToken': ''
    };
    }
   
   if(account.raceData?['vars']['rulesJson']['refuelling'] == '0')
   {
    d1Strategy['d1strategyAdvanced']['advancedFuel'] = "${account.raceData?['vars']['d1AdvancedFuel']}";
    d2Strategy['d2strategyAdvanced']['advancedFuel'] = "${account.raceData?['vars']['d2AdvancedFuel'] ?? '0'}";
   }
    
    Map<String, dynamic> saveData = {
  ...d1Strategy,
  ...d2Strategy,
};


  try {
     final response = await dio.post(url.toString(),data: jsonEncode(saveData), );
      debugPrint('Response for ${account.email}: ${response.data}');
 
    } catch (e) {
    debugPrint('Error saving strategy ${account.email}: $e');
    rethrow;
  }
}

Future<dynamic> requestLeagueInfo(Account account) async {
    Dio? dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}. Cannot fetch saveSponsor data.');
      throw Exception('Dio client not initialized for account');
    }

  final leagueId = account.fireUpData?['team']['_league'];
  try {
  final league = Uri.parse("https://igpmanager.com/index.php?action=fetch&p=league&id=${leagueId}&csrfName=&csrfToken=");
  final response = await dio.get(league.toString());
  final jsonData = jsonDecode(response.data);
  account.fireUpData?['league'] = jsonData['vars'];
  return jsonData;
    } catch (e) {
    debugPrint('Error saving sponsor ${account.email}: $e');
    rethrow;
  }
}

Future<dynamic> requestHistoryReports(Account account, int? start, int? numResults) async {
    // Check if start and numResults are null and set default values
    start ??= 0; // Default to 0 if null
    numResults ??= 10; // Default to 10 if null
    Dio? dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}. Cannot fetch saveSponsor data.');
      throw Exception('Dio client not initialized for account');
    }

  try {
  final reports = Uri.parse("https://igpmanager.com/index.php?action=send&type=history&start=$start&numResults=$numResults&jsReply=scrollLoader&el=history&csrfName=&csrfToken=");
  final response = await dio.get(reports.toString());
  final jsonData = jsonDecode(response.data);
  final races = parseRaces(jsonData['src']);
  //account.fireUpData?['league'] = jsonData['vars'];
  return races;
    } catch (e) {
    debugPrint('Error saving sponsor ${account.email}: $e');
    rethrow;
  }
}

Future<dynamic> requestRaceReport(Account account, String id) async {

    Dio? dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}. Cannot fetch race data.');
      throw Exception('Dio client not initialized for account');
    }

  try {
  final report = Uri.parse("https://igpmanager.com/index.php?action=fetch&d=result&id=$id&tab=race&csrfName=&csrfToken=");
  final response = await dio.get(report.toString());
  final jsonData = jsonDecode(response.data);
  final races = (jsonData['vars']);
  //account.fireUpData?['league'] = jsonData['vars'];
  final parsedReport = parseRaceReport(races);
  return parsedReport;
    } catch (e) {
    debugPrint('Error requestRaceReport ${account.email}: $e');
    rethrow;
  }
}

Future<dynamic> requestDriverReport(Account account, String id) async {

    Dio? dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}. Cannot fetch race data.');
      throw Exception('Dio client not initialized for account');
    }

  try {
  final report = Uri.parse("https://igpmanager.com/index.php?action=fetch&d=resultDetail&id=$id&csrfName=&csrfToken=");
  final response = await dio.get(report.toString());
  final jsonData = jsonDecode(response.data);
  final reportRace = (jsonData['vars']);

  final parsedReport = parseDriverResult(reportRace['results']);
  return parsedReport;
    } catch (e) {
    debugPrint('Error requestRaceReport ${account.email}: $e');
    rethrow;
  }
}

Future<dynamic> requestResearch(Account account) async {
    Dio? dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}. Cannot fetch race data.');
      throw Exception('Dio client not initialized for account');
    }

  try {
  final researchCar = Uri.parse("https://igpmanager.com/index.php?action=fetch&d=research&csrfName=&csrfToken=");
  final designCar = Uri.parse('https://igpmanager.com/index.php?action=fetch&d=design&csrfName=&csrfToken=');
  final responses = await Future.wait([
  dio.get(researchCar.toString()),
  dio.get(designCar.toString()),
]);
  final responseResearch = responses[0];
  final responseDesign = responses[1];
  final jsonDataResearch = jsonDecode(responseResearch.data);
  final jsonDataDesign = jsonDecode(responseDesign.data);
  final researchResponse = (jsonDataResearch['vars']);
  final designResponse = (jsonDataDesign['vars']);
  final researchMaxEffect = (researchResponse['researchMaxEffect']).toDouble();
  final designPoints = int.tryParse(designResponse['designPts']);
  final dMax = (researchResponse['dMax']);
  final int tierFactor = (dMax == 300) ? 3 : 2;
  
  List<String> attributesRating = [
    'accelerationRating',
    'brakingRating',
    'coolingRating',
    'downforceRating',
    'fuel_economyRating',
    'handlingRating',
    'reliabilityRating',
    'tyre_economyRating',
  ];
  List<String> checks = [
    'accelerationCheck',
    'brakingCheck',
    'coolingCheck',
    'downforceCheck',
    'fuel_economyCheck',
    'handlingCheck',
    'reliabilityCheck',
    'tyre_economyCheck',
  ];
  List<String> attributes = [
    'acceleration',
    'braking',
    'cooling',
    'downforce',
    'fuel_economy',
    'handling',
    'reliability',
    'tyre_economy'
  ];
  List<String> attributesBonus = [
    'accelerationBonus',
    'brakingBonus',
    'coolingBonus',
    'downforceBonus',
    'fuel_economyBonus',
    'handlingBonus',
    'reliabilityBonus',
    'tyre_economyBonus'
  ];

  final bonusCarAttributes = attributesBonus.map((key) => (designResponse[key])).toList();
  final realCarAttributes = attributes.map((key) => int.tryParse(designResponse[key])).toList();

  List<int> teamsDesign = attributesRating.map((key) => parseBest(researchResponse[key] ?? '', tierFactor)).toList();

  List<bool> checkedDesign = checks.map((key) => isChecked(researchResponse[key] ?? '')).toList();
  
  final design = {
    "myCar":realCarAttributes,
    "bonus":bonusCarAttributes,
    "best":teamsDesign,
    "checks":checkedDesign,
    "points":designPoints,
    "maxDp":dMax,
    "maxResearch":researchMaxEffect
            };
  return design;
    } catch (e) {
    debugPrint('Error research request ${account.email}: $e');
    rethrow;
  }
}


Future<void> saveDesign(Account account, Map research, List<String> design) async {

    Dio? dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}. Cannot save design.');
      throw Exception('Dio client not initialized for account');
    }

  List<String> attributesToSave = [];
    for (int i = 0; i < research['attributes'].length; i++) {
        attributesToSave.add('&c%5B%5D=${research['attributes'][i]}');
    
    }

 
    try {
  final researchCar = Uri.parse("https://igpmanager.com/index.php?action=send&addon=igp&type=research&jsReply=research&ajax=1&researchMaxEffect=${research['maxDp']}${attributesToSave.join('')}&csrfName=&csrfToken=");
  final designCar = Uri.parse('https://igpmanager.com/index.php?action=send&addon=igp&type=design&jsReply=design&ajax=1${design.join('')}&csrfName=&csrfToken=');
  final responses = await Future.wait([
  dio.get(researchCar.toString()),
  dio.get(designCar.toString()),
  ]);
  final jsonData = jsonDecode(responses[0].data);

  
    } catch (e) {
    debugPrint('Error saving design ${account.email}: $e');
    rethrow;
  }
}

Future<Map> buyEnginesWithTokens(Account account, int cost) async {

    Dio? dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}. Cannot fetch buy engines.');
      throw Exception('Dio client not initialized for account');
    }

    Map costMap = {
      3:1,
      4:3,
      5:5
    };

  final totalTokens = int.tryParse(account.fireUpData?['manager']?['tokens'])??0;
  final enginesTotal = int.tryParse(account.fireUpData?['preCache']?['p=cars']?['vars']?['totalEngines'])??0;
  final result = {'tokens':totalTokens.toString(),'engines':enginesTotal.toString()};
  if(totalTokens>cost)
  {
  try {

    final buyEngines = Uri.parse("https://igpmanager.com/index.php?action=send&type=shop&item=engines&amount=$cost&jsReply=shop&csrfName=&csrfToken=");
    
  
    final response = await dio.get(buyEngines.toString());
 
    final jsonData = jsonDecode(response.data);

        result['engines'] = (enginesTotal+costMap[cost]).toString();
        result['tokens'] = (totalTokens-cost).toString();
        
        account.fireUpData?['preCache']?['p=cars']?['vars']?['totalEngines'] = result['engines'];
        account.fireUpData?['manager']?['tokens'] = result['tokens'];
        
        return result;
        } catch (e) {
        debugPrint('Error buying engines ${account.email}: $e');
        rethrow;
  }

  }
    return result;

}