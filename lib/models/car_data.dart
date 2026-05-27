import 'dart:convert';
 
import 'package:flutter/foundation.dart';
 
/// Car research data parsed from fireUp preCache → p=cars → vars.carAttributes HTML.
///
/// Two HTML blobs are consumed:
///   vars['carAttributes'] — the main block containing the display section,
///                           both inline forms, and the leagueDesignData script.
///   vars['bonuses']       — contains the researchStrength / researchWeakness /
///                           researchMaxEffect hidden inputs.
///
/// Data sources within vars['carAttributes']:
///   Current values (WITH design bonus) → #carAttributesDisplay ratingVal spans,
///                                         anchored by id="wrap-{key}"
///   Base values (WITHOUT bonus)         → #researchInline ratingVal-striped spans,
///                                         in attribute-key order
///   Currently researching               → checked checkboxes in #researchInline
///   League max values                   → <script id="leagueDesignData"> JSON
///   Car / league IDs                    → hidden inputs inside #designInline
///   Rank on grid                        → #carAttributesRank text
 
// ─── Attribute constants ──────────────────────────────────────────────────────
 
/// All 8 attribute keys in the order the server returns them.
const _kAttrKeys = <String>[
  'acceleration', 'braking',    'cooling',      'downforce',
  'fuel_economy', 'handling',   'reliability',  'tyre_economy',
];
 
const _kAttrLabels = <String, String>{
  'acceleration': 'Acceleration',
  'braking':      'Braking',
  'cooling':      'Cooling',
  'downforce':    'Downforce',
  'fuel_economy': 'Fuel economy',
  'handling':     'Handling',
  'reliability':  'Reliability',
  'tyre_economy': 'Tyre economy',
};
 
// ─── CarAttribute ─────────────────────────────────────────────────────────────
 
class CarAttribute {
  final String key;
 
  /// Value shown in #carAttributesDisplay — includes design bonuses.
  final int currentValue;
 
  /// Raw value from #researchInline — no bonuses applied.
  final int baseValue;
 
  /// League cap from leagueDesignData JSON (max achievable in this league).
  final int leagueMax;
 
  /// currentValue − baseValue (can be negative for weaknesses).
  final int bonus;
 
  /// True when this attribute's checkbox is checked in #researchInline.
  final bool isResearching;
 
  /// Chief Designer's Strength (green icon in the UI).
  final bool isStrength;
 
  /// Chief Designer's Weakness (red icon in the UI).
  final bool isWeakness;
 
  const CarAttribute({
    required this.key,
    required this.currentValue,
    required this.baseValue,
    required this.leagueMax,
    required this.bonus,
    required this.isResearching,
    required this.isStrength,
    required this.isWeakness,
  });
 
  String get label => _kAttrLabels[key] ?? key;
 
  /// Fill ratio (0.0–1.0) of baseValue against the league cap.
  double get progress =>
      leagueMax > 0 ? (baseValue / leagueMax).clamp(0.0, 1.0) : 0.0;
 
  bool get isAtLeagueMax => baseValue >= leagueMax;
}
 
// ─── CarCondition ─────────────────────────────────────────────────────────────
 
/// Parts and engine repair state for one car, parsed from fireUp preCache vars.
///
/// Sources in preCache['p=cars']['vars']:
///   c{n}Condition — ratingCircle HTML  → partsValue via data-value
///   c{n}Engine    — ratingCircle HTML  → engineValue via data-value
///   c{n}CarBtn    — repair button HTML → carId, partsCost, partsLocked
///   c{n}EngBtn    — engine button HTML → engineCost, engineLocked
class CarCondition {
  final int    partsValue;   // 0-100
  final int    engineValue;  // 0-100
  final String carId;        // numeric car ID used in repair endpoints
  final int    partsCost;    // token cost shown on the repair parts button
  final int    engineCost;   // token cost shown on the replace engine button
  final bool   partsLocked;  // true when the disabled class is present (race live)
  final bool   engineLocked;
  final int    carNumber;    // 1 or 2
 
