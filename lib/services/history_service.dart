import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart'; // For debugPrint
import 'package:html/parser.dart' as html_parser; // For parsing HTML in reports

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

  // Internal parser, move to data_parsers.dart if it grows complex or is reused
  List<Map<String, String>> _parseRaces(String htmlSrc) {
    final document = html_parser.parse(htmlSrc);
    final List<Map<String, String>> races = [];
    final raceRows = document.querySelectorAll('tr[id^="raceRow"]');

    for (var row in raceRows) {
      final id = row.id.replaceFirst('raceRow', '');
      final trackName = row.querySelector('td:nth-child(2) a')?.text.trim() ?? 'N/A';
      final position = row.querySelector('td:nth-child(3)')?.text.trim() ?? 'N/A';
      final date = row.querySelector('td:nth-child(5)')?.text.trim() ?? 'N/A';
      races.add({
        'id': id,
        'track': trackName,
        'position': position,
        'date': date,
      });
    }
    return races;
  }

  // Internal parser, move to data_parsers.dart if it grows complex
  Map<String, dynamic> _parseRaceReport(Map<String, dynamic> vars) {
    // Example: Extracting basic info. This will need to be adjusted based on actual 'vars' structure.
    final Map<String, dynamic> report = {
      'trackName': vars['trackName'] ?? 'N/A',
      'date': vars['date'] ?? 'N/A',
      'results': vars['results'] ?? [], // Assuming results is a list or another map
      // Add more fields as needed based on the structure of vars
    };
    // Potentially more parsing of HTML embedded in vars fields
    return report;
  }
  
  // Internal parser, move to data_parsers.dart if it grows complex
  List<Map<String, String>> _parseDriverResult(String htmlResults) {
    final document = html_parser.parse(htmlResults);
    final List<Map<String, String>> driverResults = [];
    // This is highly dependent on the actual HTML structure of driver results.
    // Example: (needs to be adapted)
    final rows = document.querySelectorAll('table.resultsTable tbody tr'); // Fictional selector
    for (var row in rows) {
      driverResults.add({
        'driverName': row.querySelector('td.driverName')?.text.trim() ?? 'N/A',
        'stints': row.querySelector('td.stintsData')?.text.trim() ?? 'N/A',
        // Add other relevant data points
      });
    }
    return driverResults;
  }


  Future<List<Map<String, String>>> requestHistoryReports(Account account, {int start = 0, int numResults = 10}) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot request history reports.');
    }

    try {
      final reportsUrl = "https://igpmanager.com/index.php?action=send&type=history&start=$start&numResults=$numResults&jsReply=scrollLoader&el=history&csrfName=&csrfToken=";
      final response = await dio.get(reportsUrl);
      final jsonData = jsonDecode(response.data);
      
      if (jsonData != null && jsonData['src'] != null) {
        return _parseRaces(jsonData['src'].toString());
      } else {
        debugPrint('Failed to parse history reports or "src" key missing for ${account.email}');
        return [];
      }
    } catch (e) {
      debugPrint('Error requesting history reports for ${account.email}: $e');
      rethrow;
    }
  }

  Future<Map<String, dynamic>> requestRaceReport(Account account, String raceId) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot request race report.');
    }

    try {
      final reportUrl = "https://igpmanager.com/index.php?action=fetch&d=result&id=$raceId&tab=race&csrfName=&csrfToken=";
      final response = await dio.get(reportUrl);
      final jsonData = jsonDecode(response.data);

      if (jsonData != null && jsonData['vars'] != null) {
         return _parseRaceReport(jsonData['vars'] as Map<String, dynamic>);
      } else {
        debugPrint('Failed to parse race report or "vars" key missing for race ID $raceId, account ${account.email}');
        return {};
      }
    } catch (e) {
      debugPrint('Error requesting race report for race ID $raceId, account ${account.email}: $e');
      rethrow;
    }
  }

  Future<List<Map<String, String>>> requestDriverReport(Account account, String raceId) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot request driver report.');
    }

    try {
      final reportUrl = "https://igpmanager.com/index.php?action=fetch&d=resultDetail&id=$raceId&csrfName=&csrfToken=";
      final response = await dio.get(reportUrl);
      final jsonData = jsonDecode(response.data);

      if (jsonData != null && jsonData['vars']?['results'] != null) {
        return _parseDriverResult(jsonData['vars']['results'].toString());
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