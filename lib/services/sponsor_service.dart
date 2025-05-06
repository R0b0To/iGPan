import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart'; // For debugPrint

import '../models/account.dart';
import 'api_client_core.dart'; // For dioClients
import '../utils/data_parsers.dart'; // For parseSponsorsFromHtml, parsePickSponsorData

class SponsorService {
  Dio? _getDioClient(Account account) {
    final dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}.');
    }
    return dio;
  }

  Map<String, dynamic> getSponsors(Map<String, dynamic> jsonSponsorResponse, Account account) {
    final jsonData = jsonSponsorResponse['vars'];
    final emptySponsors = {'income': '0', 'bonus': '0', 'expire': '0', 'status': false};
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
      debugPrint('Primary sponsor expired for ${account.email}');
    }
    if (sponsorsMap['s2']?['status'] == false) {
      debugPrint('Secondary sponsor expired for ${account.email}');
    }
    return sponsorsMap;
  }

  Future<Map<String, List<String>>> pickSponsor(Account account, int number) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot fetch pickSponsor data.');
    }

    final url = Uri.parse('https://igpmanager.com/index.php?action=fetch&d=sponsor&location=$number&csrfName=&csrfToken=');

    try {
      final response = await dio.get(url.toString());
      final jsonData = jsonDecode(response.data);
      return parsePickSponsorData(jsonData, number);
    } catch (e) {
      debugPrint('Error fetching pickSponsor data for ${account.email}: $e');
      rethrow;
    }
  }

  Future<dynamic> saveSponsor(Account account, int number, String id, String income, String bonus) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot save sponsor.');
    }

    try {
      final signSponsorUrl = "https://igpmanager.com/index.php?action=send&type=contract&enact=sign&eType=5&eId=$id&location=$number&jsReply=contract&csrfName=&csrfToken=";
      final response = await dio.get(signSponsorUrl);
      final jsonData = jsonDecode(response.data);

      // Update local account fireUpData
      final sponsorKey = 's$number';
      if (account.fireUpData?['sponsor'] != null && account.fireUpData!['sponsor'][sponsorKey] != null) {
        account.fireUpData!['sponsor'][sponsorKey]['income'] = income;
        account.fireUpData!['sponsor'][sponsorKey]['bonus'] = bonus;
        account.fireUpData!['sponsor'][sponsorKey]['expire'] = '10 race(s)'; // Assuming default expiry
        account.fireUpData!['sponsor'][sponsorKey]['status'] = true;
      } else {
        debugPrint("Warning: fireUpData['sponsor'] or specific sponsor key not found for ${account.email}");
      }
      return jsonData;
    } catch (e) {
      debugPrint('Error saving sponsor for ${account.email}: $e');
      rethrow;
    }
  }
}