import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/car_data.dart';
import '../../providers/game_provider.dart';
import '../../providers/providers.dart';
import '../../providers/session_provider.dart';
import '../../ui/theme/app_theme.dart';

class CarResearchSheet extends ConsumerStatefulWidget {
  final CarData carData;
  final String accountEmail;

  const CarResearchSheet({
    super.key,
    required this.carData,
    required this.accountEmail,
  });

  @override
  ConsumerState<CarResearchSheet> createState() => _CarResearchSheetState();
}

class _CarResearchSheetState extends ConsumerState<CarResearchSheet> {
  late Set<String> _originalResearch;
  late Set<String> _selectedResearch;
  late Map<String, int> _designValues;
  late List<String> _recommendedKeys;
  bool _saving = false;
  bool _collectingDp = false;

  int get _dpSpent => widget.carData.attributes.fold(
      0, (s, a) => s + max(0, (_designValues[a.key] ?? a.baseValue) - a.baseValue));
      
  int get _dpRemaining => widget.carData.designPoints - _dpSpent;
  
  bool get _hasDesignChanges => _dpSpent > 0;
  
  bool get _hasResearchChanges =>
      _originalResearch.length != _selectedResearch.length ||
      _originalResearch.any((k) => !_selectedResearch.contains(k));
      
  bool get _canSave =>
      (_hasResearchChanges && _selectedResearch.isNotEmpty) || _hasDesignChanges;

  int get _totalResearchGain {
    return _selectedResearch.fold(0, (sum, key) {
      final attr = widget.carData.attributes.firstWhere((a) => a.key == key);
      return sum + _estimatedGain(attr);
    });
  }

  String get _saveLabel {
    final parts = [
      if (_hasResearchChanges && _selectedResearch.isNotEmpty) 'Research',
      if (_hasDesignChanges) 'Design'
    ];
    return parts.isEmpty ? 'No changes' : 'Save ${parts.join(' & ')}';
  }

