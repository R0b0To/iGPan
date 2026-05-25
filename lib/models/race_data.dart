import 'dart:convert';
 
/// Race page data parsed from the p=race endpoint.
/// All game data lives in vars. Strategy/stint data is parsed from
/// the embedded d1StrategyJson / d2StrategyJson script tags.
class RaceData {
  // ─── Race identity ─────────────────────────────────────────
  final String raceId;
  final String raceName;
  final int    raceLaps;
  final String raceTrackId;
  final String raceTrackFlag;  // 2-letter country code, e.g. "fr", "gb"
  final String raceTime;
  final int    raceRoundNum;
  final int    raceTotalRounds;
 
  // ─── Timing ────────────────────────────────────────────────
  final DateTime? nextRaceTime;
  final String?   nextRaceId;
 
  // ─── State ─────────────────────────────────────────────────
  final bool raceLocked;
 
  // ─── Car 1 setup ───────────────────────────────────────────
  final int    d1Ride;
  final int    d1Suspension;
  final int    d1Aerodynamics;
  final String d1PracticeTyre;
  final double d1FuelPrediction;
  final int    d1TotalLaps;
  final int    d1Pits;
  final bool   d1Saved;
  final int    d1PushLevel;      // parsed from d1PushLevel select HTML
  final int    d1AdvancedFuel;   // parsed from d1AdvancedFuel HTML (refuelling=0 only)
 
  // ─── Car 1 stints (from d1StrategyJson) ───────────────────
  final List<StintData> d1Stints;
 
  // ─── Car 2 setup ───────────────────────────────────────────
  final int    d2Ride;
  final int    d2Suspension;
  final int    d2Aerodynamics;
  final String d2PracticeTyre;
  final double d2FuelPrediction;
  final int    d2TotalLaps;
  final int    d2Pits;
  final bool   d2Saved;
  final int    d2PushLevel;
  final int    d2AdvancedFuel;
 
  // ─── Car 2 stints ─────────────────────────────────────────
  final List<StintData> d2Stints;
 
  // ─── Rules ─────────────────────────────────────────────────
  final bool refuelling;
  final bool twoTyreRule;
 
  // ─── Driver info ───────────────────────────────────────────
  final String? d1DriverId;
  final String? d1DriverName;
  final String? d2DriverId;
  final String? d2DriverName;
 
  // ─── Balance snapshot ─────────────────────────────────────
  final int balance;
  final int tokens;
 
  const RaceData({
    required this.raceId,
    required this.raceName,
    required this.raceLaps,
    required this.raceTrackId,
    required this.raceTrackFlag,
    required this.raceTime,
    required this.raceRoundNum,
    required this.raceTotalRounds,
    this.nextRaceTime,
    this.nextRaceId,
    required this.raceLocked,
    required this.d1Ride,
    required this.d1Suspension,
    required this.d1Aerodynamics,
    required this.d1PracticeTyre,
    required this.d1FuelPrediction,
    required this.d1TotalLaps,
    required this.d1Pits,
    required this.d1Saved,
    required this.d1PushLevel,
    required this.d1AdvancedFuel,
    required this.d1Stints,
    required this.d2Ride,
    required this.d2Suspension,
    required this.d2Aerodynamics,
    required this.d2PracticeTyre,
    required this.d2FuelPrediction,
    required this.d2TotalLaps,
    required this.d2Pits,
    required this.d2Saved,
    required this.d2PushLevel,
    required this.d2AdvancedFuel,
    required this.d2Stints,
    required this.refuelling,
    required this.twoTyreRule,
    this.d1DriverId,
    this.d1DriverName,
    this.d2DriverId,
    this.d2DriverName,
    required this.balance,
    required this.tokens,
  });
 
