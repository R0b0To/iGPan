import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/hq_data.dart';
import '../../providers/game_provider.dart';
import '../../providers/providers.dart';
import '../../providers/session_provider.dart';
import '../../ui/theme/app_theme.dart';

/// Bottom sheet showing all HQ facilities with condition, level, key stats,
/// and Repair / Upgrade / Collect action buttons.
///
/// Basic facility info is available immediately from [facilities] (fireUp data).
/// Detailed info (level, options, cost) is fetched lazily in parallel on open.
class HqSheet extends ConsumerStatefulWidget {
  final String           accountEmail;
  final List<HqFacility> facilities;
  

  const HqSheet({
    super.key,
    required this.accountEmail,
    required this.facilities,
  });

  @override
  ConsumerState<HqSheet> createState() => _HqSheetState();
}

class _HqSheetState extends ConsumerState<HqSheet> {
  // facilityId → loaded detail (null while loading)
  final Map<String, HqFacilityDetail> _details  = {};
  final Set<String> _loadingDetail               = {};
  final Set<String> _repairing                   = {};
  final Set<String> _upgrading                   = {};
  final Set<String> _collecting                  = {};
  /// True when any loaded facility detail reports an active upgrade.
/// While true, no other facility may start an upgrade.
bool get _anyFacilityUpgrading =>
    _details.values.any((d) => d.isUnderConstruction);

  @override
  void initState() {
    super.initState();
    // Kick off all detail fetches in parallel
    for (final f in widget.facilities) {
      _fetchDetail(f.id);
    }
  }

  // ─── Fetch ─────────────────────────────────────────────────────────────

  Future<void> _fetchDetail(String id) async {
    if (_loadingDetail.contains(id)) return;
    setState(() => _loadingDetail.add(id));
    try {
      final detail = await ref
          .read(hqServiceProvider)
          .fetchFacility(widget.accountEmail, facilityId: id);
      if (mounted) setState(() => _details[id] = detail);
    } catch (_) {
      // silently ignore — card stays in basic mode
    } finally {
      if (mounted) setState(() => _loadingDetail.remove(id));
    }
  }

  // ─── Actions ───────────────────────────────────────────────────────────