  String? get _saveSublabel {
    final parts = [
      if (_hasResearchChanges && _selectedResearch.isNotEmpty)
        '${_selectedResearch.length} attr${_selectedResearch.length == 1 ? "" : "s"} (+$_totalResearchGain pts)',
      if (_hasDesignChanges) '$_dpSpent DP',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  @override
  void initState() {
    super.initState();
    _originalResearch = Set.from(widget.carData.currentResearch);
    _selectedResearch = Set.from(widget.carData.currentResearch);
    _designValues = {for (final a in widget.carData.attributes) a.key: a.baseValue};
    _recommendedKeys = _calculateRecommendations();
  }

  /// Calculates the best attributes to research based on game meta priorities
  List<String> _calculateRecommendations() {
    final weights = {
      'acceleration': 1.0,
      'braking': 1.0,
      'downforce': 1.0,
      'handling': 1.0,
      'fuel economy': 0.5,
      'fuel_economy': 0.5,
      'tyre economy': 0.25,
      'tyre_economy': 0.25,
    }; // Cooling and reliability implicitly get 0.0

    final scored = widget.carData.attributes.map((attr) {
      final weight = weights[attr.key.toLowerCase()] ?? 0.0;
      if (weight == 0.0 || attr.isAtLeagueMax) return MapEntry(attr.key, 0.0);

      // Evaluate raw potential gain to find highest value investments
      final scale = attr.isStrength ? 1.1 : (attr.isWeakness ? 0.5 : 1.0);
      final rawPotential = widget.carData.researchMaxEffect * 
          ((attr.leagueMax - attr.baseValue) / attr.leagueMax) * scale;

      return MapEntry(attr.key, rawPotential * weight);
    }).where((e) => e.value > 0).toList();

    scored.sort((a, b) => b.value.compareTo(a.value));
    return scored.take(2).map((e) => e.key).toList();
  }

  int _estimatedGain(CarAttribute attr) {
    final n = _selectedResearch.length;
    if (n == 0 || !_selectedResearch.contains(attr.key) || attr.leagueMax <= 0 || attr.baseValue >= attr.leagueMax) {
      return 0;
    }
    final scale = attr.isStrength ? 1.1 : (attr.isWeakness ? 0.5 : 1.0);
    return ((widget.carData.researchMaxEffect / n) * ((attr.leagueMax - attr.baseValue) / attr.leagueMax) * scale).ceil();
  }

  void _toggleResearch(String key) => setState(() =>
      _selectedResearch.contains(key) ? _selectedResearch.remove(key) : _selectedResearch.add(key));

  void _increment(String k) {
    if (_dpRemaining > 0 && _designValues[k]! < widget.carData.dMax) {
      setState(() => _designValues[k] = _designValues[k]! + 1);
    }
  }

  void _decrement(String k) {
    if (_designValues[k]! > widget.carData.attributeByKey(k)!.baseValue) {
      setState(() => _designValues[k] = _designValues[k]! - 1);
    }
  }

  Future<void> _save() async {
    if (_saving || !_canSave) return;
    setState(() => _saving = true);
    final errors = [];

    if (_hasResearchChanges && _selectedResearch.isNotEmpty) {
      try {
        await ref.read(carServiceProvider).submitResearch(widget.accountEmail, leagueId: widget.carData.researchLeagueId, attributes: _selectedResearch.toList());
      } catch (e) {
        errors.add('Research: $e');
      }
    }
    if (_hasDesignChanges) {
      try {
        await ref.read(carServiceProvider).submitDesign(widget.accountEmail, carId: widget.carData.carDesignId, leagueId: widget.carData.designLeagueId, attributeValues: Map.from(_designValues));
      } catch (e) {
        errors.add('Design: $e');
      }
    }

    await ref.read(sessionStateProvider(widget.accountEmail).notifier).refresh();

    if (mounted) {
      if (errors.isEmpty) {
        Navigator.pop(context);
        final saved = [
          if (_hasResearchChanges && _selectedResearch.isNotEmpty) 'Research',
          if (_hasDesignChanges) 'Design'
        ];
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${saved.join(' & ')} saved!')));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(errors.join('\n'))));
        setState(() => _saving = false);
      }
    }
  }

  /// Collect pending design points from the HQ design studio.
  Future<void> _collectDp() async {
    final dc = widget.carData.designCollect;
    if (dc == null || _collectingDp) return;
    setState(() => _collectingDp = true);
    try {
      await ref.read(gameServiceProvider).collectHqFacility(
        widget.accountEmail,
        collectUrl: dc.collectUrl,
      );
      await ref.read(sessionStateProvider(widget.accountEmail).notifier).refresh();
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('+${dc.designPoints} DP collected!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Collect failed: $e')));
        setState(() => _collectingDp = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final car = widget.carData;
    final strLabel = car.attributeByKey(car.researchStrength)?.label ?? car.researchStrength;
    final wkLabel = car.attributeByKey(car.researchWeakness)?.label ?? car.researchWeakness;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              width: 36, height: 4,
              decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)),
            )
          ),
          const SizedBox(height: 14),
          // ── Title row ─────────────────────────────────────
          Row(children: [
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Car Research & Design', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
                const SizedBox(height: 2),
                Text('$strLabel ↑  $wkLabel ↓  ·  Max ${car.researchMaxEffect.toStringAsFixed(1)}%', style: const TextStyle(fontSize: 10, color: AppTheme.onSurfaceDim)),
              ])
            ),
            // DP collect button — shown when HQ design studio has pending DP
            if (car.designCollect != null) ...[
              _CollectDpButton(
                dp:        car.designCollect!.designPoints,
                loading:   _collectingDp,
                onTap:     _collectDp,
              ),
              const SizedBox(width: 8),
            ],
            if (car.rankOnGrid > 0) _Chip(label: '${_ordinal(car.rankOnGrid)} on grid', color: AppTheme.primary),
          ]),
          const SizedBox(height: 10),
          _DpBar(total: car.designPoints, spent: _dpSpent, remaining: _dpRemaining),
          const SizedBox(height: 10),
          const Row(children: [
            SizedBox(width: 38),
            Expanded(child: Text('Attribute', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: AppTheme.onSurfaceDim, letterSpacing: 0.4))),
            SizedBox(width: 96, child: Text('Design', textAlign: TextAlign.center, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: AppTheme.onSurfaceDim, letterSpacing: 0.4))),
          ]),
          const SizedBox(height: 4),
          const Divider(color: AppTheme.border, thickness: 0.5, height: 0),
          const SizedBox(height: 6),
          ...car.attributes.map((attr) {
            final designVal = _designValues[attr.key] ?? attr.baseValue;
            final canInc = _dpRemaining > 0 && designVal < car.dMax;
            return _AttrRow(
              attr: attr,
              designValue: designVal,
              dpDelta: designVal - attr.baseValue,
              isSelected: _selectedResearch.contains(attr.key),
              isRecommended: _recommendedKeys.contains(attr.key),
              estimGain: _estimatedGain(attr),
              canInc: canInc,
              canDec: designVal > attr.baseValue,
              onToggle: (attr.isAtLeagueMax && !_selectedResearch.contains(attr.key))
                  ? null
                  : () => _toggleResearch(attr.key),
              onIncrement: canInc ? () => _increment(attr.key) : null,
              onDecrement: designVal > attr.baseValue ? () => _decrement(attr.key) : null,
            );
          }),
          const SizedBox(height: 14),
          const Divider(color: AppTheme.border, thickness: 0.5, height: 0),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              decoration: BoxDecoration(
                color: _canSave ? AppTheme.primary.withOpacity(0.18) : AppTheme.surfaceRaised,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: _canSave ? AppTheme.primary : AppTheme.border, width: _canSave ? 1.0 : 0.5),
              ),
              child: Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: (_canSave && !_saving) ? _save : null,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: _saving
                        ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary)))
                        : Column(mainAxisSize: MainAxisSize.min, children: [
                            Text(_saveLabel, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: _canSave ? AppTheme.primary : AppTheme.onSurfaceDim)),
                            const SizedBox(height: 2),
                            Visibility(
                              visible: _saveSublabel != null,
                              maintainSize: true, maintainAnimation: true, maintainState: true,
                              child: Text(_saveSublabel ?? '', style: TextStyle(fontSize: 10, color: _canSave ? AppTheme.primary.withOpacity(0.7) : AppTheme.onSurfaceFaint)),
                            ),
                          ]),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _ordinal(int n) {
    if (n >= 11 && n <= 13) return '${n}th';
    return switch (n % 10) { 1 => '${n}st', 2 => '${n}nd', 3 => '${n}rd', _ => '${n}th' };
  }
}

