import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../core/exceptions.dart';
import '../models/finance_data.dart';
import '../network/http_client.dart';

class FinanceService {
  final HttpClient _httpClient;

  FinanceService({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  static const String _endpoint =
      '/index.php?action=fetch&p=finances&csrfName=&csrfToken=';

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
}
