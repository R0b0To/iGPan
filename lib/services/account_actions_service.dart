import 'package:dio/dio.dart';
import 'package:flutter/material.dart'; // For debugPrint, consider a dedicated logger

import '../models/account.dart';
import 'api_client_core.dart'; // For dioClients

class AccountActionsService {
  // Method to get the Dio client for a specific account
  Dio? _getDioClient(Account account) {
    final dio = dioClients[account.email];
    if (dio == null) {
      debugPrint('Error: Dio client not found for ${account.email}.');
    }
    return dio;
  }

  Future<void> claimDailyReward(Account account) async {
    Dio? dio = _getDioClient(account);
    if (dio == null) {
      throw Exception('Dio client not initialized for account. Cannot claim daily reward.');
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
          account.fireUpData!['notify'] is Map && // Ensure 'notify' is a Map
          (account.fireUpData!['notify'] as Map).containsKey('page') &&
          account.fireUpData!['notify']['page'] != null &&
          account.fireUpData!['notify']['page'] is Map && // Ensure 'page' is a Map
          (account.fireUpData!['notify']['page'] as Map).containsKey('nDailyReward')) {
        (account.fireUpData!['notify']['page'] as Map).remove('nDailyReward');
        debugPrint('Removed nDailyReward key for ${account.email}');
      }
    } catch (e) {
      debugPrint('Error claiming daily reward for ${account.email}: $e');
      rethrow; // Re-throw the error for the caller to handle
    }
  }
}