  const CarCondition({
    required this.partsValue,
    required this.engineValue,
    required this.carId,
    required this.partsCost,
    required this.engineCost,
    required this.partsLocked,
    required this.engineLocked,
    required this.carNumber,
  });
 
  /// Condition colour tier (matches the server's ratingCircle CSS class).
  bool get isGood     => partsValue >= 80 && engineValue >= 80;
  bool get needsWork  => !isGood && partsValue >= 50 && engineValue >= 50;
  bool get isCritical => partsValue < 50 || engineValue < 50;
 
  /// Parse from the vars map for car [carNum] (1 or 2).
  /// Returns null when the required keys are missing.
  static CarCondition? parseFromVars(Map<String, dynamic> vars, int carNum) {
    final condHtml = vars['c${carNum}Condition']?.toString() ?? '';
    final engHtml  = vars['c${carNum}Engine']?.toString()    ?? '';
    final partBtn  = vars['c${carNum}CarBtn']?.toString()    ?? '';
    final engBtn   = vars['c${carNum}EngBtn']?.toString()    ?? '';
 
    // Use whichever button is present to extract the car ID
    final carId = _extractCarId(partBtn.isNotEmpty ? partBtn : engBtn);
    if (carId.isEmpty && condHtml.isEmpty) return null;
 
    return CarCondition(
      partsValue:   _extractDataValue(condHtml),
      engineValue:  _extractDataValue(engHtml),
      carId:        carId,
      partsCost:    _extractCost(partBtn),
      engineCost:   _extractCost(engBtn),
      partsLocked:  partBtn.contains('disabled'),
      engineLocked: engBtn.contains('disabled'),
      carNumber:    carNum,
    );
  }
 
  // ── Parsers ────────────────────────────────────────────────────────────
 
  static int _extractDataValue(String html) {
    final m = RegExp(r'data-value="(\d+)"').firstMatch(html);
    return int.tryParse(m?.group(1) ?? '') ?? 0;
  }
 
  static String _extractCarId(String html) {
    final m = RegExp(r'car=(\d+)').firstMatch(html);
    return m?.group(1) ?? '';
  }
 
  /// Extracts the numeric cost that appears after the icon in button text.
  /// e.g. "Fix <icon>turbo</icon> 32</a>"  → 32
  ///      "Replace <icon>engine</icon> 1</a>" → 1
  static int _extractCost(String html) {
    final m = RegExp(r'</icon>\s*(\d+)\s*</a>', caseSensitive: false)
            .firstMatch(html)
        ?? RegExp(r'(\d+)\s*</a>', caseSensitive: false).firstMatch(html);
    return int.tryParse(m?.group(1) ?? '') ?? 0;
  }
}
 
// ─── CarData ──────────────────────────────────────────────────────────────────
 
class CarData {
  final List<CarAttribute> attributes;
 
  /// Attribute key of the Chief Designer's Strength, e.g. 'handling'.
  final String researchStrength;
 
  /// Attribute key of the Chief Designer's Weakness, e.g. 'fuel_economy'.
  final String researchWeakness;
 
  /// Maximum research effect in percent, e.g. 34.1.
  final double researchMaxEffect;
 
  /// Car's current rank on the grid (1-based; 0 = unavailable).
  final int rankOnGrid;
 
  /// Car design identifier, e.g. 'L' — from the hidden "car" input in #designInline.
  final String carDesignId;
 
  /// League ID used in the design endpoint — from the hidden "league" input in #designInline.
  final String designLeagueId;
 
  /// League ID for the research endpoint — from the hidden "league" input in #researchInline.
  /// The server often sends "0" here; use as-is when posting.
  final String researchLeagueId;
 
  /// Available design points to spend — from #carsDesignPoints[data-dp].
  final int designPoints;
 
  /// Hard attribute ceiling from vars.dMax (e.g. 300).
  /// leagueMax per attribute is ≤ dMax; this is the actual slider maximum.
  final int dMax;
 
  /// Combined TD + Chief Designer star rating (e.g. 4.5), from #carsResearch.
  /// Used in the estimated research gain formula.
  final double researchPower;
 
