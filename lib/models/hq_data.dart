import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

// ─── HqFacility ───────────────────────────────────────────────────────────────

/// Basic facility info available from the fireUp response.
///
/// Source: preCache['p=headquarters']['vars']['json'] — a JSON array
/// of facility objects, one per building owned by the team.
class HqFacility {
  final String id;          // server facility type ID, e.g. "1"
  final String name;        // cleaned name, e.g. "Manufacturing"
  final String svgId;       // stable key: 'manufacturing', 'design', etc.
  final int    stars;       // full star count
  final bool   hasHalfStar;
  final int    condition;   // 0-100
  
  /// Non-null when there are items ready to collect in this facility.
  final String? collectUrl;
  /// Human-readable summary of what is ready to collect, e.g. "59 parts  7 engines".
  final String? collectLabel;


  const HqFacility({
    required this.id,
    required this.name,
    required this.svgId,
    required this.stars,
    required this.hasHalfStar,
    required this.condition,
    this.collectUrl,
    this.collectLabel,
  });

  bool get hasCollectable => collectUrl != null;

  Color get conditionColor {
    if (condition >= 80) return const Color(0xFF1D9E75); // green
    if (condition >= 50) return const Color(0xFFE8A020); // amber
    return const Color(0xFFE24B4A);                       // red
  }

  /// Material icon for this facility type.
  static IconData iconFor(String svgId) => switch (svgId) {
        'manufacturing' => Icons.precision_manufacturing_outlined,
        'design'        => Icons.science_outlined,
        'technology'    => Icons.memory_outlined,
        'simulator'     => Icons.sports_motorsports_outlined,
        'offices'       => Icons.business_outlined,
        'yda'           => Icons.school_outlined,
        _               => Icons.domain_outlined,
      };

  factory HqFacility.fromJson(Map<String, dynamic> json) {
    // Name: strip <icon …>…</icon> tags
    final rawName = json['name']?.toString() ?? '';
    final name = rawName.replaceAll(RegExp(r'<[^>]*>'), '').trim();

    // Stars: the field is HTML-entity-encoded HTML, decode first
    final starsHtml = _htmlDecode(json['stars']?.toString() ?? '');
    final stars =
        RegExp(r'<icon[^>]*>star</icon>').allMatches(starsHtml).length;
    final hasHalf = starsHtml.contains('star-half-empty');

    // Collect info
    final bubble = json['collectBubble']?.toString() ?? '';
    String? collectUrl;
    String? collectLabel;
    if (bubble.isNotEmpty) {
      collectUrl =
          RegExp(r"data-href='([^']+)'").firstMatch(bubble)?.group(1);
      // Everything before the first <div is the quantity summary
      final labelRaw = bubble.split('<div').first;
      collectLabel =
          labelRaw.replaceAll(RegExp(r'<[^>]*>'), '').trim();
      if (collectLabel?.isEmpty ?? true) collectLabel = null;
    }

    return HqFacility(
      id:          json['id']?.toString() ?? '',
      name:        name,
      svgId:       json['svgId']?.toString() ?? '',
      stars:       stars,
      hasHalfStar: hasHalf,
      condition:   (json['condition'] as num?)?.toInt() ?? 0,
      collectUrl:  collectUrl,
      collectLabel: collectLabel,
    );
  }

  static String _htmlDecode(String s) => s
      .replaceAll('&lt;',   '<')
      .replaceAll('&gt;',   '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#039;', "'")
      .replaceAll('&amp;',  '&');
}

// ─── HqFacilityDetail ─────────────────────────────────────────────────────────

/// Detailed facility data loaded lazily from the facility endpoint.
///
/// Source: GET /index.php?action=fetch&d=facility&id={facilityId}
/// → response.vars
class HqFacilityDetail {
  final String id;             // facility type ID (matches HqFacility.id)
  final String name;
  final String info;           // short description
  final int    level;
  final int    condition;      // 0-100
  final String conditionClass; // 'green' | 'orange' | 'red'

  /// Cost string to upgrade, e.g. "5m".
  final String upgradeCostStr;
  /// Build time string, e.g. "4 Days 12 Hours".
  final String upgradeTimeStr;
  /// Cost string to repair (maintenance), e.g. "420k".
  final String repairCostStr;
  /// Facility instance ID used in the repair endpoint.
  final String fId;
  /// Facility type ID used in the upgrade endpoint.
  final String fType;
  /// Key notices extracted from vars.options, e.g. "Parts storage: 73/840".
  final List<String> notices;
  final bool      isUnderConstruction;
    /// Estimated completion time for the current upgrade (UTC).
  final DateTime? constructionEndTime;

  const HqFacilityDetail({
    required this.id,
    required this.name,
    required this.info,
    required this.level,
    required this.condition,
    required this.conditionClass,
    required this.upgradeCostStr,
    required this.upgradeTimeStr,
    required this.repairCostStr,
    required this.fId,
    required this.fType,
    required this.notices,
    required this.isUnderConstruction,
    this.constructionEndTime,
  });

  bool get canRepair  => !isUnderConstruction && condition < 100 && fId.isNotEmpty;
  bool get canUpgrade => !isUnderConstruction && fType.isNotEmpty;

