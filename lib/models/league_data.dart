import 'package:flutter/foundation.dart';

// ─── LeagueRules ─────────────────────────────────────────────────────────────

class LeagueRules {
  final int    cars;
  final String racePct;     // e.g. "50%"
  final String speedMult;  // e.g. "1.5x"
  final bool   fuelEnabled;
  final bool   tyreRuleEnabled;
  final bool   safetyCarEnabled;

  const LeagueRules({
    required this.cars,
    required this.racePct,
    required this.speedMult,
    required this.fuelEnabled,
    required this.tyreRuleEnabled,
    required this.safetyCarEnabled,
  });

  factory LeagueRules.fromHtml(String html) {
    final cars = int.tryParse(
            RegExp(r'igp-car</icon>\s*(\d+)').firstMatch(html)?.group(1) ?? '')
        ?? 1;
    final racePct  = RegExp(r'chronometer</icon>\s*(\d+%)').firstMatch(html)?.group(1) ?? '';
    final speedMult = RegExp(r'md-speedometer</icon>\s*([\d.]+x)').firstMatch(html)?.group(1) ?? '';
    return LeagueRules(
      cars:              cars,
      racePct:           racePct,
      speedMult:         speedMult,
      fuelEnabled:       _isIconEnabled(html, 'igp-fuel'),
      tyreRuleEnabled:   _isIconEnabled(html, 'igp-tyre'),
      safetyCarEnabled:  _isIconEnabled(html, 'md-stopwatch'),
    );
  }

  /// Returns true when the span immediately before [iconName] carries
  /// class="green" rather than class="grey".
  static bool _isIconEnabled(String html, String iconName) {
    final idx = html.indexOf(iconName);
    if (idx < 0) return false;
    final ctx       = html.substring(idx > 300 ? idx - 300 : 0, idx);
    final lastGreen = ctx.lastIndexOf('"green"');
    final lastGrey  = ctx.lastIndexOf('"grey"');
    if (lastGreen < 0 && lastGrey < 0) return false;
    return lastGreen > lastGrey;
  }
}

// ─── LeagueScheduleEntry ──────────────────────────────────────────────────────

class LeagueScheduleEntry {
  final String  flagCode;
  final String  raceName;
  final int     laps;
  /// "Finished" for past races; "02 Jun, 09:00" for upcoming ones.
  final String  statusText;
  /// Non-null only when the race has finished and results are available.
  final String? resultId;
  /// True for the row highlighted with class="myTeam" (the next / current race).
  final bool    isCurrentRace;

  const LeagueScheduleEntry({
    required this.flagCode,
    required this.raceName,
    required this.laps,
    required this.statusText,
    this.resultId,
    this.isCurrentRace = false,
  });

  bool get isFinished => resultId != null;
}

// ─── LeagueData ───────────────────────────────────────────────────────────────

class LeagueData {
  final String                    leagueId;
  final String                    name;
  final String                    description;
  final LeagueRules               rules;
  final int?                      rank;
  final List<LeagueScheduleEntry> schedule;

  const LeagueData({
    required this.leagueId,
    required this.name,
    required this.description,
    required this.rules,
    this.rank,
    required this.schedule,
  });

  static LeagueData? fromVars(Map<String, dynamic> vars) {
    try {
      return LeagueData(
        leagueId:    vars['leagueId']?.toString() ?? '',
        name:        vars['name']?.toString() ?? '',
        description: vars['leagueDescriptionContent']?.toString() ?? '',
        rules:       LeagueRules.fromHtml(vars['rules']?.toString() ?? ''),
        rank:        _parseRank(vars['leagueRankBadge']?.toString() ?? ''),
        schedule:    _parseSchedule(vars['condensedSchedule']?.toString() ?? ''),
      );
    } catch (e) {
      debugPrint('[LeagueData] fromVars error: $e');
      return null;
    }
  }

  /// Extracts the numeric rank from the leagueRankBadge HTML.
  ///
  /// <span class="font-heading">5249</span>
  static int? _parseRank(String html) {
    final m = RegExp(r'font-heading">(\d+)<').firstMatch(html);
    return int.tryParse(m?.group(1) ?? '');
  }

