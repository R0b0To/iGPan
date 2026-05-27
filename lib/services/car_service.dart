import 'dart:convert';
 
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
 
import '../core/exceptions.dart';
import '../network/http_client.dart';
import '../network/interceptors/csrf_interceptor.dart';
 
/// Handles car-specific API submissions for a single account.
class CarService {
  final HttpClient _httpClient;
 
  CarService({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();
 
  // POST  action=send&addon=igp&type=research&jsReply=research&ajax=1
  static const _researchEndpoint =
      '/index.php?action=send&addon=igp&type=research&jsReply=research&ajax=1';
 
  // GET   action=send&addon=igp&type=design&jsReply=design&ajax=1 + query params
  static const _designBase =
      '/index.php?action=send&addon=igp&type=design&jsReply=design&ajax=1';
 
  // ─── Research ─────────────────────────────────────────────
 
  /// Submit a new attribute research selection.
  ///
  /// [leagueId]   — CarData.researchLeagueId
  /// [attributes] — list of attribute keys, e.g. ['braking', 'handling']
  ///
  /// POST body: league={leagueId}&c[]=attr1&c[]=attr2…
  Future<Map<String, dynamic>> submitResearch(
    String accountEmail, {
    required String       leagueId,
    required List<String> attributes,
  }) async {
    debugPrint('[CarService] submitResearch $accountEmail → $attributes');
 
    if (attributes.isEmpty) {
      throw const ApiException('No attributes selected for research');
    }
 
    final formData = FormData.fromMap({'league': leagueId});
    for (final attr in attributes) {
      formData.fields.add(MapEntry('c[]', attr));
    }
 
    final response = await _httpClient.post<String>(
      _researchEndpoint,
      accountEmail: accountEmail,
      data:         formData,
    );
    return _parseResponse(response.data, 'submitResearch');
  }
 
  // ─── Repair ───────────────────────────────────────────────
 
  /// Repair parts on car [carNumber] (1 or 2).
  ///
  /// GET /index.php?action=send&type=fix&car={carId}&btn=c{n}PartSwap&jsReply=fix
  Future<Map<String, dynamic>> repairParts(
    String accountEmail, {
    required String carId,
    required int    carNumber,
  }) async {
    debugPrint('[CarService] repairParts car$carNumber ($carId) for $accountEmail');
    final url =
        '/index.php?action=send&type=fix&car=$carId&btn=c${carNumber}PartSwap&jsReply=fix';
    final response =
        await _httpClient.get<String>(url, accountEmail: accountEmail);
    return _parseResponse(response.data, 'repairParts');
  }
 
  /// Replace engine on car [carNumber] (1 or 2).
  ///
  /// GET /index.php?action=send&type=engine&car={carId}&btn=c{n}EngSwap&jsReply=engine
  Future<Map<String, dynamic>> replaceEngine(
    String accountEmail, {
    required String carId,
    required int    carNumber,
  }) async {
    debugPrint('[CarService] replaceEngine car$carNumber ($carId) for $accountEmail');
    final url =
        '/index.php?action=send&type=engine&car=$carId&btn=c${carNumber}EngSwap&jsReply=engine';
    final response =
        await _httpClient.get<String>(url, accountEmail: accountEmail);
    return _parseResponse(response.data, 'replaceEngine');
  }
 
  // ─── Design ───────────────────────────────────────────────
 
  /// Submit design point allocation.
  ///
  /// [carId]            — CarData.carDesignId (e.g. 'L')
  /// [leagueId]         — CarData.designLeagueId
  /// [attributeValues]  — full map of all 8 attributes with their NEW values.
  ///                      Send all keys even if unchanged — server expects the
  ///                      complete allocation.
  ///
  /// The endpoint is a GET with all values and CSRF in the query string.
  Future<Map<String, dynamic>> submitDesign(
    String accountEmail, {
    required String           carId,
    required String           leagueId,
    required Map<String, int> attributeValues,
  }) async {
    debugPrint('[CarService] submitDesign $accountEmail → $attributeValues');
 
    // Build the full URL: base + car/league + one param per attribute + CSRF
    final buf = StringBuffer(_designBase);
    buf.write('&car=${Uri.encodeComponent(carId)}');
    buf.write('&league=${Uri.encodeComponent(leagueId)}');
    for (final e in attributeValues.entries) {
      buf.write('&${e.key}=${e.value}');
    }
    // CSRF interceptor caches the latest token from any prior response
    buf.write('&csrfName=${csrfInterceptor.name}');
    buf.write('&csrfToken=${csrfInterceptor.token}');
 
    final response = await _httpClient.get<String>(
      buf.toString(),
      accountEmail: accountEmail,
    );
    return _parseResponse(response.data, 'submitDesign');
  }
 
  // ─── Internal ─────────────────────────────────────────────
 
  Map<String, dynamic> _parseResponse(String? raw, String op) {
    if (raw == null || raw.isEmpty) {
      throw ApiException('Empty response from $op');
    }
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      if (data['error'] != null) throw ApiException(data['error'].toString());
      return data;
    } catch (e) {
      if (e is AppException) rethrow;
      throw ApiException('Non-JSON response from $op: $raw');
    }
  }
}