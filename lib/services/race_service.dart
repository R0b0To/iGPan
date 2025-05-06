import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart'; // For debugPrint, consider a dedicated logger

import '../models/account.dart';
import 'api_client_core.dart'; // For dioClients
import '../utils/data_parsers.dart'; // For extractStrategyData

class RaceService {
  Dio? _getDioClient(Account account) {
    final dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}.');
    }
    return dio;
  }

  Future<void> fetchRaceData(Account account) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot fetch race data.');
    }

    final url = Uri.parse('https://igpmanager.com/index.php?action=fetch&p=race&csrfName=&csrfToken=');

    try {
      final response = await dio.get(url.toString());
      final raceDataJson = jsonDecode(response.data);

      if (account.fireUpData?['team']?['_numCars'] == '2') {
        raceDataJson['vars']['d2IgnoreAdvanced'] = raceDataJson['vars']['d2IgnoreAdvanced'] == '0' ? true : false;
        final selectedPushD2 = RegExp(r'<option\s+value="(\d+)"\s+selected>').firstMatch(raceDataJson['vars']['d2PushLevel'])?.group(1) ?? '60';
        raceDataJson['vars']['d2PushLevel'] = selectedPushD2;
        raceDataJson['vars']['d2RainStartDepth'] = RegExp(r'value="([^"]*)"').firstMatch(raceDataJson['vars']['d2RainStartDepth'])?.group(1) ?? '0';
        raceDataJson['vars']['d2RainStopLap'] = RegExp(r'value="([^"]*)"').firstMatch(raceDataJson['vars']['d2RainStopLap'])?.group(1) ?? '0';
        raceDataJson['vars']['d2AdvancedFuel'] = RegExp(r'value="([^"]*)"').firstMatch(raceDataJson['vars']['d2AdvancedFuel'])?.group(1) ?? '0';
      }
      raceDataJson['vars']['d1IgnoreAdvanced'] = raceDataJson['vars']['d1IgnoreAdvanced'] == '0' ? true : false;
      final selectedPushD1 = RegExp(r'<option\s+value="(\d+)"\s+selected>').firstMatch(raceDataJson['vars']['d1PushLevel'])?.group(1) ?? '60';
      raceDataJson['vars']['d1PushLevel'] = selectedPushD1;
      raceDataJson['vars']['d1RainStartDepth'] = RegExp(r'value="([^"]*)"').firstMatch(raceDataJson['vars']['d1RainStartDepth'])?.group(1) ?? '0';
      raceDataJson['vars']['d1RainStopLap'] = RegExp(r'value="([^"]*)"').firstMatch(raceDataJson['vars']['d1RainStopLap'])?.group(1) ?? '0';
      raceDataJson['vars']['d1AdvancedFuel'] = RegExp(r'value="([^"]*)"').firstMatch(raceDataJson['vars']['d1AdvancedFuel'])?.group(1) ?? '0';

      raceDataJson['parsedStrategy'] = extractStrategyData(
          raceDataJson['vars'],
          raceDataJson['vars']['d1PushLevel'],
          account.fireUpData?['team']?['_numCars'] == '2' ? raceDataJson['vars']['d2PushLevel'] : null
      );
      if (raceDataJson['vars']['rulesJson'] is String) {
        raceDataJson['vars']['rulesJson'] = jsonDecode(raceDataJson['vars']['rulesJson']);
      }
      account.raceData = raceDataJson;
      debugPrint('Race data fetched for ${account.email}');
    } catch (e) {
      debugPrint('Error fetching race data for ${account.email}: $e');
      rethrow;
    }
  }

  Future<void> saveStrategy(Account account) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot save strategy.');
    }

    final url = Uri.parse('https://igpmanager.com/index.php?action=send&type=saveAll&addon=igp&ajax=1&jsReply=saveAll&csrfName=&csrfName=&csrfToken=&csrfToken=&pageId=race');
    
    Map<String, dynamic> d1Strategy = {
      'd1setup': {
        'race': account.raceData?['vars']['raceId'],
        'suspension': account.raceData?['vars']['d1Suspension'],
        'ride': account.raceData?['vars']['d1Ride'],
        'aerodynamics': account.raceData?['vars']['d1Aerodynamics'],
        'practiceTyre': 'SS' // Assuming 'SS' is a default or common value
      },
      'd1strategy': {
        "race": account.raceData?['vars']['raceId'],
        "dNum": "1",
        "numPits": account.raceData?['vars']['d1Pits'],
        "tyre1": account.raceData?['parsedStrategy']?[0]?[0]?[0],
        "laps1": account.raceData?['parsedStrategy']?[0]?[0]?[1],
        "fuel1": account.raceData?['parsedStrategy']?[0]?[0]?[2],
        "tyre2": account.raceData?['parsedStrategy']?[0]?[1]?[0],
        "laps2": account.raceData?['parsedStrategy']?[0]?[1]?[1],
        "fuel2": account.raceData?['parsedStrategy']?[0]?[1]?[2],
        "tyre3": account.raceData?['parsedStrategy']?[0]?[2]?[0],
        "laps3": account.raceData?['parsedStrategy']?[0]?[2]?[1],
        "fuel3": account.raceData?['parsedStrategy']?[0]?[2]?[2],
        "tyre4": account.raceData?['parsedStrategy']?[0]?[3]?[0],
        "laps4": account.raceData?['parsedStrategy']?[0]?[3]?[1],
        "fuel4": account.raceData?['parsedStrategy']?[0]?[3]?[2],
        "tyre5": account.raceData?['parsedStrategy']?[0]?[4]?[0],
        "laps5": account.raceData?['parsedStrategy']?[0]?[4]?[1],
        "fuel5": account.raceData?['parsedStrategy']?[0]?[4]?[2],
      },
      "d1strategyAdvanced": {
        "pushLevel": "${account.raceData?['vars']['d1PushLevel']}",
        "d1SavedStrategy": "1", // Assuming "1" means saved
        "ignoreAdvancedStrategy": "${account.raceData?['vars']['d1IgnoreAdvanced'] == true ? '0' : '1'}",
        "advancedFuel": "${account.raceData?['vars']['d1AdvancedFuel']}",
        "rainStartTyre": "${account.raceData?['vars']['d1RainStartTyre']}",
        "rainStartDepth": "${account.raceData?['vars']['d1RainStartDepth']}",
        "rainStopTyre": "${account.raceData?['vars']['d1RainStopTyre']}",
        "rainStopLap": "${account.raceData?['vars']['d1RainStopLap']}",
      }
    };

    Map<String, dynamic> d2Strategy = {};
    if (account.raceData?['vars']['d2Pits'] != 0 && account.raceData?['parsedStrategy'] != null && account.raceData!['parsedStrategy'].length > 1) {
      d2Strategy = {
        'd2setup': {
          'race': account.raceData?['vars']['raceId'],
          'suspension': account.raceData?['vars']['d2Suspension'],
          'ride': account.raceData?['vars']['d2Ride'],
          'aerodynamics': account.raceData?['vars']['d2Aerodynamics'],
          'practiceTyre': 'SS'
        },
        'd2strategy': {
          "race": account.raceData?['vars']['raceId'],
          "dNum": "2",
          "numPits": account.raceData?['vars']['d2Pits'],
          "tyre1": account.raceData?['parsedStrategy']?[1]?[0]?[0],
          "laps1": account.raceData?['parsedStrategy']?[1]?[0]?[1],
          "fuel1": account.raceData?['parsedStrategy']?[1]?[0]?[2],
          "tyre2": account.raceData?['parsedStrategy']?[1]?[1]?[0],
          "laps2": account.raceData?['parsedStrategy']?[1]?[1]?[1],
          "fuel2": account.raceData?['parsedStrategy']?[1]?[1]?[2],
          "tyre3": account.raceData?['parsedStrategy']?[1]?[2]?[0],
          "laps3": account.raceData?['parsedStrategy']?[1]?[2]?[1],
          "fuel3": account.raceData?['parsedStrategy']?[1]?[2]?[2],
          "tyre4": account.raceData?['parsedStrategy']?[1]?[3]?[0],
          "laps4": account.raceData?['parsedStrategy']?[1]?[3]?[1],
          "fuel4": account.raceData?['parsedStrategy']?[1]?[3]?[2],
          "tyre5": account.raceData?['parsedStrategy']?[1]?[4]?[0],
          "laps5": account.raceData?['parsedStrategy']?[1]?[4]?[1],
          "fuel5": account.raceData?['parsedStrategy']?[1]?[4]?[2],
        },
        "d2strategyAdvanced": {
          "pushLevel": "${account.raceData?['vars']['d2PushLevel']}",
          "d2SavedStrategy": "1",
          "ignoreAdvancedStrategy": "${account.raceData?['vars']['d2IgnoreAdvanced'] == true ? '0' : '1'}",
          "rainStartTyre": "${account.raceData?['vars']['d2RainStartTyre']}",
          "rainStartDepth": "${account.raceData?['vars']['d2RainStartDepth']}",
          "rainStopTyre": "${account.raceData?['vars']['d2RainStopTyre']}",
          "rainStopLap": "${account.raceData?['vars']['d2RainStopLap']}",
        }
      };
    } else {
      // Default d2 strategy if not 2 cars or data missing
      d2Strategy = {
        'd2setup': {
          'race': account.raceData?['vars']['raceId'],
          'suspension': '1', 'ride': '0', 'aerodynamics': '0', 'practiceTyre': 'SS'
        },
        'd2strategy': {"race": account.raceData?['vars']['raceId'], "dNum": "2", "numPits": "0"},
        'd2strategyAdvanced': {"d2SavedStrategy": "0", "ignoreAdvancedStrategy": "1"}
      };
    }
    
    if (account.raceData?['vars']['rulesJson']?['refuelling'] == '0') {
      d1Strategy['d1strategyAdvanced']['advancedFuel'] = "${account.raceData?['vars']['d1AdvancedFuel']}";
      if (d2Strategy.containsKey('d2strategyAdvanced')) {
         d2Strategy['d2strategyAdvanced']['advancedFuel'] = "${account.raceData?['vars']['d2AdvancedFuel'] ?? '0'}";
      }
    }

    Map<String, dynamic> saveData = {
      ...d1Strategy,
      ...d2Strategy,
      // CSRF tokens are typically handled by Dio interceptors or added here if needed
    };

    try {
      final response = await dio.post(url.toString(), data: jsonEncode(saveData));
      debugPrint('Save strategy response for ${account.email}: ${response.data}');
      // Potentially update local state based on response if necessary
    } catch (e) {
      debugPrint('Error saving strategy for ${account.email}: $e');
      rethrow;
    }
  }
}