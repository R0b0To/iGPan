import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';

import '../core/app_config.dart';
import '../core/exceptions.dart';
import '../models/race_data.dart';
import '../network/http_client.dart';
import '../network/interceptors/csrf_interceptor.dart';

/// Handles race-related API calls for a single account.
///
/// Only three live endpoints:
///   1. fetchRaceData  — GET  action=fetch&p=race
///   2. simulatePracticeLap — GET action=send&addon=igp&type=setup  (practice lap only)
///   3. saveAll        — POST action=send&type=saveAll  (setup + strategy together)
class RaceService {
  final HttpClient _httpClient;

  RaceService({HttpClient? httpClient})
      : _httpClient = httpClient ?? HttpClient();

  // ─── Fetch race page ──────────────────────────────────────

  /// Fetch the current race page.
  /// Response: { vars: {...}, nextLeagueRaceTime: ..., _balance: ..., ... }
  Future<RaceData> fetchRaceData(String accountEmail) async {
    debugPrint('[RaceService] Fetching race data for $accountEmail');

    final response = await _httpClient.get<String>(
      AppConfig.raceEndpoint,
      accountEmail: accountEmail,
    );

    final raw = response.data;
    if (raw == null || raw.isEmpty) {
      throw ApiException('Empty race response for $accountEmail');
    }

    final Map<String, dynamic> json;
    try {
      json = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      throw ApiException('Non-JSON race response for $accountEmail');
    }

    final vars = json['vars'] as Map<String, dynamic>?;
    if (vars == null) {
      throw ApiException('Missing vars in race response for $accountEmail');
    }

    return RaceData.fromJson(json);
  }

  // ─── Practice lap ─────────────────────────────────────────

  /// Simulate a practice lap for car [dNum] with the given setup.
  ///
  /// GET /index.php?action=send&addon=igp&type=setup&dNum=1&ajax=1
  ///     &race={raceId}&ride={ride}&suspension={susp}&rwing={wing}
  ///     &practiceTyre={tyre}&csrfName=&csrfToken=
  ///
  /// Response includes chevronFeedback (increase/decrease/remove per slider)
  /// and updateRanges for the ideal range visualisation.
  Future<Map<String, dynamic>> simulatePracticeLap(
    String accountEmail, {
    required String raceId,
    required int    dNum,
    required int    ride,
    required int    suspension,
    required int    wing,
    required String practiceTyre,
  }) async {
    debugPrint('[RaceService] Practice lap car $dNum for $accountEmail');

    final url = '/index.php?action=send&addon=igp&type=setup'
        '&dNum=$dNum'
        '&ajax=1'
        '&race=$raceId'
        '&ride=$ride'
        '&suspension=$suspension'
        '&rwing=$wing'
        '&practiceTyre=$practiceTyre'
        '&csrfName=&csrfToken=';

    final response = await _httpClient.get<String>(
      url,
      accountEmail: accountEmail,
    );

    return _parseResponse(response.data, 'simulatePracticeLap');
  }

  // ─── Save all ─────────────────────────────────────────────