// ─── Collect DP button ────────────────────────────────────────────────────────

/// Pulsing chip shown in the sheet title when the HQ design studio
/// has design points ready to collect.
class _CollectDpButton extends StatelessWidget {
  final int          dp;
  final bool         loading;
  final VoidCallback onTap;

  const _CollectDpButton({
    required this.dp,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
        decoration: BoxDecoration(
          color:        AppTheme.success.withOpacity(0.14),
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: AppTheme.success, width: 0.8),
        ),
        child: loading
            ? const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(strokeWidth: 1.8, color: AppTheme.success))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.science_outlined, size: 12, color: AppTheme.success),
                const SizedBox(width: 4),
                Text('+$dp DP', style: const TextStyle(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: AppTheme.success)),
              ]),
      ),
    );
  }
}

class _DpBar extends StatelessWidget {
  final int total, spent, remaining;
  const _DpBar({required this.total, required this.spent, required this.remaining});

  @override
  Widget build(BuildContext context) {
    final low = remaining <= (total * 0.15).ceil();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
          color: AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.border, width: 0.5)),
      child: Column(children: [
        Row(children: [
          Icon(Icons.science_outlined, size: 13, color: low ? AppTheme.accent : AppTheme.primary),
          const SizedBox(width: 5),
          const Text('Design Points', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
          const Spacer(),
          RichText(
              text: TextSpan(style: const TextStyle(fontSize: 11), children: [
            TextSpan(text: '$remaining', style: TextStyle(fontWeight: FontWeight.w700, color: low ? AppTheme.accent : AppTheme.onSurface)),
            const TextSpan(text: ' / ', style: TextStyle(color: AppTheme.onSurfaceDim)),
            TextSpan(text: '$total DP', style: const TextStyle(color: AppTheme.onSurfaceDim)),
            if (spent > 0) TextSpan(text: ' −$spent', style: const TextStyle(color: AppTheme.accent, fontWeight: FontWeight.w600)),
          ])),
        ]),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(2),
          child: LinearProgressIndicator(
            value: total > 0 ? (spent / total).clamp(0.0, 1.0) : 0.0,
            backgroundColor: AppTheme.border,
            valueColor: AlwaysStoppedAnimation(spent > 0 ? (low ? AppTheme.accent : AppTheme.primary) : Colors.transparent),
            minHeight: 3,
          ),
        ),
      ]),
    );
  }
}