  Future<void> _repair(String facilityId, String fId) async {
    if (_repairing.contains(facilityId)) return;
    setState(() => _repairing.add(facilityId));
    try {
      await ref
          .read(hqServiceProvider)
          .repairFacility(widget.accountEmail, fId: fId);
      // Refresh detail and session balance
      await Future.wait([
        _fetchDetail(facilityId),
        ref.read(sessionStateProvider(widget.accountEmail).notifier).refresh(),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Maintenance complete!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Repair failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _repairing.remove(facilityId));
    }
  }

  Future<void> _upgrade(
      String facilityId, String fType, String costStr, String timeStr) async {
    if (_upgrading.contains(facilityId)) return;
    final confirmed = await _confirmUpgrade(costStr, timeStr);
    if (!confirmed || !mounted) return;

    setState(() => _upgrading.add(facilityId));
    try {
      await ref
          .read(hqServiceProvider)
          .upgradeFacility(widget.accountEmail, fType: fType);
      await Future.wait([
        _fetchDetail(facilityId),
        ref.read(sessionStateProvider(widget.accountEmail).notifier).refresh(),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Upgrade started!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Upgrade failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _upgrading.remove(facilityId));
    }
  }

  Future<void> _collect(String facilityId, String collectUrl) async {
    if (_collecting.contains(facilityId)) return;
    setState(() => _collecting.add(facilityId));
    try {
      await ref.read(gameServiceProvider).collectHqFacility(
            widget.accountEmail,
            collectUrl: collectUrl,
          );
      await Future.wait([
        _fetchDetail(facilityId),
        ref.read(sessionStateProvider(widget.accountEmail).notifier).refresh(),
      ]);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Collected!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Collect failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _collecting.remove(facilityId));
    }
  }

  Future<bool> _confirmUpgrade(String costStr, String timeStr) async =>
      await showDialog<bool>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text('Upgrade facility?'),
              content: Text(
                'Cost: $costStr'
                '${timeStr.isNotEmpty ? '\nBuild time: $timeStr' : ''}',
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    child: const Text('Upgrade')),
              ],
            ),
          ) ??
          false;

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.72,
      minChildSize:     0.45,
      maxChildSize:     0.95,
      expand:           false,
      builder: (_, scrollCtrl) => Column(
        children: [
          // Handle
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
            child: Row(children: [
              const Icon(Icons.domain_outlined,
                  size: 17, color: AppTheme.onSurface),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Headquarters',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface)),
              ),
              // Collectables badge
              if (widget.facilities.any((f) => f.hasCollectable)) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color:        AppTheme.success.withOpacity(0.14),
                    borderRadius: BorderRadius.circular(6),
                    border:       Border.all(color: AppTheme.success, width: 0.8),
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.inventory_2_outlined,
                        size: 11, color: AppTheme.success),
                    const SizedBox(width: 4),
                    Text(
                        '${widget.facilities.where((f) => f.hasCollectable).length} ready',
                        style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.success)),
                  ]),
                ),
              ],
            ]),
          ),
          const Divider(color: AppTheme.border, thickness: 0.5, height: 0),
          // List
          Expanded(
            child: widget.facilities.isEmpty
                ? const Center(
                    child: Text('No facilities found.',
                        style: TextStyle(
                            color: AppTheme.onSurfaceDim, fontSize: 13)))
                : ListView.separated(
                    controller:  scrollCtrl,
                    padding: const EdgeInsets.fromLTRB(12, 10, 12, 32),
                    itemCount:   widget.facilities.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 8),
                    itemBuilder: (_, i) {
                      final f = widget.facilities[i];
return _FacilityCard(
  facility:             f,
  detail:               _details[f.id],
  isLoadingDetail:      _loadingDetail.contains(f.id),
  isRepairing:          _repairing.contains(f.id),
  isUpgrading:          _upgrading.contains(f.id),
  isCollecting:         _collecting.contains(f.id),
  anyFacilityUpgrading: _anyFacilityUpgrading,
  onRepair:    (fId) => _repair(f.id, fId),
  onUpgrade:   (fType, cost, time) => _upgrade(f.id, fType, cost, time),
  onCollect:   (url) => _collect(f.id, url),
);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ─── Facility card ────────────────────────────────────────────────────────────

class _FacilityCard extends StatelessWidget {
  final HqFacility         facility;
  final HqFacilityDetail?  detail;
  final bool               isLoadingDetail;
  final bool               isRepairing;
  final bool               isUpgrading;
  final bool               isCollecting;
  final void Function(String fId)                    onRepair;
  final void Function(String fType, String cost, String time) onUpgrade;
  final void Function(String url)                    onCollect;
  final bool anyFacilityUpgrading;

  const _FacilityCard({
    required this.anyFacilityUpgrading,
    required this.facility,
    required this.detail,
    required this.isLoadingDetail,
    required this.isRepairing,
    required this.isUpgrading,
    required this.isCollecting,
    required this.onRepair,
    required this.onUpgrade,
    required this.onCollect,
  });
String _formatEndTime(DateTime end) {
  final diff = end.toLocal().difference(DateTime.now());
  if (diff.isNegative) return 'finishing…';
  if (diff.inHours > 0) {
    return '${diff.inHours}h ${diff.inMinutes.remainder(60)}m';
  }
  return '${diff.inMinutes}m';
}
  @override
  Widget build(BuildContext context) {
    final condition = detail?.condition ?? facility.condition;
    final condColor = _condColor(condition);

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
      decoration: BoxDecoration(
        color:        AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(11),
        border:       Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Top row: condition + name + level + stars ──────────
          Row(children: [
            // Condition circle
            SizedBox(
              width: 40, height: 40,
              child: Stack(alignment: Alignment.center, children: [
                CircularProgressIndicator(
                  value:           condition / 100,
                  strokeWidth:     3,
                  backgroundColor: AppTheme.border,
                  valueColor:      AlwaysStoppedAnimation(condColor),
                ),
                Text('$condition',
                    style: TextStyle(
                        fontSize: 9,
                        fontWeight: FontWeight.w700,
                        color: condColor)),
              ]),
            ),
            const SizedBox(width: 10),
            // Name + level
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(
                      child: Text(
                        detail != null ? detail!.name : facility.name,
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.onSurface),
                      ),
                    ),
                    if (detail != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color:        AppTheme.primary.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text('Lv. ${detail!.level}',
                            style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary)),
                      ),
                    ] else if (isLoadingDetail)
                      const SizedBox(
                          width: 12,
                          height: 12,
                          child: CircularProgressIndicator(
                              strokeWidth: 1.5,
                              color: AppTheme.onSurfaceDim)),
                  ]),
                  const SizedBox(height: 3),
                  Row(children: [
                    _StarsRow(
                        stars:      facility.stars,
                        hasHalf:    facility.hasHalfStar),
                    if (detail != null && detail!.info.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(detail!.info,
                            style: const TextStyle(
                                fontSize: 10,
                                color: AppTheme.onSurfaceDim),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis),
                      ),
                    ],
                  ]),
                ],
              ),
            ),
          ]),

          // ── Notices (key stats) ────────────────────────────────
