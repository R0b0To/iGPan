import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/exceptions.dart';
import '../models/hq_data.dart';
import '../network/http_client.dart';

/// Handles all HQ / facility API calls for a single account.
class HqService {
  final HttpClient _httpClient;

  HqService({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  // ─── Fetch facility detail ─────────────────────────────────────────────

  /// Fetch full facility data for [facilityId] (the facility type ID, e.g. "1").
  ///
  /// GET /index.php?action=fetch&d=facility&id={facilityId}&csrfName=&csrfToken=
  Future<HqFacilityDetail> fetchFacility(
    String accountEmail, {
    required String facilityId,
  }) async {
    debugPrint('[HqService] fetchFacility $facilityId for $accountEmail');

    final response = await _httpClient.get<String>(
      '/index.php?action=fetch&d=facility&id=$facilityId&csrfName=&csrfToken=',
      accountEmail: accountEmail,
    );

    final data = _parse(response.data, 'fetchFacility');
    final vars = data['vars'] as Map<String, dynamic>? ?? {};
    return HqFacilityDetail.fromVars(facilityId, vars);
  }

  // ─── Repair (maintenance) ──────────────────────────────────────────────

  /// Perform maintenance on a facility.
  ///
  /// [fId] is the facility *instance* ID from HqFacilityDetail.fId
  /// (e.g. "9843427") — NOT the facility type ID.
  ///
  /// GET /index.php?action=send&type=hqRepair&fId={fId}&csrfName=&csrfToken=
  Future<Map<String, dynamic>> repairFacility(
    String accountEmail, {
    required String fId,
  }) async {
    debugPrint('[HqService] repairFacility fId=$fId for $accountEmail');

    final response = await _httpClient.get<String>(
      '/index.php?action=send&type=hqRepair&fId=$fId&csrfName=&csrfToken=',
      accountEmail: accountEmail,
    );
    return _parse(response.data, 'repairFacility');
  }

  // ─── Upgrade ──────────────────────────────────────────────────────────

  /// Start an upgrade for the facility type [fType] (e.g. "1" for Manufacturing).
  ///
  /// GET /index.php?action=send&type=build&fType={fType}&csrfName=&csrfToken=
  Future<Map<String, dynamic>> upgradeFacility(
    String accountEmail, {
    required String fType,
  }) async {
    debugPrint('[HqService] upgradeFacility fType=$fType for $accountEmail');

    final response = await _httpClient.get<String>(
      '/index.php?action=send&type=build&fType=$fType&csrfName=&csrfToken=',
      accountEmail: accountEmail,
    );
    return _parse(response.data, 'upgradeFacility');
  }

  // ─── Internal ─────────────────────────────────────────────────────────

  Map<String, dynamic> _parse(String? raw, String op) {
    if (raw == null || raw.isEmpty) {
      throw ApiException('Empty response from $op');
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['error'] != null) throw ApiException(data['error'].toString());
      return data;
    } catch (e) {
      if (e is AppException) rethrow;
      throw ApiException('Non-JSON from $op: $raw');
    }
  }
}
