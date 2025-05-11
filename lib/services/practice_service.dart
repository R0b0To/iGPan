import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart'; // For debugPrint, consider a dedicated logger

import '../models/account.dart';
import 'api_client_core.dart'; // For dioClients

class PracticeService {
  Dio? _getDioClient(Account account) {
    final dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}.');
    }
    return dio;
  }

  Future<Map<String, dynamic>> simulatePracticeLap(Account account, int carIndex, String tyre) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot simulate practice lap.');
    }

    String skey = 'd${carIndex + 1}Suspension';
    String rkey = 'd${carIndex + 1}Ride';
    String akey = 'd${carIndex + 1}Aerodynamics';

    final url = "https://igpmanager.com/index.php?action=send&addon=igp&type=setup&dNum=${carIndex+1}&ajax=1&race=${account.raceData?['vars']['raceId']}&suspension=${account.raceData?['vars']?[skey]}&ride=${account.raceData?['vars']?[rkey]}&aerodynamics=${account.raceData?['vars']?[akey]}&practiceTyre=$tyre&csrfName=&csrfToken=";

    debugPrint('Simulating practice lap for ${account.email}, car ${carIndex + 1}, tyre $tyre. URL: $url');

    try {
      final response = await dio.get(url);
      debugPrint('Practice lap simulation response for ${account.email}: ${response.data}');

      final responseData = jsonDecode(response.data);
      final lapId = responseData['lapId'];

      if (lapId != null) {
        // Wait for 3 seconds
        await Future.delayed(Duration(seconds: 3));

        final practiceLapUrl = "https://igpmanager.com/index.php?action=fetch&type=lapTime&lapId=$lapId&dNum=${carIndex + 1}&addon=igp&ajax=1&jsReply=lapTime&csrfName=&csrfToken=";

        debugPrint('Fetching practice lap time for ${account.email}, lapId $lapId. URL: $practiceLapUrl');

        final practiceLapResponse = await dio.get(practiceLapUrl);
        debugPrint('Practice lap time response for ${account.email}: ${practiceLapResponse.data}');

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
        debugPrint('lapId not found in the first response for ${account.email}');
        return {}; // Return empty map if lapId is not found
      }
    } catch (e) {
      debugPrint('Error simulating practice lap for ${account.email}: $e');
      rethrow;
    }
  }
}
