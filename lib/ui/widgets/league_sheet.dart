import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/league_data.dart';
import '../../providers/game_provider.dart';
import '../../ui/theme/app_theme.dart';

// ─── League sheet ─────────────────────────────────────────────────────────────

/// Bottom sheet showing league name, rules, and full season schedule.
/// Tapping a finished race opens [RaceResultSheet].
class LeagueSheet extends ConsumerStatefulWidget {
  final String accountEmail;
  final String leagueId;

  const LeagueSheet({
    super.key,
    required this.accountEmail,
    required this.leagueId,
  });

  @override
  ConsumerState<LeagueSheet> createState() => _LeagueSheetState();
}

class _LeagueSheetState extends ConsumerState<LeagueSheet> {
  LeagueData? _data;
  bool        _loading = true;
  String?     _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final vars = await ref
          .read(gameServiceProvider)
          .fetchLeagueInfo(widget.accountEmail, leagueId: widget.leagueId);
      if (mounted) {
        setState(() {
          _data    = LeagueData.fromVars(vars);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _openResult(BuildContext context, String raceId) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => RaceResultSheet(
        accountEmail: widget.accountEmail,
        raceId:       raceId,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final schedule = _data?.schedule ?? [];
    final finished = schedule.where((e) => e.isFinished).length;
    final total    = schedule.length;

    return DraggableScrollableSheet(
      initialChildSize: 0.78,
      minChildSize:     0.45,
      maxChildSize:     0.95,
      expand:           false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // ── Handle ────────────────────────────────────────────
          const SizedBox(height: 12),
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2)),
          )),

          // ── Header ────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Row(children: [
              const Icon(Icons.emoji_events_outlined,
                  size: 17, color: AppTheme.onSurface),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _loading ? 'League' : (_data?.name ?? 'League'),
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface),
                ),
              ),
              if (_data?.rank != null) _RankBadge(rank: _data!.rank!),
            ]),
          ),

          // ── Rules bar ─────────────────────────────────────────
          if (_data != null) ...[
            const SizedBox(height: 8),
            _RulesBar(rules: _data!.rules),
          ],

          // ── Description ───────────────────────────────────────
          if (_data != null && _data!.description.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 5, 16, 0),
              child: Text(
                _data!.description,
                style: const TextStyle(
                    fontSize: 11, color: AppTheme.onSurfaceDim),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],

          const SizedBox(height: 10),
          const Divider(color: AppTheme.border, thickness: 0.5, height: 0),

          // ── Schedule list ──────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppTheme.error, fontSize: 12)),
                        ))
                    : ListView(
                        controller: scrollCtrl,
                        padding:
                            const EdgeInsets.fromLTRB(12, 10, 12, 32),
                        children: [
                          // Section header
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: Row(children: [
                              const Icon(Icons.calendar_month_outlined,
                                  size: 12, color: AppTheme.onSurfaceDim),
                              const SizedBox(width: 5),
                              Text(
                                'SCHEDULE  ·  $finished / $total',
                                style: const TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.onSurfaceDim,
                                    letterSpacing: 0.4),
                              ),
                            ]),
                          ),

                          ...schedule.map((e) => _ScheduleRow(
                                entry: e,
                                onTap: e.resultId != null
                                    ? () => _openResult(context, e.resultId!)
                                    : null,
                              )),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Rules bar ────────────────────────────────────────────────────────────────

class _RulesBar extends StatelessWidget {
  final LeagueRules rules;
  const _RulesBar({required this.rules});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Wrap(
        spacing: 6,
        runSpacing: 4,
        children: [
          _RuleChip(
              label: '${rules.cars} car${rules.cars == 1 ? '' : 's'}',
              active: true),
          if (rules.racePct.isNotEmpty)
            _RuleChip(label: rules.racePct, active: true),
          if (rules.speedMult.isNotEmpty)
            _RuleChip(label: rules.speedMult, active: true),
          _RuleChip(label: 'Fuel',    active: rules.fuelEnabled),
          _RuleChip(label: '2-Tyre',  active: rules.tyreRuleEnabled),
          _RuleChip(label: 'SC',      active: rules.safetyCarEnabled),
        ],
      ),
    );
  }
}

