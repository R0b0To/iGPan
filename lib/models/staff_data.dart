import 'package:flutter/foundation.dart';

// ─── StaffMember ─────────────────────────────────────────────────────────────

/// One staff member or reserve staff member parsed from fireUp p=staff vars.
///
/// Main staff (CD / TD / Doctor) come from vars.designInfo, vars.engineerInfo,
/// and vars.trainInfo respectively.
///
/// Reserve staff come from rows in vars.reserveStaff.
class StaffMember {
  /// Server numeric ID used in contract/fetch endpoints.
  final String id;

  final String firstName;
  final String lastName;

  /// Portrait image URL (empty for reserve staff).
  final String imageUrl;

  /// Short role code: 'CD', 'TD', 'DOC', 'DR' (reserve driver), etc.
  final String roleCode;

  /// Localised role label extracted from the HTML (e.g. 'Chief Designer').
  final String roleLabel;

  /// Full-star count from the ratingStar block (half-stars counted separately).
  final int stars;

  /// True when the ratingStar block contains at least one star-half-empty icon.
  final bool hasHalfStar;

  /// Salary string exactly as shown in the UI, e.g. "726k" or "1m".
  final String salary;

  /// Races remaining on the current contract (0 = unknown/not parsed).
  final int contractRaces;

  /// True when this member lives in the reserve pool rather than the main slot.
  final bool isReserve;

  const StaffMember({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.imageUrl,
    required this.roleCode,
    required this.roleLabel,
    required this.stars,
    required this.hasHalfStar,
    required this.salary,
    required this.contractRaces,
    required this.isReserve,
  });

  String get fullName  => '$firstName $lastName'.trim();

  /// Short display name used in compact rows: "M. Alaga" or "G Orlando".
  String get shortName {
    if (firstName.length <= 2) return fullName; // already abbreviated
    return '${firstName[0]}. $lastName';
  }

  /// Contract colour tier for visual warnings.
  bool get isExpiringSoon  => contractRaces > 0 && contractRaces <= 3;
  bool get isExpiring      => contractRaces > 3 && contractRaces <= 10;
  bool get isContractSafe  => contractRaces > 10;
}

// ─── StaffData ────────────────────────────────────────────────────────────────

/// All staff for one account, parsed from fireUp preCache → p=staff → vars.
class StaffData {
  final StaffMember? chiefDesigner;
  final StaffMember? technicalDirector;
  final StaffMember? doctor;
  final List<StaffMember> reserveStaff;

  const StaffData({
    this.chiefDesigner,
    this.technicalDirector,
    this.doctor,
    this.reserveStaff = const [],
  });

  /// All main-slot staff (CD + TD + Doctor).
  List<StaffMember> get mainStaff => [
        if (chiefDesigner != null) chiefDesigner!,
        if (technicalDirector != null) technicalDirector!,
        if (doctor != null) doctor!,
      ];

  /// All staff including reserve.
  List<StaffMember> get all => [...mainStaff, ...reserveStaff];

  bool get hasExpiringContracts => all.any((s) => s.isExpiringSoon);
  int  get expiringCount        => all.where((s) => s.isExpiringSoon).length;

  // ─── Entry point ──────────────────────────────────────────────────────

  static StaffData? parseFromFireUp(Map<String, dynamic> fireUpJson) {
    try {
      final preCache = fireUpJson['preCache'] as Map<String, dynamic>?;
      if (preCache == null) return null;

      final staff = preCache['p=staff'] as Map<String, dynamic>?;
      if (staff == null) return null;

      final vars = staff['vars'] as Map<String, dynamic>?;
      if (vars == null) return null;

      final designHtml  = vars['designInfo']?.toString()   ?? '';
      final engineHtml  = vars['engineerInfo']?.toString() ?? '';
      final trainHtml   = vars['trainInfo']?.toString()    ?? '';
      final reserveHtml = vars['reserveStaff']?.toString() ?? '';

      return StaffData(
        chiefDesigner:    designHtml.isNotEmpty
            ? _parseMainStaff(designHtml,  'CD',  'Chief Designer')    : null,
        technicalDirector: engineHtml.isNotEmpty
            ? _parseMainStaff(engineHtml,  'TD',  'Technical Director') : null,
        doctor:           trainHtml.isNotEmpty
            ? _parseMainStaff(trainHtml,   'DOC', 'Doctor')            : null,
        reserveStaff:     reserveHtml.isNotEmpty
            ? _parseReserveStaff(reserveHtml) : const [],
      );
    } catch (e) {
      debugPrint('[StaffData] parseFromFireUp error: $e');
      return null;
    }
  }