class _AttrRow extends StatelessWidget {
  final CarAttribute attr;
  final int designValue, dpDelta, estimGain;
  final bool isSelected, isRecommended, canInc, canDec;
  final VoidCallback? onToggle, onIncrement, onDecrement;

  const _AttrRow({
    required this.attr,
    required this.designValue,
    required this.dpDelta,
    required this.isSelected,
    required this.isRecommended,
    required this.estimGain,
    required this.canInc,
    required this.canDec,
    this.onToggle,
    this.onIncrement,
    this.onDecrement,
  });

  Color get _bColor => attr.isAtLeagueMax
      ? AppTheme.accent
      : (attr.isStrength ? AppTheme.success : (attr.isWeakness ? AppTheme.error : AppTheme.primary));

  @override
  Widget build(BuildContext context) {
    final atMax = onToggle == null;
    final hasSpnd = dpDelta > 0;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 5),
      padding: const EdgeInsets.fromLTRB(10, 7, 8, 7),
      decoration: BoxDecoration(
        color: isSelected ? AppTheme.primary.withOpacity(0.08) : AppTheme.surfaceRaised,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isSelected ? AppTheme.primary : (hasSpnd ? AppTheme.accent.withOpacity(0.5) : AppTheme.border),
          width: (isSelected || hasSpnd) ? 1.0 : 0.5
        ),
      ),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        GestureDetector(
          onTap: onToggle,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.only(right: 10),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 130),
              width: 18, height: 18,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppTheme.primary : Colors.transparent,
                  border: Border.all(
                      color: atMax ? AppTheme.border : (isSelected ? AppTheme.primary : AppTheme.borderBright),
                      width: 1.5)),
              child: isSelected ? const Icon(Icons.check, size: 11, color: Colors.white) : null,
            ),
          ),
        ),
        Expanded(
          child: GestureDetector(
            onTap: onToggle,
            behavior: HitTestBehavior.opaque,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(attr.label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: atMax ? AppTheme.onSurfaceDim : AppTheme.onSurface)),
                const SizedBox(width: 4),
                if (attr.isStrength) const _Badge(label: 'STR', color: AppTheme.success),
                if (attr.isWeakness) const _Badge(label: 'WK', color: AppTheme.error),
                if (attr.isAtLeagueMax) const _Badge(label: 'MAX', color: AppTheme.accent),
                if (isRecommended && !attr.isAtLeagueMax) const _Badge(label: 'REC', color: Colors.orange),
                const Spacer(),
                RichText(
                    text: TextSpan(style: const TextStyle(fontSize: 10), children: [
                  TextSpan(text: '${attr.baseValue}', style: const TextStyle(fontWeight: FontWeight.w700, color: AppTheme.onSurface)),
                  if (attr.bonus != 0) TextSpan(text: ' ${attr.bonus > 0 ? '+' : ''}${attr.bonus}', style: TextStyle(fontWeight: FontWeight.w600, color: attr.bonus > 0 ? AppTheme.success : AppTheme.error)),
                  TextSpan(text: ' / ${attr.leagueMax}', style: const TextStyle(color: AppTheme.onSurfaceDim)),
                ])),
              ]),
              const SizedBox(height: 4),
              _SegmentedBar(
                baseValue: attr.baseValue.toDouble(),
                researchGain: estimGain.toDouble(),
                designGain: dpDelta.toDouble(),
                maxValue: attr.leagueMax.toDouble(),
                baseColor: _bColor,
              ),
              const SizedBox(height: 3),
              Visibility(
                visible: estimGain > 0,
                maintainSize: true, maintainAnimation: true, maintainState: true,
                child: Text('≈ +$estimGain from research', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w500, color: _bColor)),
              ),
            ]),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 96,
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _StepBtn(icon: Icons.remove, active: canDec, onTap: onDecrement),
            const SizedBox(width: 4),
            SizedBox(
              width: 34, height: 26,
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Text('$designValue', textAlign: TextAlign.center, style: TextStyle(fontSize: 13, height: 1.1, fontWeight: FontWeight.w700, color: hasSpnd ? AppTheme.accent : AppTheme.onSurface)),
                Visibility(
                  visible: hasSpnd,
                  maintainSize: true, maintainAnimation: true, maintainState: true,
                  child: Text('+$dpDelta', textAlign: TextAlign.center, style: const TextStyle(fontSize: 8, height: 1.1, fontWeight: FontWeight.w600, color: AppTheme.accent)),
                ),
              ]),
            ),
            const SizedBox(width: 4),
            _StepBtn(icon: Icons.add, active: canInc, onTap: onIncrement),
          ]),
        ),
      ]),
    );
  }
}

