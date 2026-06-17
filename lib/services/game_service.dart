import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/app_config.dart';
import '../core/exceptions.dart';
import '../models/account_data.dart';
import '../network/http_client.dart';

/// Handles game actions that are not car-specific or race-specific.
///
/// Car repair/research/design → [CarService].
/// Race setup/strategy/save   → [RaceService].
class GameService {
  final HttpClient _httpClient;

  GameService({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  // ─── fireUp ───────────────────────────────────────────────

  /// Fetch full account state. Primary data source — called on startup/refresh.
  Future<AccountData> fetchAccountData(String accountEmail) async {
    debugPrint('[GameService] Fetching account data for $accountEmail');

    final response = await _httpClient.get<String>(
      AppConfig.fireUpEndpoint,
      accountEmail: accountEmail,
    );

    final data = _parseJson(response.data, 'fetchAccountData', accountEmail);

    if (data['guestAccount'] == true) {
      throw SessionExpiredException(accountEmail, 'Session expired (guest)');
    }

    return AccountData.fromFireUp(data);
  }

  // ─── Daily reward ─────────────────────────────────────────

  /// Claim the daily reward.
  Future<Map<String, dynamic>> claimDailyReward(String accountEmail) async {
    debugPrint('[GameService] Claiming daily reward for $accountEmail');

    final response = await _httpClient.get<String>(
      AppConfig.dailyRewardEndpoint,
      accountEmail: accountEmail,
    );

    return _parseJson(response.data, 'claimDailyReward', accountEmail);
  }

  // ─── HQ collect ───────────────────────────────────────────

  /// Collect resources from an HQ facility.
  ///
  /// [collectUrl] is the full URL from the collectBubble data-href attribute.
  Future<Map<String, dynamic>> collectHqFacility(
    String accountEmail, {
    required String collectUrl,
  }) async {
    debugPrint('[GameService] Collecting HQ facility for $accountEmail');

    final path = collectUrl.startsWith('http')
        ? collectUrl.replaceFirst(AppConfig.baseUrl, '')
        : collectUrl;

    final response = await _httpClient.get<String>(
      path,
      accountEmail: accountEmail,
    );

    return _parseJson(response.data, 'collectHqFacility', accountEmail);
  }

  // ─── History ──────────────────────────────────────────────

  /// Fetch race history list.
  Future<Map<String, dynamic>> fetchHistory(
    String accountEmail, {
    int start      = 0,
    int numResults = 10,
  }) async {
    final response = await _httpClient.get<String>(
      '${AppConfig.historyEndpoint}&start=$start&numResults=$numResults',
      accountEmail: accountEmail,
    );

    return _parseJson(response.data, 'fetchHistory', accountEmail);
  }

  /// Fetch detailed race report for [raceId].
  Future<Map<String, dynamic>> fetchRaceReport(
    String accountEmail, {
    required String raceId,
  }) async {
    final response = await _httpClient.get<String>(
      '${AppConfig.raceReportEndpoint}&id=$raceId',
      accountEmail: accountEmail,
    );

    final data = _parseJson(response.data, 'fetchRaceReport', accountEmail);
    return data['vars'] as Map<String, dynamic>? ?? {};
  }

  // ─── League ───────────────────────────────────────────────

  /// Fetch league info for [leagueId].
  Future<Map<String, dynamic>> fetchLeagueInfo(
    String accountEmail, {
    required String leagueId,
  }) async {
    final response = await _httpClient.get<String>(
      '${AppConfig.leagueEndpoint}&id=$leagueId',
      accountEmail: accountEmail,
    );

    final data = _parseJson(response.data, 'fetchLeagueInfo', accountEmail);
    return data['vars'] as Map<String, dynamic>? ?? {};
  }

  // ─── Batch helpers ────────────────────────────────────────

  /// Claim daily reward for multiple accounts concurrently.
  Future<Map<String, BatchResult>> claimDailyRewardAll(
    List<String> emails,
  ) async {
    final futures = emails.map((email) async {
      try {
        final data = await claimDailyReward(email);
        return MapEntry(email, BatchResult.success(data));
      } catch (e) {
        return MapEntry(email, BatchResult.failure(e.toString()));
      }
    });

    return Map.fromEntries(await Future.wait(futures));
  }

  // ─── Internal ─────────────────────────────────────────────

  Map<String, dynamic> _parseJson(
    String?  raw,
    String   operation,
    String   accountEmail,
  ) {
    if (raw == null || raw.isEmpty) {
      throw ApiException('Empty response from $operation for $accountEmail');
    }

    final Map<String, dynamic> data;
    try {
      data = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Non-JSON response from $operation: $raw');
    }

    if (data['error'] != null) {
      throw ApiException(data['error'].toString());
    }

    return data;
  }
}

// ─── BatchResult ──────────────────────────────────────────────────────────────

/// Outcome of a batch operation for one account.
class BatchResult {
  final bool                  success;
  final Map<String, dynamic>? data;
  final String?               error;

  const BatchResult._({required this.success, this.data, this.error});

  factory BatchResult.success(Map<String, dynamic> data) =>
      BatchResult._(success: true, data: data);

  factory BatchResult.failure(String error) =>
      BatchResult._(success: false, error: error);

  @override
  String toString() =>
      success ? 'BatchResult(success)' : 'BatchResult(error: $error)';
}