  static HqFacilityDetail fromVars(
      String facilityId, Map<String, dynamic> vars) {
    final name = vars['name']?.toString() ?? '';
    final info = vars['info']?.toString() ?? '';
    final condition = (vars['condition'] as num?)?.toInt() ?? 0;
    final conditionClass =
        vars['conditionClass']?.toString() ?? 'green';

    // Level: "<span …>21</span>"
    final levelHtml = vars['level']?.toString() ?? '';
    final level =
        int.tryParse(RegExp(r'>(\d+)<').firstMatch(levelHtml)?.group(1) ?? '')
            ?? 0;

    // Upgrade cost: "<span …><img …/>5m</span>"
    final upgradeCostHtml = vars['upgradeCost']?.toString() ?? '';
    final upgradeCostStr = _stripHtml(upgradeCostHtml).trim();

    // Upgrade time + fType from upgradeBtn
    final upgradeHtml = vars['upgradeBtn']?.toString() ?? '';
    final upgradeTimeStr =
        RegExp(r'ios-time</icon>([^<]+)').firstMatch(upgradeHtml)?.group(1)?.trim()
            ?? '';
    final fType =
        RegExp(r'type=build&(?:amp;)?fType=(\d+)').firstMatch(upgradeHtml)?.group(1)
            ?? vars['type']?.toString() ?? '';

    // Repair cost + fId from repairBtn
    final repairHtml = vars['repairBtn']?.toString() ?? '';
    final repairCostStr =
        RegExp(r'icon-24[^>]*/>\s*([\d.,]+[km]?)', caseSensitive: false)
                .firstMatch(repairHtml)
                ?.group(1)
                ?.trim()
            ?? '';
    final fId =
        RegExp(r'hqRepair&(?:amp;)?fId=(\d+)').firstMatch(repairHtml)?.group(1)
            ?? '';

    // Key notices from options HTML
    final optionsHtml = vars['options']?.toString() ?? '';
    final notices = _parseNotices(optionsHtml);
    // Under-construction detection — vars.notice contains the warning string
final noticeHtml = vars['notice']?.toString() ?? '';
final isUnderConstruction =
    noticeHtml.toLowerCase().contains('under construction');

// End time — <span class="countdown" data-cdStyle="2">2026-05-31T20:41:14.000Z</span>
DateTime? constructionEndTime;
if (isUnderConstruction) {
  final footerHtml = vars['facilityFooter']?.toString() ?? '';
  final m = RegExp(r'data-cdStyle="2">([^<]+)<').firstMatch(footerHtml);
  if (m != null) constructionEndTime = DateTime.tryParse(m.group(1)!.trim());
}

    return HqFacilityDetail(
      id:             facilityId,
      name:           name,
      info:           info,
      level:          level,
      condition:      condition,
      conditionClass: conditionClass,
      upgradeCostStr: upgradeCostStr,
      upgradeTimeStr: upgradeTimeStr,
      repairCostStr:  repairCostStr,
      fId:            fId,
      fType:          fType,
      notices:        notices,
      isUnderConstruction: isUnderConstruction,
      constructionEndTime: constructionEndTime,
    );
  }

  /// Extracts notice texts from `class="notice …"` divs in the options HTML.
  ///
  /// Example input:
  ///   `<div class="notice">Parts storage: <span>73/840</span></div>`
  /// Returns: `["Parts storage: 73/840"]`
  static List<String> _parseNotices(String html) {
    final notices = <String>[];
    final re =
        RegExp(r'class="notice[^"]*"[^>]*>(.*?)</div>', dotAll: true);
    for (final m in re.allMatches(html)) {
      final text = _stripHtml(m.group(1)!).trim();
      if (text.isNotEmpty) notices.add(text);
    }
    return notices;
  }

  static String _stripHtml(String s) =>
      s.replaceAll(RegExp(r'<[^>]*>'), '');
}

// ─── HqData ───────────────────────────────────────────────────────────────────

/// All HQ facilities for one account.
class HqData {
  final List<HqFacility> facilities;

  const HqData({required this.facilities});

  bool get hasCollectables => facilities.any((f) => f.hasCollectable);
  int  get collectableCount => facilities.where((f) => f.hasCollectable).length;

  static HqData? parseFromFireUp(Map<String, dynamic> fireUpJson) {
    try {
      final preCache = fireUpJson['preCache'] as Map<String, dynamic>?;
      if (preCache == null) return null;

      final hq = preCache['p=headquarters'] as Map<String, dynamic>?;
      if (hq == null) return null;

      final vars = hq['vars'] as Map<String, dynamic>?;
      if (vars == null) return null;

      final jsonStr = vars['json']?.toString() ?? '';
      if (jsonStr.isEmpty) return null;

      final list = jsonDecode(jsonStr) as List<dynamic>;
      final facilities = list
          .map((e) => HqFacility.fromJson(e as Map<String, dynamic>))
          .where((f) => f.id.isNotEmpty)
          .toList();

      return HqData(facilities: facilities);
    } catch (e) {
      debugPrint('[HqData] parseFromFireUp error: $e');
      return null;
    }
  }
}
