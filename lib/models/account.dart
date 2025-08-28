import 'dart:convert';
import 'package:dio/dio.dart'; // Used for making HTTP requests.
import 'package:flutter/material.dart'; // Used for `debugPrint`.
import '../utils/data_parsers.dart'; // Utility functions for parsing data.
import '../utils/math_utils.dart';

// Represents a user account in the application.
// Contains credentials, user-specific data, and methods for interacting with the game server.
class Account {
  final String email; // User's email address, used for login.
  final String password; // User's password, used for login.
  final String? nickname; // Optional user nickname.
  bool enabled; // Flag to indicate if the account is active or disabled for automated actions.

  Map<String, dynamic>? fireUpData; // Stores data received from the initial "fireUp" server request, containing game state.
  Map<String, dynamic>? raceData; // Stores data related to the current or upcoming race.
  Dio? dioClient; // Dio HTTP client instance for this account, configured with session cookies.

  Account({
    required this.email,
    required this.password,
    this.nickname,
    this.fireUpData,
    this.raceData,
    this.enabled = true, // Accounts are enabled by default.
    this.dioClient,
  });

  // Factory constructor to create an Account instance from a JSON map (e.g., when loading from storage).
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      email: json['email'],
      password: json['password'],
      nickname: json['nickname'],
      fireUpData: null, // Runtime data, not persisted in account JSON.
      raceData: null,   // Runtime data, not persisted in account JSON.
      enabled: json['enabled'] ?? true, // Load 'enabled' state, defaulting to true if not found.
      dioClient: null, // Dio client is a runtime object, not persisted in account JSON.
    );
  }

  // Converts an Account object into a JSON map, typically for storing in local preferences.
  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'password': password,
      'nickname': nickname,
      // fireUpData and raceData are runtime data and are not serialized.
      'enabled': enabled, // Persist the 'enabled' state.
    };
  }

  // Claims the daily reward for the account.
  Future<void> claimDailyReward() async {
    Dio? dio = dioClient;
    if (dio == null) {
      throw Exception('Dio client not initialized for  Cannot claim daily reward.');
    }

    final url = Uri.parse('https://igpmanager.com/content/misc/igp/ajax/dailyReward.php');
    debugPrint('Attempting to claim daily reward for ${email} at $url');

    try {
      final response = await dio.get(url.toString());
      debugPrint('Daily reward response for ${email}: ${response.statusCode}');
      debugPrint('Response data: ${response.data}');

      // Assuming a successful response means the reward was claimed
      // Remove the nDailyReward key from the account's fireUpData
      if (fireUpData != null &&
          fireUpData!.containsKey('notify') &&
          fireUpData!['notify'] != null &&
          fireUpData!['notify'] is Map && // Ensure 'notify' is a Map
          (fireUpData!['notify'] as Map).containsKey('page') &&
          fireUpData!['notify']['page'] != null &&
          fireUpData!['notify']['page'] is Map && // Ensure 'page' is a Map
          (fireUpData!['notify']['page'] as Map).containsKey('nDailyReward')) {
        (fireUpData!['notify']['page'] as Map).remove('nDailyReward');
        debugPrint('Removed nDailyReward key for ${email}');
      }
    } catch (e) {
      debugPrint('Error claiming daily reward for ${email}: $e');
      rethrow;
    }
  }

  // Requests a list of past race reports (history) for the account.
  Future<List<Map<String, dynamic>>> requestHistoryReports({int start = 0, int numResults = 10}) async {
    Dio? dio = dioClient;
    if (dio == null) {
      throw Exception('Dio client not initialized for  Cannot request history reports.');
    }

    try {
      final reportsUrl = "https://igpmanager.com/index.php?action=send&type=history&start=$start&numResults=$numResults&jsReply=scrollLoader&el=history&csrfName=&csrfToken=";
      final response = await dio.get(reportsUrl);
      final jsonData = jsonDecode(response.data);
      
      if (jsonData != null && jsonData['src'] != null) {
        return parseRaces(jsonData['src'].toString());
      } else {
        debugPrint('Failed to parse history reports or "src" key missing for ${email}');
        return [];
      }
    } catch (e) {
      debugPrint('Error requesting history reports for ${email}: $e');
      rethrow;
    }
  }

  // Requests a detailed report for a specific past race using its ID.
  Future<Map<dynamic, dynamic>> requestRaceReport(String raceId) async {
    Dio? dio = dioClient;
    if (dio == null) {
      throw Exception('Dio client not initialized for  Cannot request race report.');
    }

    try {
      final reportUrl = "https://igpmanager.com/index.php?action=fetch&d=result&id=$raceId&tab=race&csrfName=&csrfToken=";
      final response = await dio.get(reportUrl);
      final jsonData = jsonDecode(response.data);

      if (jsonData != null && jsonData['vars'] != null) {
         return parseRaceReport(jsonData['vars'] as Map<String, dynamic>);
      } else {
        debugPrint('Failed to parse race report or "vars" key missing for race ID $raceId, account ${email}');
        return {};
      }
    } catch (e) {
      debugPrint('Error requesting race report for race ID $raceId, account ${email}: $e');
      rethrow;
    }
  }

  // Requests a detailed report for a specific driver's performance in a given race.
  Future<List<dynamic>> requestDriverReport(String raceId) async {
    Dio? dio = dioClient;
    if (dio == null) {
      throw Exception('Dio client not initialized for  Cannot request driver report.');
    }

    try {
      final reportUrl = "https://igpmanager.com/index.php?action=fetch&d=resultDetail&id=$raceId&csrfName=&csrfToken=";
      final response = await dio.get(reportUrl);
      final jsonData = jsonDecode(response.data);

      if (jsonData != null && jsonData['vars']?['results'] != null) {
        return parseDriverResult(jsonData['vars']['results'].toString());
      } else {
        debugPrint('Failed to parse driver report or "results" key missing for race ID $raceId, account ${email}');
        return [];
      }
    } catch (e) {
      debugPrint('Error requesting driver report for race ID $raceId, account ${email}: $e');
      rethrow;
    }
  }

  // Requests information about the league the account is currently in.
  Future<Map<String, dynamic>?> requestLeagueInfo() async {
    Dio? dio = dioClient;
    if (dio == null) {
      throw Exception('Dio client not initialized for  Cannot request league info.');
    }

    final leagueId = fireUpData?['team']?['_league'];
    if (leagueId == null || leagueId == '0') {
      debugPrint('Account ${email} is not in a league or league ID is invalid.');
      return null; // Not in a league or ID missing
    }

    try {
      final leagueUrl = "https://igpmanager.com/index.php?action=fetch&p=league&id=$leagueId&csrfName=&csrfToken=";
      final response = await dio.get(leagueUrl);
      final jsonData = jsonDecode(response.data);
      
      if (jsonData != null && jsonData['vars'] != null) {
        fireUpData?['league'] = jsonData['vars'];
        debugPrint('League info fetched for ${email}, league ID: $leagueId');
        return jsonData['vars'] as Map<String, dynamic>;
      } else {
        debugPrint('Failed to parse league info or "vars" key missing for ${email}');
        return null;
      }
    } catch (e) {
      debugPrint('Error requesting league info for ${email}: $e');
      rethrow;
    }
  }

  // Repairs a specified car (by number) for either parts or engine.
  Future<int> repairCar(int carNumber, String repairType) async {
    Dio? dio = dioClient;
    if (dio == null) {
      throw Exception('Dio client not initialized for  Cannot repair car.');
    }

    int totalRemaining = -1;
    final carIdKey = 'c${carNumber}Id';
    final carId = fireUpData?['preCache']?['p=cars']?['vars']?[carIdKey];

    if (carId == null) {
      debugPrint('Error: Car ID not found for car number $carNumber for account ${email}');
      return totalRemaining; // Or throw an error
    }

    try {
      if (repairType == 'parts') {
        final totalParts = int.tryParse(fireUpData?['preCache']?['p=cars']?['vars']?['totalParts']?.toString() ?? '0') ?? 0;
        final repairCost = int.tryParse(fireUpData?['preCache']?['p=cars']?['vars']?['c${carNumber}CarBtn']?.toString() ?? '0') ?? 0;
        final carCondition = int.tryParse(fireUpData?['preCache']?['p=cars']?['vars']?['c${carNumber}Condition']?.toString() ?? '100') ?? 100;

        if (repairCost <= totalParts && carCondition < 100) {
          final repairUrl = "https://igpmanager.com/index.php?action=send&type=fix&car=$carId&btn=c${carNumber}PartSwap&jsReply=fix&csrfName=&csrfToken=";
          final response = await dio.get(repairUrl);
          // final jsonData = jsonDecode(response.data); // Assuming response might be useful
          totalRemaining = totalParts - repairCost;
          fireUpData?['preCache']?['p=cars']?['vars']?['totalParts'] = totalRemaining.toString();
          fireUpData?['preCache']?['p=cars']?['vars']?['c${carNumber}Condition'] = "100";
           debugPrint('Car parts repaired for c$carNumber, ${email}. Parts remaining: $totalRemaining');
        } else {
          debugPrint('Repairing car parts not possible for c$carNumber, ${email}. Cost: $repairCost, Has: $totalParts, Condition: $carCondition');
          return totalRemaining; // Indicate no repair was made or current parts count
        }
      } else if (repairType == 'engine') {
        final totalEngines = int.tryParse(fireUpData?['preCache']?['p=cars']?['vars']?['totalEngines']?.toString() ?? '0') ?? 0;
        final engineConditionKey = 'c${carNumber}Engine';
        final currentEngineCondition = int.tryParse(fireUpData?['preCache']?['p=cars']?['vars']?[engineConditionKey]?.toString() ?? '100') ?? 100;

        if (totalEngines > 0 && currentEngineCondition < 100) {
          final repairUrl = "https://igpmanager.com/index.php?action=send&type=engine&car=$carId&btn=c${carNumber}EngSwap&jsReply=fix&csrfName=&csrfToken=";
          final response = await dio.get(repairUrl);
          // final jsonData = jsonDecode(response.data); // Assuming response might be useful
          totalRemaining = totalEngines - 1;
          fireUpData?['preCache']?['p=cars']?['vars']?['totalEngines'] = totalRemaining.toString();
          fireUpData?['preCache']?['p=cars']?['vars']?[engineConditionKey] = "100";
          debugPrint('Car engine replaced for c$carNumber, ${email}. Engines remaining: $totalRemaining');
        } else {
          debugPrint('Replacing engine not possible for c$carNumber, ${email}. Has: $totalEngines, Condition: $currentEngineCondition');
           return totalRemaining; // Indicate no repair or current engine count
        }
      }
      return totalRemaining;
    } catch (e) {
      debugPrint('Error repairing car $carNumber (${repairType}) for ${email}: $e');
      rethrow;
    }
  }

  // Requests current research and design data for the account's car.
  Future<Map<String, dynamic>> requestResearch() async {
    Dio? dio = dioClient;
    if (dio == null) {
      throw Exception('Dio client not initialized for  Cannot request research data.');
    }

    try {
      final researchCarUrl = "https://igpmanager.com/index.php?action=fetch&d=research&csrfName=&csrfToken=";
      final designCarUrl = 'https://igpmanager.com/index.php?action=fetch&d=design&csrfName=&csrfToken=';
      
      final responses = await Future.wait([
        dio.get(researchCarUrl),
        dio.get(designCarUrl),
      ]);

      final jsonDataResearch = jsonDecode(responses[0].data);
      final jsonDataDesign = jsonDecode(responses[1].data);
      final researchResponseVars = jsonDataResearch['vars'];
      final designResponseVars = jsonDataDesign['vars'];

      final double researchMaxEffect = (researchResponseVars['researchMaxEffect'] as num?)?.toDouble() ?? 0.0;
      final int? designPoints = int.tryParse(designResponseVars['designPts']?.toString() ?? '');
      final int dMax = (researchResponseVars['dMax'] as num?)?.toInt() ?? 0;
      final int tierFactor = (dMax == 300) ? 3 : 2; // Example logic, adjust as needed

      List<String> attributesRatingKeys = ['accelerationRating', 'brakingRating', 'coolingRating', 'downforceRating', 'fuel_economyRating', 'handlingRating', 'reliabilityRating', 'tyre_economyRating'];
      List<String> checksKeys = ['accelerationCheck', 'brakingCheck', 'coolingCheck', 'downforceCheck', 'fuel_economyCheck', 'handlingCheck', 'reliabilityCheck', 'tyre_economyCheck'];
      List<String> attributesKeys = ['acceleration', 'braking', 'cooling', 'downforce', 'fuel_economy', 'handling', 'reliability', 'tyre_economy'];
      List<String> attributesBonusKeys = ['accelerationBonus', 'brakingBonus', 'coolingBonus', 'downforceBonus', 'fuel_economyBonus', 'handlingBonus', 'reliabilityBonus', 'tyre_economyBonus'];

      final bonusCarAttributes = attributesBonusKeys.map((key) => designResponseVars[key]?.toString() ?? '0').toList(); // Assuming bonus is string like "0.0"
      final realCarAttributes = attributesKeys.map((key) => int.tryParse(designResponseVars[key]?.toString() ?? '0') ?? 0).toList();
      
      List<int> teamsDesign = attributesRatingKeys.map((key) {
        // Use the parseBest function from data_parsers.dart
        final htmlString = researchResponseVars[key]?.toString() ?? '';
        return parseBest(htmlString, tierFactor);
      }).toList();

      List<bool> checkedDesign = checksKeys.map((key) {
        // Simplified parser for 'checked' status (can be moved to data_parsers.dart if needed elsewhere)
        return (researchResponseVars[key]?.toString() ?? '').contains('checked');
      }).toList();
      
      return {
        "myCar": realCarAttributes,
        "bonus": bonusCarAttributes,
        "best": teamsDesign,
        "checks": checkedDesign,
        "points": designPoints,
        "maxDp": dMax,
        "maxResearch": researchMaxEffect
      };
    } catch (e) {
      debugPrint('Error in research request for ${email}: $e');
      rethrow;
    }
  }

  // Saves the car's research and design settings.
  Future<void> saveDesign(Map<String, dynamic> researchSettings, List<String> designParams) async {
    Dio? dio = dioClient;
    if (dio == null) {
      throw Exception('Dio client not initialized for  Cannot save design.');
    }

    // researchSettings expected to have 'attributes' (List<String>) and 'maxDp' (dynamic)
    List<String> attributesToSaveQuery = (researchSettings['attributes'] as List<dynamic>? ?? [])
        .map((attr) => '&c%5B%5D=${Uri.encodeComponent(attr.toString())}')
        .toList();
    
    final String researchMaxEffectParam = researchSettings['maxDp']?.toString() ?? '';

    try {
      final researchCarUrl = "https://igpmanager.com/index.php?action=send&addon=igp&type=research&jsReply=research&ajax=1&researchMaxEffect=$researchMaxEffectParam${attributesToSaveQuery.join('')}&csrfName=&csrfToken=";
      final designCarUrl = 'https://igpmanager.com/index.php?action=send&addon=igp&type=design&jsReply=design&ajax=1${designParams.join('')}&csrfName=&csrfToken=';

      await Future.wait([
        dio.get(researchCarUrl),
        dio.get(designCarUrl),
      ]);
      // final jsonDataResearch = jsonDecode(responses[0].data); // If response data is needed
      debugPrint('Design and research saved for ${email}');
    } catch (e) {
      debugPrint('Error saving design for ${email}: $e');
      rethrow;
    }
  }

  // Buys a specified number of engines using account tokens.
  Future<Map<String, String>> buyEnginesWithTokens(int tokenCost) async {
    Dio? dio = dioClient;
    if (dio == null) {
      throw Exception('Dio client not initialized for  Cannot buy engines.');
    }

    Map<int, int> costToAmountMap = {3: 1, 4: 3, 5: 5}; // tokenCost to engineAmount
    final int enginesToBuy = costToAmountMap[tokenCost] ?? 0;

    if (enginesToBuy == 0) {
      debugPrint('Invalid token cost for buying engines: $tokenCost for ${email}');
      return {
        'tokens': fireUpData?['manager']?['tokens']?.toString() ?? '0',
        'engines': fireUpData?['preCache']?['p=cars']?['vars']?['totalEngines']?.toString() ?? '0'
      };
    }

    final currentTokens = int.tryParse(fireUpData?['manager']?['tokens']?.toString() ?? '0') ?? 0;
    final currentEngines = int.tryParse(fireUpData?['preCache']?['p=cars']?['vars']?['totalEngines']?.toString() ?? '0') ?? 0;
    
    Map<String, String> result = {'tokens': currentTokens.toString(), 'engines': currentEngines.toString()};

    if (currentTokens >= tokenCost) {
      try {
        final buyEnginesUrl = "https://igpmanager.com/index.php?action=send&type=shop&item=engines&amount=$enginesToBuy&jsReply=shop&csrfName=&csrfToken=";
        final response = await dio.get(buyEnginesUrl);
        // final jsonData = jsonDecode(response.data); // If response data is needed

        result['engines'] = (currentEngines + enginesToBuy).toString();
        result['tokens'] = (currentTokens - tokenCost).toString();
        
        fireUpData?['preCache']?['p=cars']?['vars']?['totalEngines'] = result['engines'];
        fireUpData?['manager']?['tokens'] = result['tokens'];
        
        debugPrint('Engines bought for ${email}. New totals - Engines: ${result['engines']}, Tokens: ${result['tokens']}');
        return result;
      } catch (e) {
        debugPrint('Error buying engines for ${email}: $e');
        rethrow;
      }
    } else {
      debugPrint('Not enough tokens to buy engines for ${email}. Has: $currentTokens, Needs: $tokenCost');
      return result; // Return current state if not enough tokens
    }
  }

  // Simulates a practice lap for a given car and tyre compound.
  Future<Map<String, dynamic>> simulatePracticeLap(int carIndex, String tyre) async {
    Dio? dio = dioClient;
    if (dio == null) {
      throw Exception('Dio client not initialized for  Cannot simulate practice lap.');
    }

    String skey = 'd${carIndex + 1}Suspension';
    String rkey = 'd${carIndex + 1}Ride';
    String akey = 'd${carIndex + 1}Aerodynamics';

    final url = "https://igpmanager.com/index.php?action=send&addon=igp&type=setup&dNum=${carIndex+1}&ajax=1&race=${raceData?['vars']['raceId']}&suspension=${raceData?['vars']?[skey]}&ride=${raceData?['vars']?[rkey]}&aerodynamics=${raceData?['vars']?[akey]}&practiceTyre=$tyre&csrfName=&csrfToken=";

    debugPrint('Simulating practice lap for ${email}, car ${carIndex + 1}, tyre $tyre. URL: $url');

    try {
      final response = await dio.get(url);
      debugPrint('Practice lap simulation response for ${email}: ${response.data}');

      final responseData = jsonDecode(response.data);
      final lapId = responseData['lapId'];

      if (lapId != null) {
        // Wait for 3 seconds
        await Future.delayed(Duration(seconds: 3));

        final practiceLapUrl = "https://igpmanager.com/index.php?action=fetch&type=lapTime&lapId=$lapId&dNum=${carIndex + 1}&addon=igp&ajax=1&jsReply=lapTime&csrfName=&csrfToken=";

        debugPrint('Fetching practice lap time for ${email}, lapId $lapId. URL: $practiceLapUrl');

        final practiceLapResponse = await dio.get(practiceLapUrl);
        debugPrint('Practice lap time response for ${email}: ${practiceLapResponse.data}');

        final lapData = jsonDecode(practiceLapResponse.data);

        // Extract the required data
        final lapTyre = lapData['lapTyre'];
        final lapFuel = lapData['lapFuel'];
        final hasMoreLaps = lapData['hasMoreLaps'];
        final comments = lapData['comments'];
        final lapTime = lapData['lapTime'];

        // Return the extracted data
        return {
          'lapTyre': lapTyre,
          'lapFuel': lapFuel,
          'hasMoreLaps': hasMoreLaps,
          'comments': comments,
          'lapTime': lapTime,
        };
      } else {
        debugPrint('lapId not found in the first response for ${email}');
        return {}; // Return empty map if lapId is not found
      }
    } catch (e) {
      debugPrint('Error simulating practice lap for ${email}: $e');
      rethrow;
    }
  }

  // Helper method to extract a value from an HTML string using a regex.
  String _extractValueFromHtmlString(String? html, RegExp regex, String defaultValue) {
    if (html == null || html.isEmpty) {
      return defaultValue;
    }
    return regex.firstMatch(html)?.group(1) ?? defaultValue;
  }

  // Fetches the main race data, including setup, strategy, and rules.
  Future<void> fetchRaceData() async {
    Dio? dio = dioClient;
    if (dio == null) {
      throw Exception('Dio client not initialized for  Cannot fetch race data.');
    }

    final url = Uri.parse('https://igpmanager.com/index.php?action=fetch&p=race&csrfName=&csrfToken=');

    try {
      final response = await dio.get(url.toString());
      final raceDataJson = jsonDecode(response.data);

      // Parse and normalize data for the second car (d2) if it exists.
      if (fireUpData?['team']?['_numCars'] == '2') {
        // d2IgnoreAdvanced is '0' for true (ignore) and '1' for false (use). Convert to boolean.
        raceDataJson['vars']['d2IgnoreAdvanced'] = raceDataJson['vars']['d2IgnoreAdvanced'] == '0' ? true : false;
        // d2PushLevel is an HTML select. Regex extracts the 'value' of the 'selected' <option>.
        raceDataJson['vars']['d2PushLevel'] = _extractValueFromHtmlString(
            raceDataJson['vars']['d2PushLevel'], RegExp(r'<option\s+value="(\d+)"\s+selected>'), '60');
        // d2RainStartDepth is an HTML input. Regex extracts the 'value' attribute.
        raceDataJson['vars']['d2RainStartDepth'] = _extractValueFromHtmlString(
            raceDataJson['vars']['d2RainStartDepth'], RegExp(r'value="([^"]*)"'), '0');
        // d2RainStopLap is an HTML input. Regex extracts the 'value' attribute.
        raceDataJson['vars']['d2RainStopLap'] = _extractValueFromHtmlString(
            raceDataJson['vars']['d2RainStopLap'], RegExp(r'value="([^"]*)"'), '0');
        // d2AdvancedFuel is an HTML input. Regex extracts the 'value' attribute.
        raceDataJson['vars']['d2AdvancedFuel'] = _extractValueFromHtmlString(
            raceDataJson['vars']['d2AdvancedFuel'], RegExp(r'value="([^"]*)"'), '0');
      }

      // Parse and normalize data for the first car (d1).
      // d1IgnoreAdvanced is '0' for true (ignore) and '1' for false (use). Convert to boolean.
      raceDataJson['vars']['d1IgnoreAdvanced'] = raceDataJson['vars']['d1IgnoreAdvanced'] == '0' ? true : false;
      // d1PushLevel is an HTML select. Regex extracts the 'value' of the 'selected' <option>.
      raceDataJson['vars']['d1PushLevel'] = _extractValueFromHtmlString(
          raceDataJson['vars']['d1PushLevel'], RegExp(r'<option\s+value="(\d+)"\s+selected>'), '60');
      // d1RainStartDepth is an HTML input. Regex extracts the 'value' attribute.
      raceDataJson['vars']['d1RainStartDepth'] = _extractValueFromHtmlString(
          raceDataJson['vars']['d1RainStartDepth'], RegExp(r'value="([^"]*)"'), '0');
      // d1RainStopLap is an HTML input. Regex extracts the 'value' attribute.
      raceDataJson['vars']['d1RainStopLap'] = _extractValueFromHtmlString(
          raceDataJson['vars']['d1RainStopLap'], RegExp(r'value="([^"]*)"'), '0');
      // d1AdvancedFuel is an HTML input. Regex extracts the 'value' attribute.
      raceDataJson['vars']['d1AdvancedFuel'] = _extractValueFromHtmlString(
          raceDataJson['vars']['d1AdvancedFuel'], RegExp(r'value="([^"]*)"'), '0');

      // Call `extractStrategyData` to parse tyre, laps, and fuel information for each stint
      // from HTML embedded within `raceDataJson['vars']`. This makes strategy data more accessible.
      raceDataJson['parsedStrategy'] = extractStrategyData(
          raceDataJson['vars'],
          raceDataJson['vars']['d1PushLevel'], // Pass d1's push level.
          fireUpData?['team']?['_numCars'] == '2' ? raceDataJson['vars']['d2PushLevel'] : null // Pass d2's push level if 2 cars.
      );

      // The `rulesJson` field might come as a JSON string. If so, parse it into a Map.
      // This contains race rules like refuelling allowance, tyre compounds, etc.
      if (raceDataJson['vars']['rulesJson'] is String) {
        raceDataJson['vars']['rulesJson'] = jsonDecode(raceDataJson['vars']['rulesJson']);
      }
      
      final raceNameHtml = raceDataJson?['vars']?['raceName'] as String?;
                        final RegExp regExp = RegExp(r'class="[^"]*f-([a-z]{2})[^"]*"');
                        final Match? match = regExp.firstMatch(raceNameHtml ?? '');
                        final String countryCode = match?.group(1)?.toUpperCase() ?? '';
      raceDataJson['trackCode'] = countryCode; // Extracted country code
      // Store the processed race data in the account instance.
      raceData = raceDataJson;
      debugPrint('Race data fetched for ${email}');
    } catch (e) {
      debugPrint('Error fetching race data for ${email}: $e');
      rethrow;
    }
  }

  // Saves the current race strategy (setup, stints, advanced options) to the server.
  Future<void> saveStrategy() async {
    Dio? dio = dioClient;
    if (dio == null) {
      throw Exception('Dio client not initialized for  Cannot save strategy.');
    }

    final url = Uri.parse('https://igpmanager.com/index.php?action=send&type=saveAll&addon=igp&ajax=1&jsReply=saveAll&csrfName=&csrfName=&csrfToken=&csrfToken=&pageId=race');
    
    // Construct the payload for saving the strategy.
    // This involves multiple parts for each car: setup, basic strategy (stints), and advanced strategy options.

    // Strategy data for the first car (d1).
    Map<String, dynamic> d1Strategy = {
      // 'd1setup': Contains car setup parameters like suspension, ride height, aerodynamics.
      'd1setup': {
        'race': raceData?['vars']['raceId'], // ID of the current race.
        'suspension': raceData?['vars']['d1Suspension'], // Suspension setting.
        'ride': raceData?['vars']['d1Ride'], // Ride height setting.
        'aerodynamics': raceData?['vars']['d1Aerodynamics'], // Aerodynamics setting.
        'practiceTyre': 'SS' // Default practice tyre, actual value may vary or not be critical for save.
      },
      // 'd1strategy': Contains the basic stint plan: number of pits, and for each stint (1-5), the tyre, laps, and fuel.
      'd1strategy': {
        "race": raceData?['vars']['raceId'], // Race ID.
        "dNum": "1", // Driver number (1 for the first car).
        "numPits": raceData?['vars']['d1Pits'], // Total number of pit stops.
        "tyre1": raceData?['parsedStrategy']?[0]?[0]?[0], // Tyre for stint 1.
        "laps1": raceData?['parsedStrategy']?[0]?[0]?[1], // Laps for stint 1.
        "fuel1": raceData?['parsedStrategy']?[0]?[0]?[2], // Fuel for stint 1.
        "tyre2": raceData?['parsedStrategy']?[0]?[1]?[0], // Tyre for stint 2.
        "laps2": raceData?['parsedStrategy']?[0]?[1]?[1], // Laps for stint 2.
        "fuel2": raceData?['parsedStrategy']?[0]?[1]?[2], // Fuel for stint 2.
        "tyre3": raceData?['parsedStrategy']?[0]?[2]?[0], // Tyre for stint 3.
        "laps3": raceData?['parsedStrategy']?[0]?[2]?[1], // Laps for stint 3.
        "fuel3": raceData?['parsedStrategy']?[0]?[2]?[2], // Fuel for stint 3.
        "tyre4": raceData?['parsedStrategy']?[0]?[3]?[0], // Tyre for stint 4.
        "laps4": raceData?['parsedStrategy']?[0]?[3]?[1], // Laps for stint 4.
        "fuel4": raceData?['parsedStrategy']?[0]?[3]?[2], // Fuel for stint 4.
        "tyre5": raceData?['parsedStrategy']?[0]?[4]?[0], // Tyre for stint 5.
        "laps5": raceData?['parsedStrategy']?[0]?[4]?[1], // Laps for stint 5.
        "fuel5": raceData?['parsedStrategy']?[0]?[4]?[2], // Fuel for stint 5.
      },
      // 'd1strategyAdvanced': Contains advanced options like push level, whether to ignore advanced settings,
      // fuel for fixed refuelling races, and rain strategy parameters.
      "d1strategyAdvanced": {
        "pushLevel": "${raceData?['vars']['d1PushLevel']}", // Driver's push level (aggression).
        "d1SavedStrategy": "1", // Flag indicating a strategy is saved. "1" usually means true/saved.
        "ignoreAdvancedStrategy": "${raceData?['vars']['d1IgnoreAdvanced'] == true ? '0' : '1'}", // '0' to ignore, '1' to use.
        "advancedFuel": "${raceData?['vars']['d1AdvancedFuel']}", // Fuel amount for races with fixed refuelling.
        "rainStartTyre": "${raceData?['vars']['d1RainStartTyre']}", // Tyre to switch to when rain starts.
        "rainStartDepth": "${raceData?['vars']['d1RainStartDepth']}", // Water level (mm) to trigger change to rain tyres.
        "rainStopTyre": "${raceData?['vars']['d1RainStopTyre']}", // Tyre to switch to when rain stops.
        "rainStopLap": "${raceData?['vars']['d1RainStopLap']}", // Lap number to switch back from rain tyres if rain stops.
      }
    };

    // Strategy data for the second car (d2), structured similarly to d1.
    // This is only included if the team has two cars and relevant data is available.
    Map<String, dynamic> d2Strategy = {};
    // Check if the second car has pit stops defined (d2Pits != 0) and if parsed strategy data exists for it.
    if (raceData?['vars']['d2Pits'] != 0 && raceData?['parsedStrategy'] != null && raceData!['parsedStrategy'].length > 1) {
      d2Strategy = {
        // 'd2setup': Setup for the second car.
        'd2setup': {
          'race': raceData?['vars']['raceId'],
          'suspension': raceData?['vars']['d2Suspension'],
          'ride': raceData?['vars']['d2Ride'],
          'aerodynamics': raceData?['vars']['d2Aerodynamics'],
          'practiceTyre': 'SS' // Default practice tyre.
        },
        // 'd2strategy': Basic stint plan for the second car.
        'd2strategy': {
          "race": raceData?['vars']['raceId'],
          "dNum": "2", // Driver number 2.
          "numPits": raceData?['vars']['d2Pits'],
          "tyre1": raceData?['parsedStrategy']?[1]?[0]?[0],
          "laps1": raceData?['parsedStrategy']?[1]?[0]?[1],
          "fuel1": raceData?['parsedStrategy']?[1]?[0]?[2],
          "tyre2": raceData?['parsedStrategy']?[1]?[1]?[0],
          "laps2": raceData?['parsedStrategy']?[1]?[1]?[1],
          "fuel2": raceData?['parsedStrategy']?[1]?[1]?[2],
          "tyre3": raceData?['parsedStrategy']?[1]?[2]?[0],
          "laps3": raceData?['parsedStrategy']?[1]?[2]?[1],
          "fuel3": raceData?['parsedStrategy']?[1]?[2]?[2],
          "tyre4": raceData?['parsedStrategy']?[1]?[3]?[0],
          "laps4": raceData?['parsedStrategy']?[1]?[3]?[1],
          "fuel4": raceData?['parsedStrategy']?[1]?[3]?[2],
          "tyre5": raceData?['parsedStrategy']?[1]?[4]?[0],
          "laps5": raceData?['parsedStrategy']?[1]?[4]?[1],
          "fuel5": raceData?['parsedStrategy']?[1]?[4]?[2],
        },
        // 'd2strategyAdvanced': Advanced options for the second car.
        "d2strategyAdvanced": {
          "pushLevel": "${raceData?['vars']['d2PushLevel']}",
          "d2SavedStrategy": "1", // Flag indicating strategy is saved.
          "ignoreAdvancedStrategy": "${raceData?['vars']['d2IgnoreAdvanced'] == true ? '0' : '1'}",
          "rainStartTyre": "${raceData?['vars']['d2RainStartTyre']}",
          "rainStartDepth": "${raceData?['vars']['d2RainStartDepth']}",
          "rainStopTyre": "${raceData?['vars']['d2RainStopTyre']}",
          "rainStopLap": "${raceData?['vars']['d2RainStopLap']}",
        }
      };
    } else {
      // If no second car or data is missing, provide a default minimal strategy for d2 to avoid errors.
      // This usually indicates the car is not participating or has no strategy set.
      d2Strategy = {
        'd2setup': {
          'race': raceData?['vars']['raceId'],
          'suspension': '1', 'ride': '0', 'aerodynamics': '0', 'practiceTyre': 'SS' // Minimal default setup.
        },
        'd2strategy': {"race": raceData?['vars']['raceId'], "dNum": "2", "numPits": "0"}, // No pit stops.
        'd2strategyAdvanced': {"d2SavedStrategy": "0", "ignoreAdvancedStrategy": "1"} // Not saved, ignore advanced.
      };
    }
    
    // Conditional logic for refuelling: If refuelling is not allowed in the race rules ('0'),
    // ensure the 'advancedFuel' parameter is included in the payload.
    // Otherwise, it might be omitted or handled differently by the server.
    if (raceData?['vars']['rulesJson']?['refuelling'] == '0') { // '0' means no refuelling allowed.
      d1Strategy['d1strategyAdvanced']['advancedFuel'] = "${raceData?['vars']['d1AdvancedFuel']}";
      if (d2Strategy.containsKey('d2strategyAdvanced')) { // Check if d2 advanced strategy exists
         d2Strategy['d2strategyAdvanced']['advancedFuel'] = "${raceData?['vars']['d2AdvancedFuel'] ?? '0'}";
      }
    }

    // Combine all parts into the final saveData payload.
    Map<String, dynamic> saveData = {
      ...d1Strategy,
      ...d2Strategy,
      // CSRF tokens are typically handled by Dio interceptors or added here if needed
    };

    try {
      final response = await dio.post(url.toString(), data: jsonEncode(saveData));
      debugPrint('Save strategy response for ${email}: ${response.data}');
      // Potentially update local state based on response if necessary
    } catch (e) {
      debugPrint('Error saving strategy for ${email}: $e');
      rethrow;
    }
}

  // Parses and returns sponsor information from a JSON response.
  Map<String, dynamic> getSponsors(Map<String, dynamic> jsonSponsorResponse) {
    final jsonData = jsonSponsorResponse['vars'];
    final emptySponsors = {'income': '0', 'bonus': '0', 'expire': '0', 'status': false}; // Default structure for a sponsor.
    final sponsorsMap = {
      's1': Map<String, dynamic>.from(emptySponsors),
      's2': Map<String, dynamic>.from(emptySponsors)
    };

    final sponsorsData = parseSponsorsFromHtml(jsonData['sponsors']);

    for (final sponsor in sponsorsData) {
      if (sponsor['number'] == 1) { // Primary sponsor
        sponsorsMap['s1']?['income'] = sponsor['Income'];
        sponsorsMap['s1']?['bonus'] = sponsor['Bonus'];
        sponsorsMap['s1']?['expire'] = sponsor['Contract'];
        sponsorsMap['s1']?['status'] = jsonData['s1Name'] != null && jsonData['s1Name'].toString().isNotEmpty;
      } else if (sponsor['number'] == 2) { // Secondary sponsor
        sponsorsMap['s2']?['income'] = sponsor['Income'];
        sponsorsMap['s2']?['bonus'] = sponsor['Bonus'];
        sponsorsMap['s2']?['expire'] = sponsor['Contract'];
        sponsorsMap['s2']?['status'] = jsonData['s2Name'] != null && jsonData['s2Name'].toString().isNotEmpty;
      }
    }

    if (sponsorsMap['s1']?['status'] == false) {
      debugPrint('Primary sponsor expired for ${email}');
    }
    if (sponsorsMap['s2']?['status'] == false) {
      debugPrint('Secondary sponsor expired for ${email}');
    }
    return sponsorsMap;
  }

  // Fetches available sponsor options for a given sponsor slot (primary or secondary).
  Future<Map<String, List<String>>> pickSponsor(int number) async {
    Dio? dio = dioClient;
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot fetch pickSponsor data.');
    }

    final url = Uri.parse('https://igpmanager.com/index.php?action=fetch&d=sponsor&location=$number&csrfName=&csrfToken=');

    try {
      final response = await dio.get(url.toString());
      final jsonData = jsonDecode(response.data);
      return parsePickSponsorData(jsonData, number);
    } catch (e) {
      debugPrint('Error fetching pickSponsor data for ${email}: $e');
      rethrow;
    }
  }

  // Saves the choice of a new sponsor for the specified slot.
  Future<dynamic> saveSponsor(int number, String id, String income, String bonus) async {
    Dio? dio = dioClient;
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot save sponsor.');
    }

    try {
      final signSponsorUrl = "https://igpmanager.com/index.php?action=send&type=contract&enact=sign&eType=5&eId=$id&location=$number&jsReply=contract&csrfName=&csrfToken=";
      final response = await dio.get(signSponsorUrl);
      final jsonData = jsonDecode(response.data);

      // Update local account fireUpData
      final sponsorKey = 's$number';
      if (fireUpData?['sponsor'] != null && fireUpData!['sponsor'][sponsorKey] != null) {
        fireUpData!['sponsor'][sponsorKey]['income'] = income;
        fireUpData!['sponsor'][sponsorKey]['bonus'] = bonus;
        fireUpData!['sponsor'][sponsorKey]['expire'] = '10 race(s)'; // Assuming default expiry
        fireUpData!['sponsor'][sponsorKey]['status'] = true;
      } else {
        debugPrint("Warning: fireUpData['sponsor'] or specific sponsor key not found for ${email}");
      }
      return jsonData;
    } catch (e) {
      debugPrint('Error saving sponsor for ${email}: $e');
      rethrow;
    }
  }

  Future<void> setDefaultStrategy() async {
    if (raceData == null) {
      debugPrint('Race data not available for ${email}. Cannot set default strategy.');
      return;
    }

    // --- Start of Fuel Calculation Logic ---
    final raceLaps = int.tryParse(raceData!['vars']!['raceLaps']!.toString()) ?? 0;
    final trackId = raceData?['vars']?['trackId']?.toString() ?? '1';
    final track = Track(trackId, raceLaps);

    final carAttributes = fireUpData?['preCache']?['p=cars']?['vars']?['carAttributes'];
    final fuelEconomy = carAttributes?['fuel_economy']?.toDouble() ?? 0.0;
    final trackLength = (track.info['length'] as num?)?.toDouble() ?? 0.0;
    final kmPerLiter = fuelCalc(fuelEconomy);
    final fuelPerLap = (kmPerLiter) * trackLength;
    final totalFuel = fuelPerLap * raceLaps;

    if (raceData?['vars']?['rulesJson']?['refuelling'] == '0') {
      raceData!['parsedStrategy'][0][0][2] = totalFuel.ceil();
      raceData?['vars']['d${1}AdvancedFuel'] = totalFuel.ceil();
    }
    raceData!['vars']?['d${1}IgnoreAdvanced'] = true;
    raceData?['kmPerLiter'] = kmPerLiter;
    raceData?['track'] = track;
    // --- End of Fuel Calculation Logic ---

    final generatedStrategy = await generateDefaultStrategyAsync(this);
    if (generatedStrategy.containsKey('error')) {
      debugPrint("Error generating strategy: ${generatedStrategy['error']}");
      return;
    }

    final drivers = fireUpData!['drivers'];
    
    for (int i = 0; i < drivers.length; i++) {
      final loadedStints = generatedStrategy['stints'] as Map<String, dynamic>;
      final numberOfPits = loadedStints.length - 1;
      final pitKey = 'd${i + 1}Pits';
      raceData!['vars'][pitKey] = numberOfPits.clamp(0, 4);

      List<dynamic> newParsedStrategy = [];
      final sortedKeys = loadedStints.keys.toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

      final pushLevelFactorMap = {
        '100': 0.02,
        '80': 0.01,
        '60': 0.0,
        '40': -0.004,
        '20': -0.007,
      };

      for (String key in sortedKeys) {
        Map<String, dynamic> stint = loadedStints[key];
        String? tyre = stint['tyre']?.toString().replaceFirst('ts-', '');
        String laps = stint['laps']?.toString() ?? '0';
        dynamic pushValue = stint['push'];
        String push;
        if (pushValue is int) {
          Map<int, String> pushMap = {
            1: '20',
            2: '40',
            3: '60',
            4: '80',
            5: '100',
          };
          push = pushMap[pushValue] ?? '60';
        } else {
          push = pushValue?.toString() ?? '60';
        }

        final pushFactor = pushLevelFactorMap[push] ?? 0.0;
        final fuelPerLapWithPush = (kmPerLiter + pushFactor) * trackLength;
        double fuelEstimation = (fuelPerLapWithPush * (int.tryParse(laps) ?? 0));

        newParsedStrategy.add([tyre, laps, fuelEstimation, push]);
      }

      double totalCalculatedFuel = 0.0;
      for (int j = 0; j < newParsedStrategy.length.clamp(0, 5); j++) {
        totalCalculatedFuel += newParsedStrategy[j][2];
        if (raceData?['vars']?['rulesJson']?['refuelling'] == '0') {
          newParsedStrategy[j][2] = 0;
        } else {
          newParsedStrategy[j][2] = newParsedStrategy[j][2].ceil();
        }
        if (raceData!['parsedStrategy'][i] == null) {
          raceData!['parsedStrategy'][i] = List.filled(5, null, growable: true);
        }
        raceData!['parsedStrategy'][i][j] = newParsedStrategy[j];
      }

      if (raceData?['vars']?['rulesJson']?['refuelling'] == '0') {
        raceData!['parsedStrategy'][i][0][2] = totalCalculatedFuel.ceil();
        raceData?['vars']['d${i + 1}AdvancedFuel'] = totalCalculatedFuel.ceil();
      }
    }
    debugPrint('Default strategy set for ${email}');
  }
}