  /// Parses the condensed schedule HTML into a list of schedule entries.
  ///
  /// Extracts <tbody> rows from the race schedule table.
  static List<LeagueScheduleEntry> _parseSchedule(String html) {
    final entries = <LeagueScheduleEntry>[];

    final tbodyM =
        RegExp(r'<tbody>(.*?)</tbody>', dotAll: true).firstMatch(html);
    if (tbodyM == null) return entries;

    for (final trM in RegExp(r'<tr([^>]*)>(.*?)</tr>', dotAll: true)
        .allMatches(tbodyM.group(1)!)) {
      final trAttrs = trM.group(1) ?? '';
      final trBody  = trM.group(2) ?? '';

      final tds = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true)
          .allMatches(trBody)
          .toList();
      if (tds.length < 3) continue;

      final td0 = tds[0].group(1) ?? '';
      final td1 = tds[1].group(1) ?? '';
      final td2 = tds[2].group(1) ?? '';

      entries.add(LeagueScheduleEntry(
        statusText:    td0.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
        resultId:      RegExp(r'd=result&(?:amp;)?id=(\d+)').firstMatch(td0)?.group(1),
        flagCode:      RegExp(r'flag f-([a-z]+)').firstMatch(td1)?.group(1) ?? '',
        raceName:      td1.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
        laps:          int.tryParse(td2.replaceAll(RegExp(r'<[^>]*>'), '').trim()) ?? 0,
        isCurrentRace: trAttrs.contains('myTeam'),
      ));
    }
    return entries;
  }
}

// ─── RaceResultRow ────────────────────────────────────────────────────────────

/// One row in a practice, qualifying, or race result table.
class RaceResultRow {
  final int     pos;
  final String  driverId;
  final String  driverName;
  final String  flagCode;
  final String  teamName;
  /// Team colour from border-right-color on the position cell.
  final String  teamColor;
  final bool    isMyTeam;

  // ── Practice / Qualifying ──────────────────────────────
  final String  time;   // lap time (P/Q) or finish time / gap (R)
  final String  gap;
  final String  tyre;   // "SS", "M", "H", etc.

  // ── Race only ──────────────────────────────────────────
  final String  bestLap;
  final String  topSpeed;
  final int     pits;
  final String  points;   // "25" or "-"
  /// ID for the future lap-by-lap detail endpoint.
  final String? detailId;

  const RaceResultRow({
    required this.pos,
    required this.driverId,
    required this.driverName,
    required this.flagCode,
    required this.teamName,
    required this.teamColor,
    required this.isMyTeam,
    this.time      = '',
    this.gap       = '',
    this.tyre      = '',
    this.bestLap   = '',
    this.topSpeed  = '',
    this.pits      = 0,
    this.points    = '',
    this.detailId,
  });
}

// ─── RaceResultData ───────────────────────────────────────────────────────────

class RaceResultData {
  final String              raceName;
  final String              flagCode;
  final List<RaceResultRow> practice;
  final List<RaceResultRow> qualifying;
  final List<RaceResultRow> race;
  final String?             postedDate;

  const RaceResultData({
    required this.raceName,
    required this.flagCode,
    required this.practice,
    required this.qualifying,
    required this.race,
    this.postedDate,
  });

  static RaceResultData? fromVars(Map<String, dynamic> vars) {
    try {
      final raceNameHtml = vars['raceName']?.toString() ?? '';
      final postedMatch  = RegExp(r'Results posted ([^<]+)<')
          .firstMatch(vars['rNotice']?.toString() ?? '');

      return RaceResultData(
        flagCode:   RegExp(r'flag f-([a-z]+)').firstMatch(raceNameHtml)?.group(1) ?? '',
        raceName:   raceNameHtml.replaceAll(RegExp(r'<[^>]*>'), '').trim(),
        practice:   _parsePQRows(vars['pResult']?.toString() ?? ''),
        qualifying: _parsePQRows(vars['qResult']?.toString() ?? ''),
        race:       _parseRaceRows(vars['rResult']?.toString() ?? ''),
        postedDate: postedMatch?.group(1)?.trim(),
      );
    } catch (e) {
      debugPrint('[RaceResultData] fromVars error: $e');
      return null;
    }
  }

  // ── Practice / Qualifying row parser ────────────────────────────────────