  /// Parts and engine repair state for car 1.
  /// Null when the vars keys are absent (e.g. fresh accounts).
  final CarCondition? car1Condition;
 
  /// Parts and engine repair state for car 2 (2-car leagues only).
  final CarCondition? car2Condition;
 
  const CarData({
    required this.attributes,
    required this.researchStrength,
    required this.researchWeakness,
    required this.researchMaxEffect,
    required this.rankOnGrid,
    required this.carDesignId,
    required this.designLeagueId,
    required this.researchLeagueId,
    required this.designPoints,
    required this.dMax,
    required this.researchPower,
    this.car1Condition,
    this.car2Condition,
  });
 
  /// Attribute keys that are currently queued for research (checked).
  List<String> get currentResearch =>
      attributes.where((a) => a.isResearching).map((a) => a.key).toList();
 
  CarAttribute? attributeByKey(String key) =>
      attributes.where((a) => a.key == key).firstOrNull;
 
  // ─── Entry point (mirrors DriverService.parseFromFireUp) ───────────────
 
  /// Parse from the full fireUp JSON response.
  ///
  /// Returns null when the p=cars preCache entry is absent or unparseable.
  static CarData? parseFromFireUp(Map<String, dynamic> fireUpJson) {
    try {
      final preCache = fireUpJson['preCache'] as Map<String, dynamic>?;
      if (preCache == null) return null;
 
      final cars = preCache['p=cars'] as Map<String, dynamic>?;
      if (cars == null) return null;
 
      final vars = cars['vars'] as Map<String, dynamic>?;
      if (vars == null) return null;
 
      final html        = vars['carAttributes']?.toString() ?? '';
      final bonusesHtml = vars['bonuses']?.toString()       ?? '';
      final liveryHtml  = vars['liveryTopRight']?.toString() ?? '';
      final dMax        = int.tryParse(vars['dMax']?.toString() ?? '') ?? 300;
      if (html.isEmpty) return null;
 
      return parseFromCarAttributesHtml(
        html, bonusesHtml,
        liveryHtml:     liveryHtml,
        dMax:           dMax,
        car1Condition:  CarCondition.parseFromVars(vars, 1),
        car2Condition:  CarCondition.parseFromVars(vars, 2),
      );
    } catch (e) {
      debugPrint('[CarData] parseFromFireUp error: $e');
      return null;
    }
  }
 
  // ─── Main HTML parser ───────────────────────────────────────────────────
 