  factory RaceData.fromJson(Map<String, dynamic> json) {
    final vars = json['vars'] as Map<String, dynamic>? ?? {};
 
    // ── Rules ──────────────────────────────────────────────
    var rules = <String, dynamic>{};
    try {
      final s = vars['rulesJson']?.toString() ?? '{}';
      if (s.isNotEmpty) rules = jsonDecode(s) as Map<String, dynamic>;
    } catch (_) {}
 
    final isRefuelling = rules['refuelling']?.toString() == '1';
 
    // ── Next race time ──────────────────────────────────────
    DateTime? nextRaceTime;
    final ts = int.tryParse(json['nextLeagueRaceTime']?.toString() ?? '');
    if (ts != null) {
      nextRaceTime = DateTime.fromMillisecondsSinceEpoch(ts * 1000);
    }
 
    // ── Is 2-car league? ────────────────────────────────────
    // d2Disable is empty string in 2-car, " disabled tooltip" in 1-car
    final twoCars = (vars['d2Disable']?.toString() ?? '').trim().isEmpty;
 
    // ── Parse stints from StrategyJson ──────────────────────
    final d1Stints = _parseStrategyJson(vars['d1StintCards']?.toString() ?? '', 'd1StrategyJson');
    final d2Stints = twoCars
        ? _parseStrategyJson(vars['d2StintCards']?.toString() ?? '', 'd2StrategyJson')
        : <StintData>[];
 
    // ── d2 setup — only valid when twoCars ──────────────────
    // In 1-car leagues d2Ride/d2Aerodynamics are 0 (intentional, not missing)
    // so we use 50 as default only for 2-car leagues
    final d2RideRaw = _toInt(vars['d2Ride']);
    final d2SuspRaw = _toInt(vars['d2Suspension']);
    final d2AeroRaw = _toInt(vars['d2Aerodynamics']);
 
    return RaceData(
      raceId:          vars['raceId']?.toString()          ?? '',
      raceName:        _stripHtml(vars['raceName']?.toString() ?? ''),
      raceLaps:        _toInt(vars['raceLaps']),
      raceTrackId:     vars['raceTrackId']?.toString()     ?? '1',
      raceTrackFlag:   _extractFlagCode(vars['raceName']?.toString() ?? ''),
      raceTime:        _stripHtml(vars['raceTime']?.toString() ?? ''),
      raceRoundNum:    _toInt(vars['raceRoundNum']),
      raceTotalRounds: _toInt(vars['raceTotalRounds']),
      nextRaceTime:    nextRaceTime,
      nextRaceId:      json['nextLeagueRaceId']?.toString(),
      raceLocked:      (vars['raceLocked']?.toString() ?? '').isNotEmpty,
 
      // ── Car 1 ──────────────────────────────────────────────
      // d1 values always come as strings in the real response
      d1Ride:           _toIntMin1(vars['d1Ride']),
      d1Suspension:     _toIntMin1(vars['d1Suspension']),
      d1Aerodynamics:   _toIntMin1(vars['d1Aerodynamics']),
      d1PracticeTyre:   vars['d1PracticeTyre']?.toString()  ?? 'M',
      d1FuelPrediction: _toDouble(vars['d1FuelPrediction']),
      d1TotalLaps:      _toInt(vars['d1TotalLaps']),
      d1Pits:           _toInt(vars['d1Pits']),
      d1Saved:          _toInt(vars['d1Saved']) == 1,
      d1PushLevel:      _parsePushLevel(vars['d1PushLevel']?.toString() ?? ''),
      d1AdvancedFuel:   _parseAdvancedFuel(vars['d1AdvancedFuel']?.toString() ?? ''),
      d1Stints:         d1Stints,
 
      // ── Car 2 ──────────────────────────────────────────────
      // Only use parsed values when twoCars — otherwise keep 0
      d2Ride:           twoCars ? _toIntMin1Fallback(d2RideRaw, 50) : d2RideRaw,
      d2Suspension:     twoCars ? _toIntMin1Fallback(d2SuspRaw, 50) : d2SuspRaw,
      d2Aerodynamics:   twoCars ? _toIntMin1Fallback(d2AeroRaw, 50) : d2AeroRaw,
      d2PracticeTyre:   vars['d2PracticeTyre']?.toString()  ?? 'SS',
      d2FuelPrediction: _toDouble(vars['d2FuelPrediction']),
      d2TotalLaps:      _toInt(vars['d2TotalLaps']),
      d2Pits:           _toInt(vars['d2Pits']),
      d2Saved:          _toInt(vars['d2Saved']) == 1,
      d2PushLevel:      _parsePushLevel(vars['d2PushLevel']?.toString() ?? ''),
      d2AdvancedFuel:   _parseAdvancedFuel(vars['d2AdvancedFuel']?.toString() ?? ''),
      d2Stints:         d2Stints,
 
      refuelling:      isRefuelling,
      twoTyreRule:     rules['two_tyres']?.toString() == '1',
      d1DriverId:      vars['d1Id']?.toString(),
      d1DriverName:    vars['d1Name']?.toString(),
      d2DriverId:      vars['d2Id']?.toString(),
      d2DriverName:    vars['d2Name']?.toString(),
      balance:         _toInt(json['_balance']),
      tokens:          _toInt(json['_tokens']),
    );
  }
 
  // ─── Computed ──────────────────────────────────────────────
 
  bool get raceImminent {
    if (nextRaceTime == null) return false;
    return nextRaceTime!.difference(DateTime.now()).inHours < 1;
  }
 
  bool get raceIsLive => raceLocked;
 
  String get countdownLabel {
    if (nextRaceTime == null) return '—';
    final diff = nextRaceTime!.difference(DateTime.now());
    if (diff.isNegative)  return 'Live';
    if (diff.inDays > 0)  return '${diff.inDays}d ${diff.inHours.remainder(24)}h';
    if (diff.inHours > 0) return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
    return '${diff.inMinutes}m';
  }
 