if (detail != null && detail!.isUnderConstruction) ...[
  const SizedBox(height: 8),
  Row(children: [
    const Icon(Icons.construction_outlined, size: 13, color: AppTheme.accent),
    const SizedBox(width: 6),
    Expanded(child: Text(
      detail!.constructionEndTime != null
          ? 'Upgrading until ${_formatEndTime(detail!.constructionEndTime!)}'
          : 'Upgrading…',
      style: const TextStyle(
          fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.accent),
    )),
  ]),
] else if (detail != null && detail!.notices.isNotEmpty) ...[
  const SizedBox(height: 8),
  ...detail!.notices.map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Text(n,
                      style: const TextStyle(
                          fontSize: 11, color: AppTheme.onSurface)),
                ))
],

          // ── Action buttons ─────────────────────────────────────
          if (detail != null || facility.hasCollectable) ...[
            const SizedBox(height: 10),
            const Divider(color: AppTheme.border, thickness: 0.5, height: 0),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                // Collect
                if (facility.hasCollectable)
                  _ActionBtn(
                    label:     'Collect${facility.collectLabel != null ? ' (${facility.collectLabel})' : ''}',
                    color:     AppTheme.success,
                    loading:   isCollecting,
                    onTap:     () => onCollect(facility.collectUrl!),
                  ),
                // Repair (maintenance)
                if (detail != null && detail!.canRepair)
                  _ActionBtn(
                    label:   'Repair ${detail!.repairCostStr}',
                    color:   AppTheme.primary,
                    loading: isRepairing,
                    onTap:   () => onRepair(detail!.fId),
                  ),
                // Upgrade
if (detail != null && detail!.canUpgrade)
  _ActionBtn(
    label:   anyFacilityUpgrading
        ? 'Upgrade ${detail!.upgradeCostStr} (locked)'
        : 'Upgrade ${detail!.upgradeCostStr}'
               '${detail!.upgradeTimeStr.isNotEmpty ? "  ⏱ ${detail!.upgradeTimeStr}" : ""}',
    color:   anyFacilityUpgrading ? AppTheme.onSurfaceDim : AppTheme.accent,
    loading: isUpgrading,
    onTap:   anyFacilityUpgrading ? () {} : () => onUpgrade(
        detail!.fType, detail!.upgradeCostStr, detail!.upgradeTimeStr),
  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Color _condColor(int c) {
    if (c >= 80) return AppTheme.success;
    if (c >= 50) return AppTheme.accent;
    return AppTheme.error;
  }
}

// ─── Stars row ────────────────────────────────────────────────────────────────

class _StarsRow extends StatelessWidget {
  final int  stars;
  final bool hasHalf;
  const _StarsRow({required this.stars, required this.hasHalf});

  @override
  Widget build(BuildContext context) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < stars; i++)
            const Icon(Icons.star_rounded, size: 11, color: AppTheme.accent),
          if (hasHalf)
            const Icon(Icons.star_half_rounded, size: 11, color: AppTheme.accent),
        ],
      );
}

// ─── Action button ────────────────────────────────────────────────────────────

class _ActionBtn extends StatelessWidget {
  final String       label;
  final Color        color;
  final bool         loading;
  final VoidCallback onTap;

  const _ActionBtn({
    required this.label,
    required this.color,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color:        color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: color, width: 0.8),
        ),
        child: loading
            ? SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 1.8, color: color))
            : Text(label,
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: color)),
      ),
    );
  }
}