  /// Save setup AND strategy for both cars in a single POST.
  ///
  /// Endpoint: POST /index.php?action=send&type=saveAll&addon=igp&ajax=1
  ///                           &jsReply=saveAll&pageId=race
  ///
  /// Headers: X-CSRF-Name + X-CSRF-Token (injected automatically by CsrfInterceptor).
  ///
  /// Body shape (JSON):
  /// {
  ///   d1setup:            { race, ride, suspension, rwing, practiceTyre },
  ///   d2setup:            { race } | { race, ride, suspension, rwing, practiceTyre },
  ///   d1strategy:         { race, dNum, numPits, tyre1-5, fuel1-5, laps1-5 },
  ///   d1strategyAdvanced: { pushLevel, d1SavedStrategy, ignoreAdvancedStrategy,
  ///                         advancedFuel (only when refuelling=0),
  ///                         rainStartDepth, rainStartTyre, rainStopLap, rainStopTyre },
  ///   d2strategy:         { race, dNum, numPits } | full stints,
  ///   d2strategyAdvanced: { pushLevel, d2SavedStrategy, ignoreAdvancedStrategy,
  ///                         advancedFuel (only when refuelling=0),
  ///                         rainStartDepth, rainStartTyre, rainStopLap, rainStopTyre },
  /// }
  ///
  /// Fuel per stint = ceil(laps × fuelPerLap) when refuelling is enabled,
  /// otherwise laps-based only and advancedFuel covers the full race.
  Future<Map<String, dynamic>> saveAll({
    required String accountEmail, 
    required String  raceId,
    required bool    twoCars,
    required bool    refuelling,     // from race vars rulesJson.refuelling == '1'

    // ── Car 1 ──────────────────────────────────────────────
    required int     d1Ride,
    required int     d1Suspension,
    required int     d1Wing,
    required String  d1PracticeTyre,
    required List<Map<String, dynamic>> d1Stints,  // each: {tyre, laps, fuelPerLap}
    required int     d1NumPits,
    required int     d1AdvancedFuel,  // from race vars d1AdvancedFuel (total fuel)
    int    d1PushLevel      = 60,
    String d1RainStartTyre  = 'I',
    int    d1RainStartDepth = 0,
    String d1RainStopTyre   = 'M',
    int    d1RainStopLap    = 0,
    bool   d1Saved          = true,
    bool   d1IgnoreAdvanced = false,

    // ── Car 2 (only when twoCars=true) ─────────────────────
    int    d2Ride           = 50,
    int    d2Suspension     = 50,
    int    d2Wing           = 50,
    String d2PracticeTyre   = 'SS',
    List<Map<String, dynamic>> d2Stints = const [],
    int    d2NumPits        = 0,
    int    d2AdvancedFuel   = 0,
    int    d2PushLevel      = 60,
    String d2RainStartTyre  = 'I',
    int    d2RainStartDepth = 0,
    String d2RainStopTyre   = 'M',
    int    d2RainStopLap    = 0,
    bool   d2Saved          = false,
    bool   d2IgnoreAdvanced = false,
  }) async {
    debugPrint('[RaceService] saveAll (twoCars:$twoCars refuelling:$refuelling) for $accountEmail');

    // ── Build stint map ─────────────────────────────────────
  // ── Build stint map ─────────────────────────────────────
// ── Build stint map ─────────────────────────────────────
  Map<String, String> _stintMap(
      String dNum, int numPits, List<Map<String, dynamic>> stints, int advancedFuel) {
    
    final m = <String, String>{
      'race':    raceId,
      'dNum':    dNum,
      'numPits': numPits.toString(),
    };

    for (var i = 0; i < 5; i++) {
      final n = i + 1;
      if (i < stints.length) {
        final laps = stints[i]['laps'] as int? ?? 0;
        final fuelPerLap = stints[i]['fuelPerLap'] as double? ?? 0.0;
        
        String fuelValue;
        if (refuelling) {
          // FIX: Read the exact fuel value provided by the UI!
          // Fall back to recalculation only if it's missing for some reason.
          final explicitFuel = stints[i]['fuel'] as int?;
          if (explicitFuel != null) {
            fuelValue = explicitFuel.toString();
          } else {
            fuelValue = (laps * fuelPerLap).ceil().toString();
          }
        } else {
          // NO REFUELLING: 
          // Stint 1 gets the total fuel, all other stints get 0
          fuelValue = (i == 0) ? advancedFuel.toString() : "0";
        }

        m['tyre$n'] = stints[i]['tyre']?.toString() ?? 'M';
        m['laps$n'] = laps.toString();
        m['fuel$n'] = fuelValue;
      } else {
        // Unused stints
        m['tyre$n'] = '';
        m['laps$n'] = '1';
        m['fuel$n'] = "0"; // Changed from '1' to '0' to match game
      }
    }
    return m;
  }
    // ── Build advanced strategy map ─────────────────────────
    Map<String, String> _advancedMap({
      required String savedKey,
      required bool   saved,
      required bool   ignoreAdv,
      required int    pushLevel,
      required int    advancedFuel,
      required String rainStartTyre,
      required int    rainStartDepth,
      required String rainStopTyre,
      required int    rainStopLap,
    }) {
      final m = <String, String>{
        'pushLevel':              pushLevel.toString(),
        savedKey:                 saved ? '1' : '0',
        'ignoreAdvancedStrategy': ignoreAdv ? '1' : '0',
        'rainStartDepth':         rainStartDepth.toString(),
        'rainStartTyre':          rainStartTyre,
        'rainStopLap':            rainStopLap.toString(),
        'rainStopTyre':           rainStopTyre,
      };
      // advancedFuel only included when refuelling is NOT allowed
      // (server uses it as total race fuel when refuelling=0)
      if (!refuelling) {
        m['advancedFuel'] = advancedFuel.toString();
      }
      return m;
    }

    final body = <String, dynamic>{
      // ── Setup ──────────────────────────────────────────────
      'd1setup': {
        'race':         raceId,
        'ride':         d1Ride.toString(),
        'suspension':   d1Suspension.toString(),
        'rwing':        d1Wing.toString(),
        'practiceTyre': d1PracticeTyre,
      },
      'd2setup': twoCars
          ? {
              'race':         raceId,
              'ride':         d2Ride.toString(),
              'suspension':   d2Suspension.toString(),
              'rwing':        d2Wing.toString(),
              'practiceTyre': d2PracticeTyre,
            }
          : {'race': raceId},

// ── Strategy ───────────────────────────────────────────
'd1strategy': _stintMap('1', d1NumPits, d1Stints, d1AdvancedFuel), // Added d1AdvancedFuel
'd2strategy': twoCars
    ? _stintMap('2', d2NumPits, d2Stints, d2AdvancedFuel) // Added d2AdvancedFuel
    : {'race': raceId, 'dNum': '2', 'numPits': '0'},

      // ── Advanced ───────────────────────────────────────────
      'd1strategyAdvanced': _advancedMap(
        savedKey:       'd1SavedStrategy',
        saved:          d1Saved,
        ignoreAdv:      d1IgnoreAdvanced,
        pushLevel:      d1PushLevel,
        advancedFuel:   d1AdvancedFuel,
        rainStartTyre:  d1RainStartTyre,
        rainStartDepth: d1RainStartDepth,
        rainStopTyre:   d1RainStopTyre,
        rainStopLap:    d1RainStopLap,
      ),
      'd2strategyAdvanced': twoCars
          ? _advancedMap(
              savedKey:       'd2SavedStrategy',
              saved:          d2Saved,
              ignoreAdv:      d2IgnoreAdvanced,
              pushLevel:      d2PushLevel,
              advancedFuel:   d2AdvancedFuel,
              rainStartTyre:  d2RainStartTyre,
              rainStartDepth: d2RainStartDepth,
              rainStopTyre:   d2RainStopTyre,
              rainStopLap:    d2RainStopLap,
            )
          : {
              'd2SavedStrategy':        '0',
              'ignoreAdvancedStrategy': '0',
            },
    };

    final response = await _httpClient.post<String>(
      AppConfig.saveAllEndpoint,
      accountEmail: accountEmail,
      data:         body,
    );

    return _parseResponse(response.data, 'saveAll');
  }

  // ─── Internal ─────────────────────────────────────────────

  Map<String, dynamic> _parseResponse(String? raw, String operation) {
    if (raw == null || raw.isEmpty) {
      throw ApiException('Empty response from $operation');
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