  // ─── Static parsers ────────────────────────────────────────
 
  static int _toInt(dynamic v) =>
      v == null ? 0 : int.tryParse(v.toString()) ?? 0;
 
  /// Parse int, minimum 1 — for slider values that must be in 1-100 range.
  static int _toIntMin1(dynamic v) {
    final i = _toInt(v);
    return i < 1 ? 1 : i;
  }
 
  /// Parse int with fallback when result is 0 — for d2 values in 2-car leagues.
  static int _toIntMin1Fallback(int v, int fallback) =>
      v < 1 ? fallback : v;
 
  static double _toDouble(dynamic v) =>
      v == null ? 0.0 : double.tryParse(v.toString()) ?? 0.0;
 
  /// Parse push level from the select HTML:
  /// '<option value="100">Very high</option><option value="60" selected>...'
  /// Extracts the value attribute of the option that has 'selected'.
  static int _parsePushLevel(String html) {
    if (html.isEmpty) return 60;
    final m = RegExp(r'value="(\d+)"[^>]*selected').firstMatch(html);
    if (m != null) return int.tryParse(m.group(1)!) ?? 60;
    // Also try 'selected' before 'value' ordering
    final m2 = RegExp(r'selected[^>]*value="(\d+)"').firstMatch(html);
    return int.tryParse(m2?.group(1) ?? '') ?? 60;
  }
 
  /// Parse advancedFuel:
  ///   - Empty string ("") when refuelling=1 (not needed) → 0
  ///   - HTML string with value="35" when refuelling=0 → 35
  static int _parseAdvancedFuel(String raw) {
    if (raw.trim().isEmpty) return 0;
    // Direct int
    final direct = int.tryParse(raw.trim());
    if (direct != null) return direct;
    // Extract value from <input ... value="35" ...>
    final m = RegExp(r'value="(\d+)"').firstMatch(raw);
    return int.tryParse(m?.group(1) ?? '') ?? 0;
  }
 
  /// Parse stints from the d1StrategyJson / d2StrategyJson embedded script tag
  /// inside the StintCards HTML string.
  ///
  /// The JSON has shape:
  /// { "stint": { "1": {"tyre":"S","fuel":"18","laps":"5"}, "2": {...}, ... },
  ///   "pits": "3", "stints": 4 }
  ///
  /// "stints" = number of active stints (not counting the 5th hidden one).
  static List<StintData> _parseStrategyJson(String stintCardsHtml, String scriptId) {
    if (stintCardsHtml.isEmpty) return [];
 
    try {
      // Extract the JSON from <script type="application/json" id="d1StrategyJson">...</script>
      final scriptRe = RegExp(
        r'<script[^>]*id="' + scriptId + r'"[^>]*>(.*?)</script>',
        dotAll: true,
      );
      final match = scriptRe.firstMatch(stintCardsHtml);
      if (match == null) return [];
 
      final jsonStr = match.group(1)?.trim() ?? '';
      if (jsonStr.isEmpty) return [];
 
      final data = jsonDecode(jsonStr) as Map<String, dynamic>;
      final stintMap = data['stint'] as Map<String, dynamic>? ?? {};
      final activeStints = _toInt(data['stints']); // number of visible stints
 
      final stints = <StintData>[];
      for (var i = 1; i <= 5; i++) {
        final s = stintMap[i.toString()] as Map<String, dynamic>?;
        if (s == null) break;
        // Only include up to 'stints' count of active stints
        if (i > activeStints && activeStints > 0) break;
        stints.add(StintData(
          tyre: s['tyre']?.toString() ?? 'M',
          fuel: _toInt(s['fuel']),
          laps: _toInt(s['laps']),
        ));
      }
 
      return stints;
    } catch (e) {
      return [];
    }
  }
 
  static String _stripHtml(String s) =>
      s.replaceAll(RegExp(r'<[^>]*>'), '').replaceAll('\uFEFF', '').trim();
 
  /// Extract 2-letter country code from raceName HTML.
  /// e.g. '<img class="flag f-fr ..."/> France (24 laps)' → 'fr'
  static String _extractFlagCode(String raceNameHtml) {
    final m = RegExp(r'flag f-([a-z]{2})').firstMatch(raceNameHtml);
    return m?.group(1) ?? '';
  }
}
 
/// One stint from the saved strategy.
class StintData {
  final String tyre;
  final int    fuel;
  final int    laps;
 
  const StintData({required this.tyre, required this.fuel, required this.laps});
 
  Map<String, dynamic> toMap() => {'tyre': tyre, 'fuel': fuel, 'laps': laps};
 
  @override
  String toString() => 'Stint($tyre, laps:$laps, fuel:$fuel)';
}
