import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart'; // For debugPrint

import '../models/account.dart';
import 'api_client_core.dart'; // For dioClients
import '../utils/data_parsers.dart'; // Import data parsers

class CarService {
  Dio? _getDioClient(Account account) {
    final dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}.');
    }
    return dio;
  }

  Future<int> repairCar(Account account, int carNumber, String repairType) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot repair car.');
    }

    int totalRemaining = -1;
    final carIdKey = 'c${carNumber}Id';
    final carId = account.fireUpData?['preCache']?['p=cars']?['vars']?[carIdKey];

    if (carId == null) {
      debugPrint('Error: Car ID not found for car number $carNumber for account ${account.email}');
      return totalRemaining; // Or throw an error
    }

    try {
      if (repairType == 'parts') {
        final totalParts = int.tryParse(account.fireUpData?['preCache']?['p=cars']?['vars']?['totalParts']?.toString() ?? '0') ?? 0;
        final repairCost = int.tryParse(account.fireUpData?['preCache']?['p=cars']?['vars']?['c${carNumber}CarBtn']?.toString() ?? '0') ?? 0;
        final carCondition = int.tryParse(account.fireUpData?['preCache']?['p=cars']?['vars']?['c${carNumber}Condition']?.toString() ?? '100') ?? 100;

        if (repairCost <= totalParts && carCondition < 100) {
          final repairUrl = "https://igpmanager.com/index.php?action=send&type=fix&car=$carId&btn=c${carNumber}PartSwap&jsReply=fix&csrfName=&csrfToken=";
          final response = await dio.get(repairUrl);
          // final jsonData = jsonDecode(response.data); // Assuming response might be useful
          totalRemaining = totalParts - repairCost;
          account.fireUpData?['preCache']?['p=cars']?['vars']?['totalParts'] = totalRemaining.toString();
          account.fireUpData?['preCache']?['p=cars']?['vars']?['c${carNumber}Condition'] = "100";
           debugPrint('Car parts repaired for c$carNumber, ${account.email}. Parts remaining: $totalRemaining');
        } else {
          debugPrint('Repairing car parts not possible for c$carNumber, ${account.email}. Cost: $repairCost, Has: $totalParts, Condition: $carCondition');
          return totalRemaining; // Indicate no repair was made or current parts count
        }
      } else if (repairType == 'engine') {
        final totalEngines = int.tryParse(account.fireUpData?['preCache']?['p=cars']?['vars']?['totalEngines']?.toString() ?? '0') ?? 0;
        final engineConditionKey = 'c${carNumber}Engine';
        final currentEngineCondition = int.tryParse(account.fireUpData?['preCache']?['p=cars']?['vars']?[engineConditionKey]?.toString() ?? '100') ?? 100;

        if (totalEngines > 0 && currentEngineCondition < 100) {
          final repairUrl = "https://igpmanager.com/index.php?action=send&type=engine&car=$carId&btn=c${carNumber}EngSwap&jsReply=fix&csrfName=&csrfToken=";
          final response = await dio.get(repairUrl);
          // final jsonData = jsonDecode(response.data); // Assuming response might be useful
          totalRemaining = totalEngines - 1;
          account.fireUpData?['preCache']?['p=cars']?['vars']?['totalEngines'] = totalRemaining.toString();
          account.fireUpData?['preCache']?['p=cars']?['vars']?[engineConditionKey] = "100";
          debugPrint('Car engine replaced for c$carNumber, ${account.email}. Engines remaining: $totalRemaining');
        } else {
          debugPrint('Replacing engine not possible for c$carNumber, ${account.email}. Has: $totalEngines, Condition: $currentEngineCondition');
           return totalRemaining; // Indicate no repair or current engine count
        }
      }
      return totalRemaining;
    } catch (e) {
      debugPrint('Error repairing car $carNumber (${repairType}) for ${account.email}: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> requestResearch(Account account) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot request research data.');
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
      debugPrint('Error in research request for ${account.email}: $e');
      rethrow;
    }
  }

  Future<void> saveDesign(Account account, Map<String, dynamic> researchSettings, List<String> designParams) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot save design.');
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
      debugPrint('Design and research saved for ${account.email}');
    } catch (e) {
      debugPrint('Error saving design for ${account.email}: $e');
      rethrow;
    }
  }

  Future<Map<String, String>> buyEnginesWithTokens(Account account, int tokenCost) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot buy engines.');
    }

    Map<int, int> costToAmountMap = {3: 1, 4: 3, 5: 5}; // tokenCost to engineAmount
    final int enginesToBuy = costToAmountMap[tokenCost] ?? 0;

    if (enginesToBuy == 0) {
      debugPrint('Invalid token cost for buying engines: $tokenCost for ${account.email}');
      return {
        'tokens': account.fireUpData?['manager']?['tokens']?.toString() ?? '0',
        'engines': account.fireUpData?['preCache']?['p=cars']?['vars']?['totalEngines']?.toString() ?? '0'
      };
    }

    final currentTokens = int.tryParse(account.fireUpData?['manager']?['tokens']?.toString() ?? '0') ?? 0;
    final currentEngines = int.tryParse(account.fireUpData?['preCache']?['p=cars']?['vars']?['totalEngines']?.toString() ?? '0') ?? 0;
    
    Map<String, String> result = {'tokens': currentTokens.toString(), 'engines': currentEngines.toString()};

    if (currentTokens >= tokenCost) {
      try {
        final buyEnginesUrl = "https://igpmanager.com/index.php?action=send&type=shop&item=engines&amount=$enginesToBuy&jsReply=shop&csrfName=&csrfToken=";
        final response = await dio.get(buyEnginesUrl);
        // final jsonData = jsonDecode(response.data); // If response data is needed

        result['engines'] = (currentEngines + enginesToBuy).toString();
        result['tokens'] = (currentTokens - tokenCost).toString();
        
        account.fireUpData?['preCache']?['p=cars']?['vars']?['totalEngines'] = result['engines'];
        account.fireUpData?['manager']?['tokens'] = result['tokens'];
        
        debugPrint('Engines bought for ${account.email}. New totals - Engines: ${result['engines']}, Tokens: ${result['tokens']}');
        return result;
      } catch (e) {
        debugPrint('Error buying engines for ${account.email}: $e');
        rethrow;
      }
    } else {
      debugPrint('Not enough tokens to buy engines for ${account.email}. Has: $currentTokens, Needs: $tokenCost');
      return result; // Return current state if not enough tokens
    }
  }
}
