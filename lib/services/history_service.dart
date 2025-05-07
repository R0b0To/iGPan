import '../utils/data_parsers.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart'; // For debugPrint
import '../models/account.dart';
import 'api_client_core.dart'; // For dioClients

class HistoryService {
  Dio? _getDioClient(Account account) {
    final dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}.');
    }
    return dio;
  }

  Future<List<Map<String, dynamic>>> requestHistoryReports(Account account, {int start = 0, int numResults = 10}) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot request history reports.');
    }

    try {
      final reportsUrl = "https://igpmanager.com/index.php?action=send&type=history&start=$start&numResults=$numResults&jsReply=scrollLoader&el=history&csrfName=&csrfToken=";
      final response = await dio.get(reportsUrl);
      final jsonData = jsonDecode(response.data);
      
      if (jsonData != null && jsonData['src'] != null) {
        return parseRaces(jsonData['src'].toString());
      } else {
        debugPrint('Failed to parse history reports or "src" key missing for ${account.email}');
        return [];
      }
    } catch (e) {
      debugPrint('Error requesting history reports for ${account.email}: $e');
      rethrow;
    }
  }

  Future<Map<dynamic, dynamic>> requestRaceReport(Account account, String raceId) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot request race report.');
    }

    try {
      final reportUrl = "https://igpmanager.com/index.php?action=fetch&d=result&id=$raceId&tab=race&csrfName=&csrfToken=";
      final response = await dio.get(reportUrl);
      final jsonData = jsonDecode(response.data);

      if (jsonData != null && jsonData['vars'] != null) {
         return parseRaceReport(jsonData['vars'] as Map<String, dynamic>);
      } else {
        debugPrint('Failed to parse race report or "vars" key missing for race ID $raceId, account ${account.email}');
        return {};
      }
    } catch (e) {
      debugPrint('Error requesting race report for race ID $raceId, account ${account.email}: $e');
      rethrow;
    }
  }

  Future<List<dynamic>> requestDriverReport(Account account, String raceId) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot request driver report.');
    }

    try {
      final reportUrl = "https://igpmanager.com/index.php?action=fetch&d=resultDetail&id=$raceId&csrfName=&csrfToken=";
      final response = await dio.get(reportUrl);
      final jsonData = jsonDecode(response.data);

      if (jsonData != null && jsonData['vars']?['results'] != null) {
        return parseDriverResult(jsonData['vars']['results'].toString());
      } else {
        debugPrint('Failed to parse driver report or "results" key missing for race ID $raceId, account ${account.email}');
        return [];
      }
    } catch (e) {
      debugPrint('Error requesting driver report for race ID $raceId, account ${account.email}: $e');
      rethrow;
    }
  }
}