import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/driver_data.dart';
import '../../models/staff_data.dart';
import '../../providers/providers.dart';
import '../../providers/session_provider.dart';
import '../../ui/theme/app_theme.dart';

/// Full-screen bottom sheet showing all drivers and staff with contract status.
///
/// Watches [sessionStateProvider] live so rows auto-update immediately
/// after extending a contract (which triggers a session refresh).
class StaffSheet extends ConsumerStatefulWidget {
  final String accountEmail;
  final int    numCars;

  const StaffSheet({
    super.key,
    required this.accountEmail,
    required this.numCars,
  });

  @override
  ConsumerState<StaffSheet> createState() => _StaffSheetState();
}

class _StaffSheetState extends ConsumerState<StaffSheet> {
  // entityId → true while the extend request is in flight
  final Map<String, bool> _extending = {};

  // ─── Contract extension ────────────────────────────────────────────────

  Future<void> _extend({
    required String entityId,
    required bool   isDriver,
    required String displayName,
  }) async {
    final confirmed = await _confirm(displayName);
    if (!confirmed || !mounted) return;

    setState(() => _extending[entityId] = true);
    try {
      await ref.read(staffServiceProvider).extendContract(
        widget.accountEmail,
        entityId: entityId,
        isDriver: isDriver,
      );
      await ref
          .read(sessionStateProvider(widget.accountEmail).notifier)
          .refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("$displayName's contract extended!")));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Extend failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _extending.remove(entityId));
    }
  }

  Future<bool> _confirm(String name) async {
    return await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Extend contract?'),
            content: Text(
                'Extend $name\'s contract for the standard additional term.\n\n'
                'Check the iGP website for exact cost and race count.'),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(ctx, false),
                  child: const Text('Cancel')),
              ElevatedButton(
                  onPressed: () => Navigator.pop(ctx, true),
                  child: const Text('Extend')),
            ],
          ),
        ) ??
        false;
  }

  // ─── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionStateProvider(widget.accountEmail));
    final accountData  = sessionAsync.valueOrNull?.accountData;

    final drivers = accountData?.drivers ?? <DriverData>[];
    final staffData = accountData?.staffData;

    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize:     0.4,
      maxChildSize:     0.95,
      expand:           false,
      builder: (_, scrollCtrl) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ──────────────────────────────────────────────
          const SizedBox(height: 12),
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          // ── Header ──────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
            child: Row(children: [
              const Icon(Icons.people_rounded,
                  size: 17, color: AppTheme.onSurface),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Drivers & Staff',
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface)),
              ),
              // Global expiry badge
              if (accountData != null) ..._buildExpiryBadges(drivers, staffData),
            ]),
          ),
          const Divider(color: AppTheme.border, thickness: 0.5, height: 0),

          // ── Scrollable content ───────────────────────────────────
          Expanded(
            child: sessionAsync.when(
              loading: () => const Center(
                  child: CircularProgressIndicator(strokeWidth: 2)),
              error: (e, _) => Center(
                  child: Text('Error: $e',
                      style: const TextStyle(
                          color: AppTheme.onSurfaceDim, fontSize: 13))),
              data: (_) => ListView(
                controller: scrollCtrl,
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: [
                  // ── Drivers ──────────────────────────────────────
                  if (drivers.isNotEmpty) ...[
                    _SectionHeader(label: 'DRIVERS (${drivers.length})'),
                    ...drivers.asMap().entries.map((e) {
                      final d = e.value;
                      return _DriverRow(
                        driver:    d,
                        carNum:    e.key + 1,
                        isLoading: _extending[d.id] == true,
                        onExtend:  () => _extend(
                          entityId:    d.id,
                          isDriver:    true,
                          displayName: d.fullName,
                        ),
                      );
                    }),
                  ],

                  // ── Main staff ───────────────────────────────────
                  if (staffData != null &&
                      staffData.mainStaff.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _SectionHeader(label: 'STAFF'),
                    ...staffData.mainStaff.map((s) => _StaffRow(
                          member:    s,
                          isLoading: _extending[s.id] == true,
                          onExtend:  () => _extend(
                            entityId:    s.id,
                            isDriver:    false,
                            displayName: s.fullName,
                          ),
                        )),
                  ],

                  // ── Reserve staff ─────────────────────────────────
                  if (staffData != null &&
                      staffData.reserveStaff.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    _SectionHeader(
                        label:
                            'RESERVE (${staffData.reserveStaff.length})'),
                    ...staffData.reserveStaff.map((s) => _StaffRow(
                          member:    s,
                          isLoading: _extending[s.id] == true,
                          onExtend:  () => _extend(
                            entityId:    s.id,
                            isDriver:    false,
                            displayName: s.fullName,
                          ),
                        )),
                  ],

                  if (drivers.isEmpty && (staffData?.all.isEmpty ?? true))
                    const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text('No staff data available.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              color: AppTheme.onSurfaceDim, fontSize: 13)),
                    ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildExpiryBadges(
      List<DriverData> drivers, StaffData? staff) {
    final driverExpiring =
        drivers.where((d) => d.isContractExpiringSoon).length;
    final staffExpiring = staff?.expiringCount ?? 0;
    final total = driverExpiring + staffExpiring;
    if (total == 0) return [];
    return [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:        AppTheme.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: AppTheme.error, width: 0.8),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.warning_amber_rounded,
              size: 12, color: AppTheme.error),
          const SizedBox(width: 4),
          Text('$total expiring',
              style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.error)),
        ]),
      ),
    ];
  }
}

