import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/exceptions.dart';
import '../network/http_client.dart';

/// Handles staff and driver contract operations.
///
/// Contract entity types used by the server:
///   eType=2 → staff (Chief Designer, Technical Director, Doctor, reserve staff)
///   eType=3 → driver (active main-slot drivers)
class StaffService {
  final HttpClient _httpClient;

  StaffService({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  // ─── Fetch staff detail ────────────────────────────────────────────────

  /// Fetch full staff profile for [staffId].
  ///
  /// GET /index.php?action=fetch&d=staff&id={staffId}&csrfName=&csrfToken=
  ///
  /// The response vars.contract HTML contains current salary, contract length,
  /// extension cost, and sell price — useful for showing exact terms before
  /// the user commits to an action.
  Future<Map<String, dynamic>> fetchStaffDetail(
    String accountEmail, {
    required String staffId,
  }) async {
    debugPrint('[StaffService] fetchStaffDetail $staffId for $accountEmail');
    final response = await _httpClient.get<String>(
      '/index.php?action=fetch&d=staff&id=$staffId&csrfName=&csrfToken=',
      accountEmail: accountEmail,
    );
    return _parse(response.data, 'fetchStaffDetail');
  }

  // ─── Fetch driver detail ───────────────────────────────────────────────

  /// Fetch full driver profile for [driverId].
  ///
  /// GET /index.php?action=fetch&d=driver&id={driverId}
  Future<Map<String, dynamic>> fetchDriverDetail(
    String accountEmail, {
    required String driverId,
  }) async {
    debugPrint('[StaffService] fetchDriverDetail $driverId for $accountEmail');
    final response = await _httpClient.get<String>(
      '/index.php?action=fetch&d=driver&id=$driverId&csrfName=&csrfToken=',
      accountEmail: accountEmail,
    );
    return _parse(response.data, 'fetchDriverDetail');
  }

  // ─── Extend contract ───────────────────────────────────────────────────

  /// Extend the contract for a staff member or driver.
  ///
  /// [entityId]  — the numeric ID (staffId or driverId).
  /// [isDriver]  — true for active drivers (eType=3), false for all staff (eType=2).
  ///
  /// GET /index.php?action=send&type=contract&enact=extend
  ///                          &eType={2|3}&eId={id}&jsReply=contract
  Future<Map<String, dynamic>> extendContract(
    String accountEmail, {
    required String entityId,
    required bool isDriver,
  }) async {
    final eType = isDriver ? 3 : 2;
    debugPrint(
        '[StaffService] extendContract eType=$eType eId=$entityId for $accountEmail');
    final response = await _httpClient.get<String>(
      '/index.php?action=send&type=contract&enact=extend'
      '&eType=$eType&eId=$entityId&jsReply=contract',
      accountEmail: accountEmail,
    );
    return _parse(response.data, 'extendContract');
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