  /// Parse from the two HTML strings.  Can be called directly in tests.
  ///
  /// [liveryHtml] — vars['liveryTopRight'] for DP and research power.
  /// [dMax]       — vars['dMax'] global attribute ceiling (default 300).
  static CarData? parseFromCarAttributesHtml(
    String html,
    String bonusesHtml, {
    String         liveryHtml    = '',
    int            dMax          = 300,
    CarCondition?  car1Condition,
    CarCondition?  car2Condition,
  }) {
    try {
      final currentValues = _parseCurrentValues(html);
      final baseValues    = _parseBaseValues(html);
      final checkedKeys   = _parseCheckedResearch(html);
      final leagueMaxes   = _parseLeagueMaxes(html);
 
      // Strength / weakness / max-effect come from hidden inputs in vars.bonuses
      final strength  = _parseHiddenInput(bonusesHtml, 'researchStrength');
      final weakness  = _parseHiddenInput(bonusesHtml, 'researchWeakness');
      final maxEffect = double.tryParse(
              _parseHiddenInput(bonusesHtml, 'researchMaxEffect')!) ??
          0.0;
 
      // Design points and research star rating — from vars.liveryTopRight
      final designPoints  = _parseDesignPoints(liveryHtml);
      final researchPower = _parseResearchPower(liveryHtml);
 
      // Rank on grid — text inside #carAttributesRank, e.g. "1st"
      final rankMatch = RegExp(
        r'id="carAttributesRank"[^>]*>.*?(\d+)\s*(?:st|nd|rd|th)',
        dotAll: true,
      ).firstMatch(html);
      final rank = int.tryParse(rankMatch?.group(1) ?? '') ?? 0;
 
      // car / league IDs from hidden inputs in #designInline
      final designSection = _extractSection(html, 'id="designInline"', '</form>');
      final carId         = _parseHiddenInput(designSection, 'car')
          ?? RegExp(r'name="car"\s+value="([^"]*)"').firstMatch(designSection)?.group(1)
          ?? '';
      final designLgId = RegExp(r'name="league"\s+value="([^"]*)"')
              .firstMatch(designSection)
              ?.group(1) ??
          '';
 
      // research league ID from #researchInline
      final researchSection = _extractSection(html, 'id="researchInline"', '</form>');
      final researchLgId    = RegExp(r'name="league"\s+value="([^"]*)"')
              .firstMatch(researchSection)
              ?.group(1) ??
          '0';
 
      final attributes = _kAttrKeys.map((key) {
        final current = currentValues[key] ?? 0;
        final base    = baseValues[key]    ?? current;
        return CarAttribute(
          key:          key,
          currentValue: current,
          baseValue:    base,
          leagueMax:    leagueMaxes[key] ?? dMax,
          bonus:        current - base,
          isResearching: checkedKeys.contains(key),
          isStrength:   key == strength,
          isWeakness:   key == weakness,
        );
      }).toList();
 
      final data = CarData(
        attributes:        attributes,
        researchStrength:  strength  ?? '',
        researchWeakness:  weakness  ?? '',
        researchMaxEffect: maxEffect,
        rankOnGrid:        rank,
        carDesignId:       carId,
        designLeagueId:    designLgId,
        researchLeagueId:  researchLgId,
        designPoints:      designPoints,
        dMax:              dMax,
        researchPower:     researchPower,
        car1Condition:     car1Condition,
        car2Condition:     car2Condition,
      );
 
      debugPrint('[CarData] Parsed: rank=${data.rankOnGrid}, '
          'dp=${data.designPoints}, rPower=${data.researchPower}, '
          'strength=$strength, weakness=$weakness, '
          'researching=${data.currentResearch}');
      return data;
    } catch (e) {
      debugPrint('[CarData] parseFromCarAttributesHtml error: $e');
      return null;
    }
  }
 
  // ─── Section parsers ────────────────────────────────────────────────────
 
  /// Current values WITH design bonuses from #carAttributesDisplay.
  ///
  /// Each attribute is anchored by id="wrap-{key}", so we locate each
  /// key independently — immune to reordering.
  static Map<String, int> _parseCurrentValues(String html) {
    // Slice to the display section only — stops before #designInline
    final displayStart = html.indexOf('id="carAttributesDisplay"');
    final designStart  = html.indexOf('id="designInline"');
    if (displayStart < 0) return {};
 
    final section = (designStart > displayStart)
        ? html.substring(displayStart, designStart)
        : html.substring(displayStart);
 
    final result = <String, int>{};
    for (final key in _kAttrKeys) {
      final anchor = section.indexOf('id="wrap-$key"');
      if (anchor < 0) continue;
      // Search within a bounded window (one attribute block ≈ 500 chars)
      final end   = (anchor + 600).clamp(0, section.length);
      final chunk = section.substring(anchor, end);
      // ratingVal spans in the display section are NOT tagged "striped"
      final m = RegExp(r'class="ratingVal[^"]*">(\d+)').firstMatch(chunk);
      if (m != null) result[key] = int.tryParse(m.group(1)!) ?? 0;
    }
    return result;
  }
 
  /// Base values WITHOUT bonuses from #researchInline.
  ///
  /// The ratingVal-striped spans appear in the same order as _kAttrKeys,
  /// which matches the leagueDesignData JSON key order — zip directly.
  static Map<String, int> _parseBaseValues(String html) {
    final result  = <String, int>{};
    final section = _extractSection(html, 'id="researchInline"', '</form>');
    if (section.isEmpty) return result;
 
    final re      = RegExp(r'class="ratingVal[^"]*striped[^"]*">(\d+)');
    final matches = re.allMatches(section).toList();
 
    for (var i = 0; i < matches.length && i < _kAttrKeys.length; i++) {
      result[_kAttrKeys[i]] = int.tryParse(matches[i].group(1)!) ?? 0;
    }
    return result;
  }
 