  // ─── Main staff parser ─────────────────────────────────────────────────

  /// Parses a single main-slot staff member from the HTML blob in
  /// vars.designInfo / vars.engineerInfo / vars.trainInfo.
  ///
  /// Expected shape (simplified):
  ///   <a href="d=staff&id=11635919" …></a>
  ///   <div class="c-head …">Chief Designer</div>
  ///   <div class="staffImage …"><img src="…" /><div class="driverName …">
  ///     Mete<br><span …>Alaga</span></div></div>
  ///   <div …><span class="ratingStar in">…</span><br>
  ///     <img class="icon-24 …"/>726k<br>
  ///     <span id="nStaffC11635919" …>48 race(s)</span></div>
  static StaffMember? _parseMainStaff(
    String html, String fallbackCode, String fallbackLabel) {
    // ID
    final idMatch = RegExp(r'd=staff&(?:amp;)?id=(\d+)').firstMatch(html);
    final id = idMatch?.group(1) ?? '';
    if (id.isEmpty) return null;

    // Localised role label
    final labelMatch =
        RegExp(r'class="c-head[^"]*"[^>]*>([^<]+)<').firstMatch(html);
    final roleLabel = labelMatch?.group(1)?.trim() ?? fallbackLabel;

    // Name from driverName div: "Mete<br>…<span>Alaga</span>"
    final nameMatch = RegExp(
      r'class="driverName[^"]*"[^>]*>(.*?)<br[^>]*>.*?<span[^>]*>(.*?)</span>',
      dotAll: true,
    ).firstMatch(html);
    final firstName =
        (nameMatch?.group(1) ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();
    final lastName =
        (nameMatch?.group(2) ?? '').replaceAll(RegExp(r'<[^>]*>'), '').trim();

    // Portrait image — first <img> inside staffImage wrapper
    final imgMatch = RegExp(
      r'class="staffImage[^"]*"[^>]*>.*?<img\s+src="([^"]*)"',
      dotAll: true,
    ).firstMatch(html);
    final imageUrl = imgMatch?.group(1) ?? '';

    // Stars
    final starsBlockMatch =
        RegExp(r'class="ratingStar in">(.*?)</span>', dotAll: true)
            .firstMatch(html);
    final starsHtml = starsBlockMatch?.group(1) ?? '';
    final stars =
        RegExp(r'<icon[^>]*>star</icon>').allMatches(starsHtml).length;
    final hasHalf =
        starsHtml.contains('star-half-empty');

    // Salary — text immediately after the cash icon img
    final salaryMatch =
        RegExp(r'class="icon-24[^"]*"[^>]*/>\s*([\d.,]+[km]?)',
                caseSensitive: false)
            .firstMatch(html);
    final salary = salaryMatch?.group(1)?.trim() ?? '';

    // Contract races — from nStaffC{id} span
    final contractMatch =
        RegExp('id="nStaffC$id"[^>]*>([^<]+)<').firstMatch(html);
    final contractStr = contractMatch?.group(1)?.trim() ?? '';
    final contractNum =
        int.tryParse(RegExp(r'(\d+)').firstMatch(contractStr)?.group(1) ?? '')
            ?? 0;

    return StaffMember(
      id:           id,
      firstName:    firstName,
      lastName:     lastName,
      imageUrl:     imageUrl,
      roleCode:     fallbackCode,
      roleLabel:    roleLabel,
      stars:        stars,
      hasHalfStar:  hasHalf,
      salary:       salary,
      contractRaces: contractNum,
      isReserve:    false,
    );
  }

  // ─── Reserve staff parser ──────────────────────────────────────────────

  /// Parses every <tr> in vars.reserveStaff.
  ///
  /// Row shape:
  ///   <td>CD</td>
  ///   <th><a href="d=staff&id=15073447" …></a><img class="flag f-it …"/> G Orlando</th>
  ///   <td class="hoverData" data-staff="12,11,11,14,33" …>
  ///     <span class="ratingStar in">…</span></td>
  ///   <td id="nStaffC15073447" …><img …/>50k, 29 gara/e</td>
  static List<StaffMember> _parseReserveStaff(String html) {
    final members = <StaffMember>[];
    int idx = 0;

    for (final rowMatch
        in RegExp(r'<tr>(.*?)</tr>', dotAll: true).allMatches(html)) {
      final row = rowMatch.group(1) ?? '';
      if (row.trim().isEmpty) continue;

      // Role code from first <td>
      final roleMatch = RegExp(r'<td>([A-Z]+)</td>').firstMatch(row);
      final roleCode = roleMatch?.group(1)?.trim() ?? '';
      if (roleCode.isEmpty) continue;

      // ID
      final idMatch =
          RegExp(r'd=staff&(?:amp;)?id=(\d+)').firstMatch(row);
      final id = idMatch?.group(1) ?? '${roleCode}_$idx';
      idx++;

      // Short name — text node after flag img inside <th>
      final nameMatch =
          RegExp(r'class="flag[^"]*"[^>]*/?>([^<]+)').firstMatch(row);
      final shortName = nameMatch?.group(1)?.trim() ?? '';

      // Stars
      final starsHtml =
          RegExp(r'class="ratingStar in">(.*?)</span>', dotAll: true)
                  .firstMatch(row)
                  ?.group(1) ??
              '';
      final stars =
          RegExp(r'<icon[^>]*>star</icon>').allMatches(starsHtml).length;
      final hasHalf = starsHtml.contains('star-half-empty');

      // Salary + contract from nStaffC{id} td
      String salary = '';
      int contractNum = 0;
      final tdMatch =
          RegExp('id="nStaffC$id"[^>]*>(.*?)</td>', dotAll: true)
              .firstMatch(row);
      if (tdMatch != null) {
        final raw =
            tdMatch.group(1)!.replaceAll(RegExp(r'<[^>]*>'), '').trim();
        // Format: "50k, 29 gara/e"  or  "50k, 29 race(s)"
        final comma = raw.indexOf(',');
        if (comma > 0) {
          salary = raw.substring(0, comma).trim();
          contractNum = int.tryParse(
                  RegExp(r'(\d+)').firstMatch(raw.substring(comma))?.group(1) ?? '')
              ?? 0;
        } else {
          contractNum =
              int.tryParse(RegExp(r'(\d+)').firstMatch(raw)?.group(1) ?? '')
                  ?? 0;
        }
      }

      // Split short name into firstName/lastName
      final parts = shortName.split(' ');
      final firstName = parts.isNotEmpty ? parts[0] : '';
      final lastName =
          parts.length > 1 ? parts.sublist(1).join(' ') : shortName;

      members.add(StaffMember(
        id:            id,
        firstName:     firstName,
        lastName:      lastName,
        imageUrl:      '',
        roleCode:      roleCode,
        roleLabel:     _labelFromCode(roleCode),
        stars:         stars,
        hasHalfStar:   hasHalf,
        salary:        salary,
        contractRaces: contractNum,
        isReserve:     true,
      ));
    }
    return members;
  }

  static String _labelFromCode(String code) => switch (code.toUpperCase()) {
        'CD'             => 'Chief Designer',
        'TD'             => 'Technical Director',
        'DR' || 'DT'     => 'Driver',
        'DOC' || 'TR'    => 'Doctor',
        _                => code,
      };
}
