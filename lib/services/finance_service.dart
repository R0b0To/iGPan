import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/app_config.dart';
import '../core/exceptions.dart';
import '../models/finance_data.dart';
import '../network/http_client.dart';

class FinanceService {
  final HttpClient _httpClient;

  FinanceService({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  static const String _endpoint =
      '/index.php?action=fetch&p=finances&csrfName=&csrfToken=';

  // ─── Finances ─────────────────────────────────────────────

  Future<FinanceData> fetchFinances(String accountEmail) async {
    debugPrint('[FinanceService] Fetching finances for $accountEmail');

    final response = await _httpClient.get<String>(
      _endpoint,
      accountEmail: accountEmail,
    );

    final raw = response.data;
    if (raw == null || raw.isEmpty) {
      throw ApiException('Empty finances response for $accountEmail');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Non-JSON finances response');
    }

    if (json['guestAccount'] == true) {
      throw SessionExpiredException(accountEmail, 'Session expired');
    }

    return FinanceData.fromJson(json);
  }

  // ─── Sponsor options ──────────────────────────────────────

  /// Fetch the list of available sponsors for the given slot.
  ///
  /// [location] — 1 = primary sponsor, 2 = secondary sponsor.
  ///
  /// GET /index.php?action=fetch&d=sponsor&location={location}&csrfName=&csrfToken=
  ///
  /// Returns [SponsorOption] objects parsed from vars.row1 … row5.
  Future<List<SponsorOption>> fetchSponsorOptions(
    String accountEmail, {
    required int location,
  }) async {
    debugPrint(
        '[FinanceService] fetchSponsorOptions loc=$location for $accountEmail');

    final response = await _httpClient.get<String>(
      '${AppConfig.sponsorEndpoint}&location=$location',
      accountEmail: accountEmail,
    );

    final raw = response.data;
    if (raw == null || raw.isEmpty) return [];

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final vars = data['vars'] as Map<String, dynamic>? ?? {};
      return SponsorOption.parseFromVars(vars);
    } catch (e) {
      debugPrint('[FinanceService] fetchSponsorOptions parse error: $e');
      return [];
    }
  }

  // ─── Sign sponsor ─────────────────────────────────────────

  /// Sign a sponsor contract.
  ///
  /// [eId]      — sponsor entity ID (from [SponsorOption.eId]).
  /// [location] — 1 = primary, 2 = secondary.
  ///
  /// GET /index.php?action=send&type=contract&enact=sign
  ///                          &eType=5&eId={eId}&location={location}&jsReply=contract
  Future<Map<String, dynamic>> signSponsor(
    String accountEmail, {
    required int eId,
    required int location,
  }) async {
    debugPrint(
        '[FinanceService] signSponsor eId=$eId loc=$location for $accountEmail');

    final response = await _httpClient.get<String>(
      '/index.php?action=send&type=contract&enact=sign'
      '&eType=5&eId=$eId&location=$location&jsReply=contract',
      accountEmail: accountEmail,
    );

    final raw = response.data;
    if (raw == null || raw.isEmpty) {
      throw ApiException('Empty response from signSponsor');
    }

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['error'] != null) throw ApiException(data['error'].toString());
      return data;
    } catch (e) {
      if (e is AppException) rethrow;
      throw ApiException('Non-JSON from signSponsor: $raw');
    }
  }
}