  /// Attribute keys whose checkboxes are checked in #researchInline.
  static List<String> _parseCheckedResearch(String html) {
    final checked = <String>[];
    final section = _extractSection(html, 'id="researchInline"', '</form>');
    if (section.isEmpty) return checked;
 
    // Match every <input type="checkbox" ...> in the form
    final re = RegExp(r'<input[^>]+type="checkbox"[^>]*/?>');
    for (final m in re.allMatches(section)) {
      final tag = m.group(0)!;
      if (!tag.contains('checked')) continue;
      final value = RegExp(r'\bvalue="(\w+)"').firstMatch(tag)?.group(1);
      if (value != null) checked.add(value);
    }
    return checked;
  }
 
  /// League-max values from the embedded <script id="leagueDesignData"> JSON.
  ///
  /// Shape: {"acceleration":{"max":68},"braking":{"max":45}, ...}
  static Map<String, int> _parseLeagueMaxes(String html) {
    final result = <String, int>{};
    final m = RegExp(
      r'id="leagueDesignData"[^>]*>(.*?)</script>',
      dotAll: true,
    ).firstMatch(html);
    if (m == null) return result;
 
    try {
      final json = jsonDecode(m.group(1)!.trim()) as Map<String, dynamic>;
      for (final entry in json.entries) {
        final max = (entry.value as Map<String, dynamic>)['max'];
        result[entry.key] =
            max is int ? max : int.tryParse(max.toString()) ?? 0;
      }
    } catch (_) {}
    return result;
  }
 
  // ─── Livery parsers (vars.liveryTopRight) ───────────────────────────────
 
  /// Available design points from data-dp="88" on #carsDesignPoints.
  static int _parseDesignPoints(String html) {
    if (html.isEmpty) return 0;
    final m = RegExp(r'id="carsDesignPoints"[^>]*data-dp="(\d+)"').firstMatch(html)
        ?? RegExp(r'data-dp="(\d+)"[^>]*id="carsDesignPoints"').firstMatch(html);
    if (m != null) return int.tryParse(m.group(1)!) ?? 0;
    // Fallback: read designPointsTotal span text
    final fb = RegExp(r'id="designPointsTotal"[^>]*>(\d+)').firstMatch(html);
    return int.tryParse(fb?.group(1) ?? '') ?? 0;
  }
 
  /// Research star rating (TD + Chief Designer combined) from #carsResearch.
  ///
  /// Counts <icon>star</icon> (full = 1.0) and
  ///         <icon>star-half-empty</icon> (half = 0.5).
  static double _parseResearchPower(String html) {
    if (html.isEmpty) return 0.0;
    final idx = html.indexOf('id="carsResearch"');
    if (idx < 0) return 0.0;
    // Cap the search window to this element only
    final chunk = html.substring(idx, (idx + 600).clamp(0, html.length));
    final full  = RegExp(r'<icon>star</icon>').allMatches(chunk).length;
    final half  = RegExp(r'<icon>star-half-empty</icon>').allMatches(chunk).length;
    return full + half * 0.5;
  }
 
  // ─── Generic helpers ────────────────────────────────────────────────────
 
  /// Value of a hidden <input id="{inputId}" value="..."> tag.
  static String? _parseHiddenInput(String html, String inputId) {
    final m = RegExp('id="$inputId"[^>]*value="([^"]*)"').firstMatch(html)
        ?? RegExp('value="([^"]*)"[^>]*id="$inputId"').firstMatch(html);
    return m?.group(1);
  }
 
  /// Slice HTML from [startMarker] to the first [endMarker] after it.
  static String _extractSection(
      String html, String startMarker, String endMarker) {
    final s = html.indexOf(startMarker);
    if (s < 0) return '';
    final e = html.indexOf(endMarker, s);
    return e > 0 ? html.substring(s, e) : html.substring(s);
  }
}