class _RuleChip extends StatelessWidget {
  final String label;
  final bool   active;
  const _RuleChip({required this.label, required this.active});

  @override
  Widget build(BuildContext context) {
    final color = active ? AppTheme.primary : AppTheme.onSurfaceFaint;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color:        color.withOpacity(active ? 0.12 : 0.06),
        borderRadius: BorderRadius.circular(5),
        border:       Border.all(
            color: color.withOpacity(active ? 0.55 : 0.2), width: 0.6),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: color)),
    );
  }
}

// ─── Rank badge ───────────────────────────────────────────────────────────────

class _RankBadge extends StatelessWidget {
  final int rank;
  const _RankBadge({required this.rank});

  @override
  Widget build(BuildContext context) => Container(
        padding:
            const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:        AppTheme.accent.withOpacity(0.13),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: AppTheme.accent, width: 0.8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.military_tech_outlined,
              size: 12, color: AppTheme.accent),
          const SizedBox(width: 4),
          Text('#$rank',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.accent)),
        ]),
      );
}

// ─── Schedule row ─────────────────────────────────────────────────────────────

class _ScheduleRow extends StatelessWidget {
  final LeagueScheduleEntry entry;
  final VoidCallback?       onTap;
  const _ScheduleRow({required this.entry, this.onTap});

  @override
  Widget build(BuildContext context) {
    final isCurrent  = entry.isCurrentRace;
    final isFinished = entry.isFinished;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding:
            const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: BoxDecoration(
          color: isCurrent
              ? AppTheme.primary.withOpacity(0.08)
              : AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isCurrent
                ? AppTheme.primary.withOpacity(0.45)
                : AppTheme.border,
            width: isCurrent ? 1.0 : 0.5,
          ),
        ),
        child: Row(children: [
          // Status icon
          SizedBox(
            width: 18,
            child: isFinished
                ? const Icon(Icons.check_circle_outline,
                    size: 13, color: AppTheme.success)
                : isCurrent
                    ? const Icon(Icons.play_circle_outline,
                        size: 13, color: AppTheme.primary)
                    : const Icon(Icons.radio_button_unchecked,
                        size: 13, color: AppTheme.onSurfaceFaint),
          ),
          const SizedBox(width: 7),

          // Flag emoji
          Text(_flagEmoji(entry.flagCode),
              style: const TextStyle(fontSize: 15)),
          const SizedBox(width: 8),

          // Race name
          Expanded(
            child: Text(
              entry.raceName,
              style: TextStyle(
                fontSize: 13,
                fontWeight:
                    isCurrent ? FontWeight.w600 : FontWeight.w400,
                color:
                    isCurrent ? AppTheme.primary : AppTheme.onSurface,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),

          // Laps
          Text('${entry.laps}L',
              style: const TextStyle(
                  fontSize: 10, color: AppTheme.onSurfaceDim)),
          const SizedBox(width: 8),

          // Status label
          Text(
            isCurrent
                ? 'Next'
                : (isFinished ? '' : entry.statusText),
            style: TextStyle(
                fontSize: 10,
                fontWeight:
                    isCurrent ? FontWeight.w600 : FontWeight.w400,
                color: isCurrent
                    ? AppTheme.primary
                    : AppTheme.onSurfaceDim),
          ),

          // Chevron for tappable rows
          if (onTap != null) ...[
            const SizedBox(width: 4),
            const Icon(Icons.chevron_right,
                size: 14, color: AppTheme.onSurfaceDim),
          ],
        ]),
      ),
    );
  }
}

// ─── Flag emoji helper ────────────────────────────────────────────────────────

String _flagEmoji(String code) {
  if (code.length != 2) return '🏁';
  try {
    final a = code.codeUnitAt(0);
    final b = code.codeUnitAt(1);
    if (a < 97 || a > 122 || b < 97 || b > 122) return '🏁';
    return String.fromCharCode(0x1F1E6 + a - 97) +
        String.fromCharCode(0x1F1E6 + b - 97);
  } catch (_) {
    return '🏁';
  }
}

// ─── Race result sheet ────────────────────────────────────────────────────────