/// Creates a segmented progress bar showing Base, Projected Research, and Projected Design with clear gaps
class _SegmentedBar extends StatelessWidget {
  final double baseValue;
  final double researchGain;
  final double designGain;
  final double maxValue;
  final Color baseColor;

  const _SegmentedBar({
    required this.baseValue,
    required this.researchGain,
    required this.designGain,
    required this.maxValue,
    required this.baseColor,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        if (maxValue <= 0 || width == 0) return const SizedBox();

        double getW(double val) => (val / maxValue).clamp(0.0, 1.0) * width;

        final wBase = getW(baseValue);
        final wRes = getW(baseValue + researchGain) - wBase;
        final wDes = getW(baseValue + researchGain + designGain) - wBase - wRes;

        final gapBorder = Border(right: BorderSide(color: AppTheme.surfaceRaised, width: 1.5));

        return Container(
          height: 10,
          decoration: BoxDecoration(
            color: AppTheme.border,
            borderRadius: BorderRadius.circular(2.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: Row(
            children: [
              if (wBase > 0) 
                Container(width: wBase, decoration: BoxDecoration(color: baseColor, border: gapBorder)),
              if (wRes > 0) 
                Container(width: wRes, decoration: BoxDecoration(color: baseColor.withOpacity(0.65), border: gapBorder)),
              if (wDes > 0) 
                Container(width: wDes, color: AppTheme.accent),
            ],
          ),
        );
      }
    );
  }
}


class _StepBtn extends StatefulWidget {
  final IconData icon;
  final bool active;
  final VoidCallback? onTap;
  const _StepBtn({required this.icon, required this.active, this.onTap});
  
  @override
  State<_StepBtn> createState() => _StepBtnState();
}

class _StepBtnState extends State<_StepBtn> {
  Timer? _iDly, _rTmr;
  bool _prs = false;
  
  void _onTapDown(TapDownDetails _) {
    if (widget.onTap == null) return;
    widget.onTap!();
    setState(() => _prs = true);
    _iDly = Timer(const Duration(milliseconds: 400), () => _rTmr = Timer.periodic(const Duration(milliseconds: 80), () {
      if (widget.onTap != null) widget.onTap!();
    } as void Function(Timer timer)));
  }
  
  void _cancel() {
    _iDly?.cancel();
    _rTmr?.cancel();
    if (mounted) setState(() => _prs = false);
  }
  
  @override
  void dispose() {
    _iDly?.cancel();
    _rTmr?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final act = widget.active && widget.onTap != null;
    return GestureDetector(
      onTapDown: act ? _onTapDown : null,
      onTapUp: (_) => _cancel(),
      onTapCancel: _cancel,
      onLongPressCancel: _cancel,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: 22, height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _prs ? AppTheme.accent.withOpacity(0.35) : (act ? AppTheme.accent.withOpacity(0.18) : AppTheme.surfaceRaised),
            border: Border.all(color: act ? AppTheme.accent : AppTheme.border, width: 0.8)),
        child: Icon(widget.icon, size: 13, color: act ? AppTheme.accent : AppTheme.onSurfaceFaint),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  final String label;
  final Color color;
  const _Badge({required this.label, required this.color});
  
  @override
  Widget build(BuildContext context) => Container(
        margin: const EdgeInsets.only(right: 3),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        decoration: BoxDecoration(color: color.withOpacity(0.18), borderRadius: BorderRadius.circular(3)),
        child: Text(label, style: TextStyle(fontSize: 8, fontWeight: FontWeight.w700, color: color, letterSpacing: 0.3)),
      );
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;
  const _Chip({required this.label, required this.color});
  
  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.15), borderRadius: BorderRadius.circular(6), border: Border.all(color: color, width: 0.5)),
        child: Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
      );
}