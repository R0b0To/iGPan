import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart'; // For debugPrint

import '../models/account.dart';
import 'api_client_core.dart'; // For dioClients

class LeagueService {
  Dio? _getDioClient(Account account) {
    final dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}.');
    }
    return dio;
  }

  Future<Map<String, dynamic>?> requestLeagueInfo(Account account) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot request league info.');
    }

    final leagueId = account.fireUpData?['team']?['_league'];
    if (leagueId == null || leagueId == '0') {
      debugPrint('Account ${account.email} is not in a league or league ID is invalid.');
      return null; // Not in a league or ID missing
    }

    try {
      final leagueUrl = "https://igpmanager.com/index.php?action=fetch&p=league&id=$leagueId&csrfName=&csrfToken=";
      final response = await dio.get(leagueUrl);
      final jsonData = jsonDecode(response.data);
      
      if (jsonData != null && jsonData['vars'] != null) {
        account.fireUpData?['league'] = jsonData['vars'];
        debugPrint('League info fetched for ${account.email}, league ID: $leagueId');
        return jsonData['vars'] as Map<String, dynamic>;
      } else {
        debugPrint('Failed to parse league info or "vars" key missing for ${account.email}');
        return null;
      }
    } catch (e) {
      debugPrint('Error requesting league info for ${account.email}: $e');
      rethrow;
    }
  }
}