/// Nested sheet showing Practice / Qualifying / Race result tabs for one race.
class RaceResultSheet extends ConsumerStatefulWidget {
  final String accountEmail;
  final String raceId;

  const RaceResultSheet({
    super.key,
    required this.accountEmail,
    required this.raceId,
  });

  @override
  ConsumerState<RaceResultSheet> createState() => _RaceResultSheetState();
}

class _RaceResultSheetState extends ConsumerState<RaceResultSheet>
    with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  RaceResultData? _data;
  bool    _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    // Default to Race tab (index 2) since that is usually the most relevant
    _tabs = TabController(length: 3, vsync: this, initialIndex: 2);
    _fetch();
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  Future<void> _fetch() async {
    try {
      final vars = await ref
          .read(gameServiceProvider)
          .fetchRaceReport(widget.accountEmail, raceId: widget.raceId);
      if (mounted) {
        setState(() {
          _data    = RaceResultData.fromVars(vars);
          _loading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.93,
      minChildSize:     0.5,
      maxChildSize:     0.97,
      expand:           false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(child: Container(
            width: 36, height: 4,
            decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2)),
          )),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Row(children: [
              if (_data != null) ...[
                Text(_flagEmoji(_data!.flagCode),
                    style: const TextStyle(fontSize: 16)),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  _data?.raceName ?? 'Race Results',
                  style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface),
                ),
              ),
              if (_data?.postedDate != null)
                Text(_data!.postedDate!,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.onSurfaceDim)),
            ]),
          ),

          // Tab bar
          Container(
            color: AppTheme.surfaceCard,
            child: TabBar(
              controller:            _tabs,
              tabs: const [
                Tab(text: 'Practice'),
                Tab(text: 'Qualifying'),
                Tab(text: 'Race'),
              ],
              labelColor:            AppTheme.primary,
              unselectedLabelColor:  AppTheme.onSurfaceDim,
              indicatorColor:        AppTheme.primary,
              indicatorSize:         TabBarIndicatorSize.tab,
              dividerColor:          AppTheme.border,
              labelStyle: const TextStyle(
                  fontSize: 12, fontWeight: FontWeight.w600),
              unselectedLabelStyle:
                  const TextStyle(fontSize: 12),
            ),
          ),
          const Divider(
              color: AppTheme.border, thickness: 0.5, height: 0),

          // Content
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(strokeWidth: 2))
                : _error != null
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(_error!,
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: AppTheme.error, fontSize: 12)),
                        ))
                    : TabBarView(
                        controller: _tabs,
                        children: [
                          _ResultList(
                              rows:       _data?.practice ?? [],
                              isRace:     false,
                              scrollCtrl: scrollCtrl),
                          _ResultList(
                              rows:       _data?.qualifying ?? [],
                              isRace:     false,
                              scrollCtrl: scrollCtrl),
                          _ResultList(
                              rows:       _data?.race ?? [],
                              isRace:     true,
                              scrollCtrl: scrollCtrl),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}

// ─── Result list ─────────────────────────────────────────────────────────────

class _ResultList extends StatelessWidget {
  final List<RaceResultRow> rows;
  final bool                isRace;
  final ScrollController    scrollCtrl;

  const _ResultList({
    required this.rows,
    required this.isRace,
    required this.scrollCtrl,
  });

  @override
  Widget build(BuildContext context) {
    if (rows.isEmpty) {
      return const Center(
        child: Text('No data',
            style: TextStyle(
                color: AppTheme.onSurfaceDim, fontSize: 13)));
    }
    return ListView.separated(
      controller:  scrollCtrl,
      padding:     const EdgeInsets.fromLTRB(12, 8, 12, 32),
      itemCount:   rows.length,
      separatorBuilder: (_, __) => const SizedBox(height: 4),
      itemBuilder: (_, i) =>
          _ResultRow(row: rows[i], isRace: isRace),
    );
  }
}

// ─── Result row ───────────────────────────────────────────────────────────────

class _ResultRow extends StatelessWidget {
  final RaceResultRow row;
  final bool          isRace;
  const _ResultRow({required this.row, required this.isRace});

  @override
  Widget build(BuildContext context) {
    final teamColor = _hexColor(row.teamColor);

    return Container(
      decoration: BoxDecoration(
        color: row.isMyTeam
            ? AppTheme.primary.withOpacity(0.08)
            : AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: row.isMyTeam
              ? AppTheme.primary.withOpacity(0.3)
              : AppTheme.border,
          width: 0.5,
        ),
      ),
      child: IntrinsicHeight(
        child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          // Team colour bar
          Container(
            width: 3,
            decoration: BoxDecoration(
              color: teamColor,
              borderRadius: const BorderRadius.only(
                topLeft:     Radius.circular(8),
                bottomLeft:  Radius.circular(8),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Position
          SizedBox(
            width: 22,
            child: Center(
              child: Text('${row.pos}',
                  style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: _posColor(row.pos))),
            ),
          ),
          const SizedBox(width: 6),

          // Flag + driver info
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(children: [
                    Text(_flagEmoji(row.flagCode),
                        style: const TextStyle(fontSize: 12)),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(row.driverName,
                          style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: AppTheme.onSurface),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                    ),
                  ]),
                  Text(row.teamName,
                      style: const TextStyle(
                          fontSize: 10, color: AppTheme.onSurfaceDim),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
          ),

          // Right section: result data
          Padding(
            padding:
                const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: isRace
                ? _RaceStats(row: row)
                : _PqStats(row: row),
          ),
        ]),
      ),
    );
  }

  Color _posColor(int pos) {
    if (pos == 1) return const Color(0xFFFFD700);
    if (pos == 2) return const Color(0xFFC0C0C0);
    if (pos == 3) return const Color(0xFFCD7F32);
    return AppTheme.onSurfaceDim;
  }

  Color _hexColor(String hex) {
    try {
      return Color(int.parse(hex.replaceFirst('#', '0xFF')));
    } catch (_) {
      return AppTheme.onSurfaceDim;
    }
  }
}

