import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/car_data.dart';
import '../../providers/providers.dart';
import '../../providers/session_provider.dart';
import '../../ui/theme/app_theme.dart';

/// Bottom sheet showing parts and engine condition for up to 2 cars,
/// with buttons to repair parts or replace the engine.
class CarRepairSheet extends ConsumerStatefulWidget {
  final CarData carData;
  final String  accountEmail;
  final int     numCars;

  const CarRepairSheet({
    super.key,
    required this.carData,
    required this.accountEmail,
    required this.numCars,
  });

  @override
  ConsumerState<CarRepairSheet> createState() => _CarRepairSheetState();
}

class _CarRepairSheetState extends ConsumerState<CarRepairSheet> {
  // Track in-flight requests per (carNumber, type) to prevent double-taps
  final Set<String> _loading = {};

  bool _isLoading(int carNum, String type) => _loading.contains('$carNum-$type');

  Future<void> _repair(CarCondition cond, String type) async {
    final key = '${cond.carNumber}-$type';
    if (_loading.contains(key)) return;
    setState(() => _loading.add(key));

    try {
      final svc = ref.read(carServiceProvider);
      if (type == 'parts') {
        await svc.repairParts(widget.accountEmail,
            carId: cond.carId, carNumber: cond.carNumber);
      } else {
        await svc.replaceEngine(widget.accountEmail,
            carId: cond.carId, carNumber: cond.carNumber);
      }

      await ref
          .read(sessionStateProvider(widget.accountEmail).notifier)
          .refresh();

      if (mounted) {
        final label = type == 'parts' ? 'Parts repaired' : 'Engine replaced';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Car ${cond.carNumber}: $label!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Car ${cond.carNumber} failed: $e')));
    } finally {
      if (mounted) setState(() => _loading.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c1 = widget.carData.car1Condition;
    final c2 = widget.numCars >= 2 ? widget.carData.car2Condition : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // ── Handle ─────────────────────────────────────────
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),

          // ── Title ──────────────────────────────────────────
          const Row(children: [
            Text('Car Repair',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600,
                    color: AppTheme.onSurface)),
          ]),
          const SizedBox(height: 14),

          // ── Car sections ───────────────────────────────────
          if (c1 != null) _CarSection(
            condition:   c1,
            onRepair:    c1.partsLocked  ? null : () => _repair(c1, 'parts'),
            onEngine:    c1.engineLocked ? null : () => _repair(c1, 'engine'),
            partsLoading:  _isLoading(1, 'parts'),
            engineLoading: _isLoading(1, 'engine'),
          ),

          if (c1 != null && c2 != null)
            const SizedBox(height: 10),

          if (c2 != null) _CarSection(
            condition:   c2,
            onRepair:    c2.partsLocked  ? null : () => _repair(c2, 'parts'),
            onEngine:    c2.engineLocked ? null : () => _repair(c2, 'engine'),
            partsLoading:  _isLoading(2, 'parts'),
            engineLoading: _isLoading(2, 'engine'),
          ),

          if (c1 == null && c2 == null) ...[
            const SizedBox(height: 24),
            const Center(
              child: Text('No car data available',
                  style: TextStyle(
                      color: AppTheme.onSurfaceDim, fontSize: 13)),
            ),
            const SizedBox(height: 24),
          ],
        ],
      ),
    );
  }
}

// ─── Car section ──────────────────────────────────────────────────────────────

class _CarSection extends StatelessWidget {
  final CarCondition  condition;
  final VoidCallback? onRepair;
  final VoidCallback? onEngine;
  final bool          partsLoading;
  final bool          engineLoading;

  const _CarSection({
    required this.condition,
    this.onRepair,
    this.onEngine,
    required this.partsLoading,
    required this.engineLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding:    const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(10),
        border:       Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Car label
          Text('CAR ${condition.carNumber}',
              style: const TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceDim, letterSpacing: 0.5)),
          const SizedBox(height: 10),

          // Parts row
          _RepairRow(
            icon:     Icons.build_rounded,
            label:    'Parts',
            value:    condition.partsValue,
            cost:     condition.partsCost,
            locked:   condition.partsLocked,
            loading:  partsLoading,
            onTap:    onRepair,
          ),
          const SizedBox(height: 8),

          // Engine row
          _RepairRow(
            icon:     Icons.developer_board_rounded,
            label:    'Engine',
            value:    condition.engineValue,
            cost:     condition.engineCost,
            locked:   condition.engineLocked,
            loading:  engineLoading,
            onTap:    onEngine,
          ),
        ],
      ),
    );
  }
}