// ─── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  const _SectionHeader({required this.label});

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(label,
            style: const TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: AppTheme.onSurfaceDim,
                letterSpacing: 0.5)),
      );
}

// ─── Driver row ───────────────────────────────────────────────────────────────

class _DriverRow extends StatelessWidget {
  final DriverData   driver;
  final int          carNum;
  final bool         isLoading;
  final VoidCallback onExtend;

  const _DriverRow({
    required this.driver,
    required this.carNum,
    required this.isLoading,
    required this.onExtend,
  });

  @override
  Widget build(BuildContext context) {
    final races = driver.contractRacesNum;
    return _PersonTile(
      initial:       driver.fullName.isNotEmpty
          ? driver.fullName[0].toUpperCase()
          : 'D',
      name:          driver.fullName,
      subtitle:      'Car $carNum  ·  ${driver.salary}',
      stars:         driver.stars,
      hasHalfStar:   false,
      contractRaces: races,
      isLoading:     isLoading,
      onExtend:      onExtend,
    );
  }
}

// ─── Staff row ────────────────────────────────────────────────────────────────

class _StaffRow extends StatelessWidget {
  final StaffMember  member;
  final bool         isLoading;
  final VoidCallback onExtend;

  const _StaffRow({
    required this.member,
    required this.isLoading,
    required this.onExtend,
  });

  @override
  Widget build(BuildContext context) => _PersonTile(
        initial:       member.fullName.isNotEmpty
            ? member.fullName[0].toUpperCase()
            : member.roleCode[0],
        name:          member.fullName,
        subtitle:      '${member.roleLabel}  ·  ${member.salary}',
        stars:         member.stars,
        hasHalfStar:   member.hasHalfStar,
        contractRaces: member.contractRaces,
        isLoading:     isLoading,
        onExtend:      onExtend,
      );
}

// ─── Shared person tile ───────────────────────────────────────────────────────

class _PersonTile extends StatelessWidget {
  final String       initial;
  final String       name;
  final String       subtitle;
  final int          stars;
  final bool         hasHalfStar;
  final int          contractRaces;
  final bool         isLoading;
  final VoidCallback onExtend;

  const _PersonTile({
    required this.initial,
    required this.name,
    required this.subtitle,
    required this.stars,
    required this.hasHalfStar,
    required this.contractRaces,
    required this.isLoading,
    required this.onExtend,
  });

  Color get _contractColor {
    if (contractRaces <= 0) return AppTheme.onSurfaceDim;
    if (contractRaces <= 3) return AppTheme.error;
    if (contractRaces <= 10) return AppTheme.accent;
    return AppTheme.success;
  }

  Color get _initialBg {
    if (contractRaces <= 0) return AppTheme.surfaceRaised;
    if (contractRaces <= 3) return AppTheme.error.withOpacity(0.18);
    if (contractRaces <= 10) return AppTheme.accent.withOpacity(0.18);
    return AppTheme.success.withOpacity(0.18);
  }

  @override
  Widget build(BuildContext context) {
    final contractLabel = contractRaces > 0
        ? '$contractRaces race${contractRaces == 1 ? '' : 's'}'
        : '—';
    final expiringSoon = contractRaces > 0 && contractRaces <= 3;

    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(10, 9, 10, 9),
      decoration: BoxDecoration(
        color: expiringSoon
            ? AppTheme.error.withOpacity(0.05)
            : AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: expiringSoon ? AppTheme.error.withOpacity(0.3) : AppTheme.border,
          width: 0.5,
        ),
      ),
      child: Row(children: [
        // Initial circle
        Container(
          width:  36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(shape: BoxShape.circle, color: _initialBg),
          child: Text(initial,
              style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _contractColor)),
        ),
        const SizedBox(width: 10),

        // Name + info
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(name,
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.onSurface),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              _StarsWidget(stars: stars, hasHalf: hasHalfStar),
            ]),
            const SizedBox(height: 3),
            Row(children: [
              Flexible(
                child: Text(subtitle,
                    style: const TextStyle(
                        fontSize: 10, color: AppTheme.onSurfaceDim),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ),
              const SizedBox(width: 6),
              // Contract countdown
              Row(mainAxisSize: MainAxisSize.min, children: [
                if (expiringSoon)
                  const Icon(Icons.warning_amber_rounded,
                      size: 11, color: AppTheme.error),
                const SizedBox(width: 2),
                Text(contractLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: _contractColor)),
              ]),
            ]),
          ]),
        ),
        const SizedBox(width: 8),

        // Extend button
        _ExtendButton(isLoading: isLoading, onTap: onExtend),
      ]),
    );
  }
}

// ─── Stars widget ─────────────────────────────────────────────────────────────

class _StarsWidget extends StatelessWidget {
  final int  stars;
  final bool hasHalf;
  const _StarsWidget({required this.stars, required this.hasHalf});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      for (var i = 0; i < stars; i++)
        const Icon(Icons.star_rounded, size: 10, color: AppTheme.accent),
      if (hasHalf)
        const Icon(Icons.star_half_rounded, size: 10, color: AppTheme.accent),
    ]);
  }
}

// ─── Extend button ────────────────────────────────────────────────────────────

class _ExtendButton extends StatelessWidget {
  final bool         isLoading;
  final VoidCallback onTap;
  const _ExtendButton({required this.isLoading, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isLoading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        AppTheme.success.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: AppTheme.success, width: 0.8),
        ),
        child: isLoading
            ? const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 1.8, color: AppTheme.success))
            : const Text('Extend',
                style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.success)),
      ),
    );
  }
}