// ── Practice / Qualifying stats ───────────────────────────────────────────────

class _PqStats extends StatelessWidget {
  final RaceResultRow row;
  const _PqStats({required this.row});

  static const _tyreColors = {
    'SS': Color(0xFFD65E56),
    'S':  Color(0xFFD9C777),
    'M':  Color(0xFFD9D9D9),
    'H':  Color(0xFFD99A57),
    'I':  Color(0xFF82A674),
    'W':  Color(0xFF4786B3),
  };

  @override
  Widget build(BuildContext context) {
    final tyreColor =
        _tyreColors[row.tyre] ?? AppTheme.onSurfaceDim;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment:  MainAxisAlignment.center,
      children: [
        Text(row.time,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface)),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text(row.gap,
              style: const TextStyle(
                  fontSize: 9, color: AppTheme.onSurfaceDim)),
          if (row.tyre.isNotEmpty) ...[
            const SizedBox(width: 6),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color:        tyreColor.withOpacity(0.18),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text(row.tyre,
                  style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: tyreColor)),
            ),
          ],
        ]),
      ],
    );
  }
}

// ── Race stats ────────────────────────────────────────────────────────────────

class _RaceStats extends StatelessWidget {
  final RaceResultRow row;
  const _RaceStats({required this.row});

  @override
  Widget build(BuildContext context) {
    final hasPoints =
        row.points.isNotEmpty && row.points != '-';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisAlignment:  MainAxisAlignment.center,
      children: [
        Text(row.time,
            style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurface)),
        const SizedBox(height: 2),
        Row(mainAxisSize: MainAxisSize.min, children: [
          Text('${row.pits}P',
              style: const TextStyle(
                  fontSize: 9, color: AppTheme.onSurfaceDim)),
          const SizedBox(width: 6),
          if (hasPoints)
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: 5, vertical: 1),
              decoration: BoxDecoration(
                color:        AppTheme.accent.withOpacity(0.18),
                borderRadius: BorderRadius.circular(3),
              ),
              child: Text('${row.points}pts',
                  style: const TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.accent)),
            )
          else
            Text(row.points.isEmpty ? '-' : row.points,
                style: const TextStyle(
                    fontSize: 9, color: AppTheme.onSurfaceDim)),
        ]),
      ],
    );
  }
}