// ─── Repair row ───────────────────────────────────────────────────────────────

class _RepairRow extends StatelessWidget {
  final IconData      icon;
  final String        label;
  final int           value;    // 0-100
  final int           cost;
  final bool          locked;
  final bool          loading;
  final VoidCallback? onTap;

  const _RepairRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.cost,
    required this.locked,
    required this.loading,
    this.onTap,
  });

  Color get _conditionColor {
    if (value >= 80) return AppTheme.success;
    if (value >= 50) return const Color(0xFFE8A020); // amber
    return AppTheme.error;
  }

  bool get _needsRepair => value < 100;

  @override
  Widget build(BuildContext context) {
    final canRepair = _needsRepair && !locked && onTap != null;

    return Row(children: [
      // Condition circle
      Container(
        width: 40, height: 40,
        decoration: BoxDecoration(
          shape:  BoxShape.circle,
          color:  _conditionColor.withOpacity(0.12),
          border: Border.all(color: _conditionColor.withOpacity(0.4), width: 1),
        ),
        child: Stack(alignment: Alignment.center, children: [
          SizedBox(
            width: 36, height: 36,
            child: CircularProgressIndicator(
              value:           value / 100,
              strokeWidth:     3,
              backgroundColor: AppTheme.border,
              valueColor:      AlwaysStoppedAnimation<Color>(_conditionColor),
            ),
          ),
          Text('$value',
              style: TextStyle(
                  fontSize: 11, fontWeight: FontWeight.w700,
                  color: _conditionColor)),
        ]),
      ),
      const SizedBox(width: 12),

      // Label + bar
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Icon(icon, size: 13, color: AppTheme.onSurfaceDim),
              const SizedBox(width: 5),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w600,
                      color: AppTheme.onSurface)),
              if (locked) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                  decoration: BoxDecoration(
                    color:        AppTheme.onSurfaceFaint.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: const Text('Locked',
                      style: TextStyle(fontSize: 8, color: AppTheme.onSurfaceDim)),
                ),
              ],
            ]),
            const SizedBox(height: 4),
            ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value:           value / 100,
                backgroundColor: AppTheme.border,
                valueColor:      AlwaysStoppedAnimation<Color>(_conditionColor),
                minHeight:       3,
              ),
            ),
          ],
        ),
      ),
      const SizedBox(width: 10),

      // Repair button
      if (_needsRepair)
        _RepairBtn(
          cost:    cost,
          locked:  locked,
          loading: loading,
          onTap:   canRepair ? onTap : null,
        )
      else
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 8),
          child: Icon(Icons.check_circle_outline_rounded,
              size: 18, color: AppTheme.success),
        ),
    ]);
  }
}

// ─── Repair button ────────────────────────────────────────────────────────────

class _RepairBtn extends StatelessWidget {
  final int           cost;
  final bool          locked;
  final bool          loading;
  final VoidCallback? onTap;

  const _RepairBtn({
    required this.cost,
    required this.locked,
    required this.loading,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final active = onTap != null && !locked;

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color:        active
              ? AppTheme.primary.withOpacity(0.15)
              : AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(
            color: active ? AppTheme.primary : AppTheme.border,
            width: 0.5,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 14, height: 14,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: AppTheme.primary))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(Icons.build_rounded, size: 12,
                    color: active ? AppTheme.primary : AppTheme.onSurfaceDim),
                const SizedBox(width: 4),
                Text('$cost',
                    style: TextStyle(
                        fontSize: 12, fontWeight: FontWeight.w600,
                        color: active
                            ? AppTheme.primary
                            : AppTheme.onSurfaceDim)),
                const SizedBox(width: 2),
                Icon(Icons.bolt, size: 11,
                    color: active ? AppTheme.primary : AppTheme.onSurfaceDim),
              ]),
      ),
    );
  }
}