  /// Each row: pos | driver | time | gap | tyre
  static List<RaceResultRow> _parsePQRows(String html) {
    final rows = <RaceResultRow>[];
    for (final trM
        in RegExp(r'<tr([^>]*)>(.*?)</tr>', dotAll: true).allMatches(html)) {
      final trAttrs = trM.group(1) ?? '';
      final trBody  = trM.group(2) ?? '';
      final tds = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true)
          .allMatches(trBody)
          .toList();
      if (tds.length < 5) continue;

      final cell0 = tds[0].group(1) ?? '';
      final cell1 = tds[1].group(1) ?? '';

      rows.add(RaceResultRow(
        pos:        int.tryParse(cell0.replaceAll(RegExp(r'<[^>]*>'), '').trim()) ?? 0,
        teamColor:  RegExp(r'border-right-color:\s*(#[a-fA-F0-9]+)')
            .firstMatch(trM.group(0) ?? '')?.group(1) ?? '#888888',
        driverId:   RegExp(r'd=driver&(?:amp;)?id=(\d+)').firstMatch(cell1)?.group(1) ?? '',
        flagCode:   RegExp(r'flag f-([a-z]+)').firstMatch(cell1)?.group(1) ?? '',
        driverName: _extractDriverName(cell1),
        teamName:   RegExp(r'class="teamName">([^<]+)').firstMatch(cell1)?.group(1)?.trim() ?? '',
        isMyTeam:   trAttrs.contains('myTeam'),
        time:       tds[2].group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '',
        gap:        tds[3].group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '',
        tyre:       tds[4].group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '',
      ));
    }
    return rows;
  }

  // ── Race row parser ──────────────────────────────────────────────────────

  /// Each row: pos | driver | finish | best_lap | top_speed | pits | points
  static List<RaceResultRow> _parseRaceRows(String html) {
    final rows = <RaceResultRow>[];
    for (final trM
        in RegExp(r'<tr([^>]*)>(.*?)</tr>', dotAll: true).allMatches(html)) {
      final trAttrs = trM.group(1) ?? '';
      final trBody  = trM.group(2) ?? '';
      final tds = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true)
          .allMatches(trBody)
          .toList();
      if (tds.length < 7) continue;

      final cell0 = tds[0].group(1) ?? '';
      final cell1 = tds[1].group(1) ?? '';
      final cell2 = tds[2].group(1) ?? '';

      // Finish time lives inside a <span> in the third cell
      final finishTime = RegExp(r'<span[^>]*>([^<]+)</span>')
              .firstMatch(cell2)?.group(1)?.trim()
          ?? cell2.replaceAll(RegExp(r'<[^>]*>'), '').trim();

      rows.add(RaceResultRow(
        pos:       int.tryParse(cell0.replaceAll(RegExp(r'<[^>]*>'), '').trim()) ?? 0,
        teamColor: RegExp(r'border-right-color:\s*(#[a-fA-F0-9]+)')
            .firstMatch(trM.group(0) ?? '')?.group(1) ?? '#888888',
        driverId:  RegExp(r'd=driver&(?:amp;)?id=(\d+)').firstMatch(cell1)?.group(1) ?? '',
        flagCode:  RegExp(r'flag f-([a-z]+)').firstMatch(cell1)?.group(1) ?? '',
        driverName: _extractDriverName(cell1),
        teamName:  RegExp(r'class="teamName">([^<]+)').firstMatch(cell1)?.group(1)?.trim() ?? '',
        isMyTeam:  trAttrs.contains('myTeam'),
        time:      finishTime,
        detailId:  RegExp(r'd=resultDetail&(?:amp;)?id=(\d+)').firstMatch(cell2)?.group(1),
        bestLap:   tds[3].group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '',
        topSpeed:  tds[4].group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '',
        pits:      int.tryParse(tds[5].group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '') ?? 0,
        points:    tds[6].group(1)?.replaceAll(RegExp(r'<[^>]*>'), '').trim() ?? '',
      ));
    }
    return rows;
  }

  // ── Shared helpers ───────────────────────────────────────────────────────

  /// Extracts the driver surname from the driver cell HTML.
  ///
  /// Expected layout:
  ///   <a …></a><img class="flag f-gb …" /> O Wright<br /><span…>Team</span>
  static String _extractDriverName(String cell) {
    final m = RegExp(r'class="flag[^"]*"[^>]*/>\s*([^<\n]+?)\s*<br')
        .firstMatch(cell);
    return m?.group(1)?.trim() ?? '';
  }
}
