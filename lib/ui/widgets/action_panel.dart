import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/account_data.dart';
import '../../models/driver_data.dart';
import '../../models/finance_data.dart';
import '../../models/race_data.dart';
import '../../models/setup_suggestion.dart';
import '../../providers/game_provider.dart';
import '../../providers/providers.dart';
import '../../providers/session_provider.dart';
import '../../ui/theme/app_theme.dart';
import '../../models/car_data.dart';
import '../../models/staff_data.dart';
import 'car_research_sheet.dart';
import 'staff_sheet.dart';

/// Full-screen action panel for the currently selected account.
class ActionPanel extends ConsumerWidget {
  final String accountEmail;
  const ActionPanel({super.key, required this.accountEmail});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessionAsync = ref.watch(sessionStateProvider(accountEmail));
    
    return sessionAsync.when(
      skipLoadingOnRefresh: true,
      loading: () => const _LoadingPanel(),
      error:   (e, _) => _ErrorPanel(message: e.toString()),
      data:    (session) {
        if (session.needsReLogin) {
          return _BackgroundReLoginTrigger(accountEmail: accountEmail);
        }
        final data = session.accountData;
        if (data == null) return const _LoadingPanel();
        return _PanelContent(accountEmail: accountEmail, accountData: data);
      },
    );
  }
}

/// A "Ghost" widget that shows a loader and triggers re-login
class _BackgroundReLoginTrigger extends ConsumerStatefulWidget {
  final String accountEmail;
  const _BackgroundReLoginTrigger({required this.accountEmail});

  @override
  ConsumerState<_BackgroundReLoginTrigger> createState() => _BackgroundReLoginTriggerState();
}

class _BackgroundReLoginTriggerState extends ConsumerState<_BackgroundReLoginTrigger> {
  @override
  void initState() {
    super.initState();
    _performAutoLogin();
  }

  @override
  void didUpdateWidget(_BackgroundReLoginTrigger oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.accountEmail != widget.accountEmail) {
      _performAutoLogin();
    }
  }

  Future<void> _performAutoLogin() async {
    try {
      final auth = ref.read(authServiceProvider);
      final sessionNotifier = ref.read(sessionStateProvider(widget.accountEmail).notifier);
      
      final newSession = await auth.reLogin(widget.accountEmail);
      await sessionNotifier.onLoginSuccess(newSession, widget.accountEmail);
    } catch (e) {
      if (mounted) debugPrint('Auto-relogin error: $e');
    }
  }

  @override
  Widget build(BuildContext context) => const _LoadingPanel();
}

class _PanelContent extends ConsumerWidget {
  final String      accountEmail;
  final AccountData accountData;
  const _PanelContent({required this.accountEmail, required this.accountData});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final financeAsync = ref.watch(financeDataProvider(accountEmail));
    final raceAsync    = ref.watch(raceDataProvider(accountEmail));

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 24),
      children: [
        _CompactOverview(
          accountData:  accountData,
          financeAsync: financeAsync,
          accountEmail: accountEmail,
        ),
        const SizedBox(height: 12),
        const _HDivider(),
        const SizedBox(height: 10),
        _SectionLabel('Actions'),
        const SizedBox(height: 6),
        // ── Drivers & Staff quick-view ──────────────────────────
        _DriversStaffButton(
          accountData: accountData,
          onTap:       () => _openStaffSheet(context, accountData),
        ),
        if (accountData.carData != null) ...[
          const SizedBox(height: 8),
          _ActionButton(
            icon:  Icons.science_outlined,
            label: 'Research',
            sub:   _researchSub(accountData.carData!),
            onTap: () => _openResearch(context, accountData.carData!),
          ),
        ],
        if (accountData.carData?.car1Condition != null) ...[
          const SizedBox(height: 10),
          _CarConditionCard(
            carData:      accountData.carData!,
            accountEmail: accountEmail,
            numCars:      accountData.numCars,
          ),
        ],
        const SizedBox(height: 12),
        const _HDivider(),
        const SizedBox(height: 10),
        _SectionLabel('Next race'),
        const SizedBox(height: 6),
        raceAsync.when(
          loading: () => const _RaceCardSkeleton(),
          error:   (_, __) => const _RaceCardError(),
          data:    (race) {
            if (race.raceId.isEmpty) return const _NoRaceCard();
            
            return _InlineRaceCard(
              key:          ValueKey('${accountEmail}_${race.raceId}'),
              race:         race,
              accountEmail: accountEmail,
              accountData:  accountData,
            );
          },
        ),
      ],
    );
  }

  void _openResearch(BuildContext context, CarData carData) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => CarResearchSheet(
        carData:      carData,
        accountEmail: accountEmail,
      ),
    );
  }

  void _openStaffSheet(BuildContext context, AccountData data) {
    showModalBottomSheet(
      context:            context,
      isScrollControlled: true,
      backgroundColor:    AppTheme.surfaceCard,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => StaffSheet(
        accountEmail: accountEmail,
        numCars:      data.numCars,
      ),
    );
  }

  static String _researchSub(CarData carData) {
    final current = carData.currentResearch;
    if (current.isEmpty) return 'Not set';
    if (current.length == 1) {
      return carData.attributeByKey(current.first)?.label ?? current.first;
    }
    return '${current.length} attributes';
  }
}

// ─── Compact overview card ────────────────────────────────────────────────────

class _CompactOverview extends ConsumerWidget {
  final AccountData             accountData;
  final AsyncValue<FinanceData> financeAsync;
  final String                  accountEmail;

  const _CompactOverview({
    required this.accountData,
    required this.financeAsync,
    required this.accountEmail,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color:        AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _MiniStat(label: 'Balance', value: accountData.formattedBalance),
              const _VDivider(),
              _MiniStat(label: 'Tokens',  value: '${accountData.tokens}'),
              const _VDivider(),
              _MiniStat(label: 'Level',   value: 'L${accountData.managerLevel}'),
              const Spacer(),
              _ClaimButton(accountEmail: accountEmail,canClaim: accountData.canClaimDailyReward),
            ],
          ),
          financeAsync.maybeWhen(
            data: (finance) {
              if (finance.sponsors.isEmpty) return const SizedBox.shrink();
              return Column(children: [
                const SizedBox(height: 8),
                const Divider(color: AppTheme.border, thickness: 0.5, height: 0),
                const SizedBox(height: 8),
                Row(
                  children: finance.sponsors.map((s) =>
                    Expanded(child: _SponsorChip(sponsor: s))
                  ).toList(),
                ),
              ]);
            },
            orElse: () => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value;
  const _MiniStat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 10, color: AppTheme.onSurfaceDim)),
      const SizedBox(height: 2),
      Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
    ],
  );
}

class _VDivider extends StatelessWidget {
  const _VDivider();
  @override
  Widget build(BuildContext context) => Container(
    width: 0.5, height: 28,
    margin: const EdgeInsets.symmetric(horizontal: 12),
    color: AppTheme.border,
  );
}

class _ClaimButton extends ConsumerStatefulWidget {
  final String accountEmail;
  final bool   canClaim;
  const _ClaimButton({required this.accountEmail,required this.canClaim});

  @override
  ConsumerState<_ClaimButton> createState() => _ClaimButtonState();
}

class _ClaimButtonState extends ConsumerState<_ClaimButton> {
  bool _loading = false;

  Future<void> _claim() async {
     if (_loading || !widget.canClaim) return;
    setState(() => _loading = true);
    try {
      await ref.read(gameServiceProvider).claimDailyReward(widget.accountEmail);
      ref.read(sessionStateProvider(widget.accountEmail).notifier).refresh();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Daily reward claimed!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed: $e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final claimed = !widget.canClaim;
    return GestureDetector(
      onTap: claimed ? null : _claim,
       child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: claimed
               ? AppTheme.surfaceRaised
               : AppTheme.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
             color: claimed ? AppTheme.border : AppTheme.primary,
             width: 0.5,
           ),
        ),
        child: _loading
          ? const SizedBox(width: 14, height: 14,
              child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primary))
          :  Row(mainAxisSize: MainAxisSize.min, children: [
               Icon(claimed ? Icons.check_circle_outline_rounded : Icons.card_giftcard_rounded,
                 size:  14,
                 color: claimed ? AppTheme.onSurfaceDim : AppTheme.primary,
               ),
               const SizedBox(width: 5),
               Text(
                 claimed ? 'Claimed' : 'Claim',
                 style: TextStyle(
                     fontSize:   12,
                     fontWeight: FontWeight.w600,
                     color: claimed ? AppTheme.onSurfaceDim : AppTheme.primary),
               ),
      ]),
    ));
  }
}

class _SponsorChip extends StatelessWidget {
  final SponsorInfo sponsor;
  const _SponsorChip({required this.sponsor});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(sponsor.label, style: const TextStyle(fontSize: 10, color: AppTheme.onSurfaceDim)),
      const SizedBox(height: 1),
      Text(sponsor.name.isNotEmpty ? sponsor.name : '—',
        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurface),
        maxLines: 1, overflow: TextOverflow.ellipsis),
      if (sponsor.income.isNotEmpty)
        Text(sponsor.income, style: const TextStyle(fontSize: 10, color: AppTheme.success)),
    ],
  );
}

// ─── Inline race card ─────────────────────────────────────────────────────────

class _InlineRaceCard extends StatefulWidget {
  final RaceData    race;
  final String      accountEmail;
  final AccountData accountData;
  const _InlineRaceCard({
    super.key,
    required this.race,
    required this.accountEmail,
    required this.accountData,
  });

  @override
  State<_InlineRaceCard> createState() => _InlineRaceCardState();
}

class _InlineRaceCardState extends State<_InlineRaceCard> {
  late int    _ride, _suspension, _wing;
  late String _practiceTyre;
  late List<_Stint> _stints;
  late int _d1AdvancedFuel; 
  late int _d2AdvancedFuel; 
  int  _pushLevel = 60;
  bool _saving    = false;

  late int    _d2Ride, _d2Suspension, _d2Wing;
  late String _d2PracticeTyre;
  late List<_Stint> _d2Stints;
  int  _d2PushLevel = 60;

  late String _trackCode;
  
  int _getAttr(int index) {
    try {
      return widget.accountData.carData!.attributes[index].currentValue;
    } catch (_) { return 50; }
  }

  double get _d1FuelPerLap => StrategyCalc.getFuelPerLap(_getAttr(4), _trackCode, _pushLevel);
  double get _d2FuelPerLap => StrategyCalc.getFuelPerLap(_getAttr(4), _trackCode, _d2PushLevel);

  @override
  void initState() {
    super.initState();
    final r = widget.race;
    
    _trackCode = r.raceTrackFlag.isNotEmpty ? r.raceTrackFlag : r.raceTrackId;
    
    _ride         = r.d1Ride.clamp(1, 100);
    _suspension   = r.d1Suspension.clamp(1, 100);
    _wing         = r.d1Aerodynamics.clamp(1, 100);
    _practiceTyre = r.d1PracticeTyre.isEmpty ? 'M' : r.d1PracticeTyre;
    _pushLevel    = r.d1PushLevel;
    _d1AdvancedFuel = r.d1AdvancedFuel;
    _d2AdvancedFuel = r.d2AdvancedFuel;

    if (r.d1Stints.isNotEmpty) {
      _stints = r.d1Stints.map((s) => _Stint(
        tyre:       s.tyre,
        laps:       s.laps,
        fuelPerLap: _d1FuelPerLap,
        explicitFuel: r.refuelling ? s.fuel : null,
      )).toList();
    } else {
      final n = (r.d1Pits + 1).clamp(1, 5);
      _stints = List.generate(n, (_) => _Stint(fuelPerLap: _d1FuelPerLap));
    }

    _d2Ride         = r.d2Ride.clamp(1, 100);
    _d2Suspension   = r.d2Suspension.clamp(1, 100);
    _d2Wing         = r.d2Aerodynamics.clamp(1, 100);
    _d2PracticeTyre = r.d2PracticeTyre.isEmpty ? 'M' : r.d2PracticeTyre;
    _d2PushLevel    = r.d2PushLevel;

    if (r.d2Stints.isNotEmpty) {
      _d2Stints = r.d2Stints.map((s) => _Stint(
        tyre:       s.tyre,
        laps:       s.laps,
        fuelPerLap: _d2FuelPerLap,
        explicitFuel: r.refuelling ? s.fuel : null,
      )).toList();
    } else {
      final n2 = (r.d2Pits + 1).clamp(1, 5);
      _d2Stints = List.generate(n2, (_) => _Stint(fuelPerLap: _d2FuelPerLap));
    }
  }

  int  get _totalLaps => _stints.fold(0, (s, st) => s + st.laps);
  bool get _lapsOk    => _totalLaps >= widget.race.raceLaps;

  Future<void> _showSuggestSetup(BuildContext context, WidgetRef ref) async {
    final drivers = ref.read(driversProvider(widget.accountEmail));
    final circuits = await ref.read(circuitsProvider(widget.accountEmail).future);

    if (!context.mounted) return;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.surfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => SetupSuggestSheet(
        trackCode: _trackCode,
        drivers: drivers,
        circuits: circuits,
        accountEmail: widget.accountEmail,
        numCars: widget.accountData.numCars,
        currentRide1: _ride, currentSusp1: _suspension, currentWing1: _wing,
        currentRide2: _d2Ride, currentSusp2: _d2Suspension, currentWing2: _d2Wing,
        onApply: (r1, s1, w1, r2, s2, w2) => setState(() {
          _ride = r1; _suspension = s1; _wing = w1;
          if (r2 != null && s2 != null && w2 != null) {
            _d2Ride = r2; _d2Suspension = s2; _d2Wing = w2;
          }
        }),
      ),
    );
  }

  void _applyOptimalStrategy(int carNum) {
    setState(() {
      final newStints = StrategyCalc.getOptimalStrategy(
        raceLaps: widget.race.raceLaps,
        fuelPerLap: carNum == 1 ? _d1FuelPerLap : _d2FuelPerLap,
        teAttr: _getAttr(7),
        trackCode: _trackCode,
        refuelling: widget.race.refuelling,
      );
      if (carNum == 1) {
        _stints = newStints;
        _d1AdvancedFuel = (widget.race.raceLaps * _d1FuelPerLap).ceil();
      } else {
        _d2Stints = newStints;
        _d2AdvancedFuel = (widget.race.raceLaps * _d2FuelPerLap).ceil();
      }
    });
  }

  Future<void> _save(BuildContext context, WidgetRef ref) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(raceServiceProvider).saveAll(
        accountEmail:   widget.accountEmail,
        raceId:         widget.race.raceId,
        twoCars:        widget.accountData.numCars >= 2,
        refuelling:     widget.race.refuelling,
        d1Ride:         _ride,
        d1Suspension:   _suspension,
        d1Wing:         _wing,
        d1PracticeTyre: _practiceTyre,
        d1Stints:       _stints.map((s) => s.toMap()).toList(),
        d1NumPits:      _stints.length - 1,
        d1PushLevel:    _pushLevel,
        d1AdvancedFuel: _d1AdvancedFuel,
        d1Saved:        true,
        d2Ride:         _d2Ride,
        d2Suspension:   _d2Suspension,
        d2Wing:         _d2Wing,
        d2PracticeTyre: _d2PracticeTyre,
        d2Stints:       _d2Stints.map((s) => s.toMap()).toList(),
        d2NumPits:      _d2Stints.length - 1,
        d2PushLevel:    _d2PushLevel,
        d2AdvancedFuel: _d2AdvancedFuel,
      );
      ref.invalidate(raceDataProvider(widget.accountEmail));
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved!')));
    } catch (e) {
      if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Save failed: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    int teAttr = _getAttr(5);

    return Consumer(builder: (ctx, ref, _) => Container(
      decoration: BoxDecoration(
        color:        AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                widget.race.raceName.isNotEmpty
                  ? 'R${widget.race.raceRoundNum} — ${widget.race.raceName}'
                  : 'Round ${widget.race.raceRoundNum}',
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
              Text(
                widget.race.raceIsLive ? 'Race is live' : 'Starts in ${widget.race.countdownLabel}',
                style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceDim)),
            ])),
            GestureDetector(
              onTap: () => _save(ctx, ref),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: AppTheme.primary, borderRadius: BorderRadius.circular(8)),
                child: _saving
                  ? const SizedBox(width: 14, height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white)),
              ),
            ),
          ]),
        ),
        const SizedBox(height: 10),
        const Divider(color: AppTheme.border, thickness: 0.5, height: 0),
        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Expanded(
                child: Text('SETUP', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w500,
                    color: AppTheme.onSurfaceDim, letterSpacing: 0.5))),
              _SuggestBtn(onTap: () => _showSuggestSetup(ctx, ref)),
            ]),
            const SizedBox(height: 8),
            _SetupSlider(label: 'Ride',  value: _ride,       onChanged: (v) => setState(() => _ride = v)),
            const SizedBox(height: 5),
            _SetupSlider(label: 'Susp.', value: _suspension, onChanged: (v) => setState(() => _suspension = v)),
            const SizedBox(height: 5),
            _SetupSlider(label: 'Wing',  value: _wing,       onChanged: (v) => setState(() => _wing = v)),
          ]),
        ),
        const SizedBox(height: 10),
        const Divider(color: AppTheme.border, thickness: 0.5, height: 0),
        const SizedBox(height: 10),

        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              const Text('STRATEGY', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w500,
                color: AppTheme.onSurfaceDim, letterSpacing: 0.5)),
              const SizedBox(width: 8),
              _SuggestBtn(onTap: () => _applyOptimalStrategy(1)),
              const Spacer(),
              if (_stints.length > 1)
                _StintHeaderBtn(
                  icon:  Icons.remove,
                  onTap: () => setState(() => _stints.removeLast()),
                ),
              if (_stints.length > 1 && _stints.length < 5)
                const SizedBox(width: 4),
              if (_stints.length < 5)
                _StintHeaderBtn(
                  icon:  Icons.add,
                  onTap: () => setState(() => _stints.add(
                      _Stint(fuelPerLap: _d1FuelPerLap))),
                ),
              const Spacer(),
              Text('$_totalLaps / ${widget.race.raceLaps}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: _lapsOk ? AppTheme.onSurfaceDim : AppTheme.error)),
            ]),
            const SizedBox(height: 4),
            Text('~${_d1FuelPerLap.toStringAsFixed(2)}L/lap',
              style: const TextStyle(fontSize: 10, color: AppTheme.onSurfaceDim)),
            const SizedBox(height: 8),

            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ReorderableRow(
                stints:    _stints,
                fuelPerLap: _d1FuelPerLap,
                teAttr:     teAttr,
                trackCode:  _trackCode,
                refuelling: widget.race.refuelling,
                raceLaps:  widget.race.raceLaps,
                onReorder: (o, n) => setState(() {
                  final s = _stints.removeAt(o);
                  _stints.insert(n, s);
                }),
                onChanged: (i, s) => setState(() => _stints[i] = s),
              ),
            ),
            const SizedBox(height: 10),

            if (!widget.race.refuelling) ...[
              _FuelSlider(
                label: 'Total Fuel',
                value: _d1AdvancedFuel,
                fuelPerLap: _d1FuelPerLap,
                onChanged: (v) => setState(() => _d1AdvancedFuel = v),
              ),
              const SizedBox(height: 10),
            ],

            Row(children: [
              const Text('Push:', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceDim)),
              const SizedBox(width: 8),
              ...{20: 'V.Low', 40: 'Low', 60: 'Mid', 80: 'High', 100: 'V.High'}.entries.map((e) {
                final sel = _pushLevel == e.key;
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _pushLevel = e.key;
                      final newFuel = _d1FuelPerLap;
                      for (var s in _stints) { s.fuelPerLap = newFuel; }
                    });
                  },
                  child: Container(
                    margin: const EdgeInsets.only(right: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color:        sel ? AppTheme.primary : AppTheme.surfaceRaised,
                      borderRadius: BorderRadius.circular(6),
                      border:       Border.all(color: sel ? AppTheme.primary : AppTheme.border, width: 0.5)),
                    child: Text(e.value, style: TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w500,
                      color: sel ? Colors.white : AppTheme.onSurfaceDim)),
                  ),
                );
              }),
            ]),

            if (widget.accountData.numCars >= 2) ...[
              const SizedBox(height: 14),
              const Divider(color: AppTheme.border, thickness: 0.5, height: 0),
              const SizedBox(height: 10),
              const Text('CAR 2 — SETUP', style: TextStyle(fontSize: 10,
                fontWeight: FontWeight.w500, color: AppTheme.onSurfaceDim, letterSpacing: 0.5)),
              const SizedBox(height: 8),
              _SetupSlider(label: 'Ride',  value: _d2Ride,       onChanged: (v) => setState(() => _d2Ride = v)),
              const SizedBox(height: 5),
              _SetupSlider(label: 'Susp.', value: _d2Suspension, onChanged: (v) => setState(() => _d2Suspension = v)),
              const SizedBox(height: 5),
              _SetupSlider(label: 'Wing',  value: _d2Wing,       onChanged: (v) => setState(() => _d2Wing = v)),
              const SizedBox(height: 10),
              Row(children: [
                const Text('CAR 2 — STRATEGY',
                  style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500,
                    color: AppTheme.onSurfaceDim, letterSpacing: 0.5)),
                const SizedBox(width: 8),
                _SuggestBtn(onTap: () => _applyOptimalStrategy(2)),
                const Spacer(),
                if (_d2Stints.length > 1)
                  _StintHeaderBtn(
                    icon:  Icons.remove,
                    onTap: () => setState(() => _d2Stints.removeLast()),
                  ),
                if (_d2Stints.length > 1 && _d2Stints.length < 5)
                  const SizedBox(width: 4),
                if (_d2Stints.length < 5)
                  _StintHeaderBtn(
                    icon:  Icons.add,
                    onTap: () => setState(() => _d2Stints.add(
                        _Stint(fuelPerLap: _d2FuelPerLap))),
                  ),
                const Spacer(),
                Text('${_d2Stints.fold(0, (s, st) => s + st.laps)} / ${widget.race.raceLaps}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: _d2Stints.fold(0, (s, st) => s + st.laps) >= widget.race.raceLaps
                        ? AppTheme.onSurfaceDim : AppTheme.error)),
              ]),
              const SizedBox(height: 4),
              Text('~${_d2FuelPerLap.toStringAsFixed(2)}L/lap',
                style: const TextStyle(fontSize: 10, color: AppTheme.onSurfaceDim)),
              const SizedBox(height: 8),

              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ReorderableRow(
                  stints:     _d2Stints,
                  fuelPerLap: _d2FuelPerLap,
                  teAttr:     teAttr,
                  trackCode:  _trackCode,
                  refuelling: widget.race.refuelling, 
                  raceLaps:   widget.race.raceLaps,
                  onReorder: (o, n) => setState(() {
                    final s = _d2Stints.removeAt(o);
                    _d2Stints.insert(n, s);
                  }),
                  onChanged: (i, s) => setState(() => _d2Stints[i] = s),
                ),
              ),
              const SizedBox(height: 10),
               if (!widget.race.refuelling) ...[
                 _FuelSlider(
                   label: 'Total Fuel',
                   value: _d2AdvancedFuel,
                   fuelPerLap: _d2FuelPerLap,
                   onChanged: (v) => setState(() => _d2AdvancedFuel = v),
                 ),
                 const SizedBox(height: 10),
               ],
              Row(children: [
                const Text('Push:', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceDim)),
                const SizedBox(width: 8),
                ...{20: 'V.Low', 40: 'Low', 60: 'Mid', 80: 'High', 100: 'V.High'}.entries.map((e) {
                  final sel = _d2PushLevel == e.key;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _d2PushLevel = e.key;
                        final newFuel = _d2FuelPerLap;
                        for (var s in _d2Stints) { s.fuelPerLap = newFuel; }
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.only(right: 5),
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                      decoration: BoxDecoration(
                        color:        sel ? AppTheme.primary : AppTheme.surfaceRaised,
                        borderRadius: BorderRadius.circular(6),
                        border:       Border.all(color: sel ? AppTheme.primary : AppTheme.border, width: 0.5)),
                      child: Text(e.value, style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w500,
                        color: sel ? Colors.white : AppTheme.onSurfaceDim)),
                    ),
                  );
                }),
              ]),
            ],
          ]),
        ),
        const SizedBox(height: 14),
      ]),
    ));
  }
}

class _SuggestBtn extends StatelessWidget {
  final VoidCallback onTap;
  const _SuggestBtn({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color:        AppTheme.primary.withOpacity(0.15),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: AppTheme.primary, width: 0.5),
        ),
        child: const Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(Icons.auto_fix_high_rounded, size: 12, color: AppTheme.primary),
          SizedBox(width: 4),
          Text('Suggest', style: TextStyle(
              fontSize: 10, fontWeight: FontWeight.w600,
              color: AppTheme.primary)),
        ]),
      ),
    );
  }
}

class _StintHeaderBtn extends StatelessWidget {
  final IconData     icon;
  final VoidCallback onTap;

  const _StintHeaderBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width:  22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:        AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: AppTheme.borderBright, width: 0.5),
        ),
        child: Icon(icon, size: 14, color: AppTheme.onSurface),
      ),
    );
  }
}

class ReorderableRow extends StatefulWidget {
  final List<_Stint>                stints;
  final double                      fuelPerLap;
  final int                         teAttr;
  final String                      trackCode;
  final int                         raceLaps;
  final bool                        refuelling;   
  final void Function(int, int)     onReorder;   
  final void Function(int, _Stint)  onChanged;

  const ReorderableRow({
    super.key,
    required this.stints,
    required this.fuelPerLap,
    required this.teAttr,
    required this.trackCode,
    required this.raceLaps,
    required this.refuelling, 
    required this.onReorder,
    required this.onChanged,
  });

  @override
  State<ReorderableRow> createState() => _ReorderableRowState();
}

class _ReorderableRowState extends State<ReorderableRow> {
  int? _draggingIndex;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: widget.stints.asMap().entries.map((entry) {
        final i     = entry.key;
        final stint = entry.value;
        final isDragging = _draggingIndex == i;

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: DragTarget<int>(
            onWillAcceptWithDetails: (details) => details.data != i,
            onAcceptWithDetails: (details) {
              widget.onReorder(details.data, i);
              setState(() => _draggingIndex = null);
            },
            builder: (context, candidateData, rejectedData) {
              final isHovered = candidateData.isNotEmpty;
              return LongPressDraggable<int>(
                data:      i,
                onDragStarted: () => setState(() => _draggingIndex = i),
                onDragEnd:     (_) => setState(() => _draggingIndex = null),
                onDraggableCanceled: (_, __) => setState(() => _draggingIndex = null),
                feedback: Material(
                  color: Colors.transparent,
                  child: Opacity(
                    opacity: 0.85,
                    child: _StintCard(
                      index:      i,
                      stint:      stint,
                      raceLaps:   widget.raceLaps,
                      refuelling: widget.refuelling,
                      fuelPerLap: widget.fuelPerLap,
                      teAttr:     widget.teAttr,
                      trackCode:  widget.trackCode,
                      onChanged:  (_) {},
                    ),
                  ),
                ),
                childWhenDragging: Opacity(
                  opacity: 0.3,
                  child: _StintCard(
                    index:      i,
                    stint:      stint,
                    raceLaps:   widget.raceLaps,
                    fuelPerLap: widget.fuelPerLap,
                    refuelling: widget.refuelling,
                    teAttr:     widget.teAttr,
                    trackCode:  widget.trackCode,
                    onChanged:  (_) {},
                  ),
                ),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    border: isHovered
                        ? Border.all(color: AppTheme.primary, width: 2)
                        : null,
                  ),
                  child: _StintCard(
                    index:      i,
                    stint:      stint,
                    raceLaps:   widget.raceLaps,
                    fuelPerLap: widget.fuelPerLap,
                    refuelling: widget.refuelling,
                    teAttr:     widget.teAttr,
                    trackCode:  widget.trackCode,
                    onChanged:  (s) => widget.onChanged(i, s),
                  ),
                ),
              );
            },
          ),
        );
      }).toList(),
    );
  }
}

class _Stint {
  String tyre;
  int laps;
  double fuelPerLap;
  int fuel; 

  _Stint({
    this.tyre = 'M', 
    this.laps = 7, 
    this.fuelPerLap = 0.0, 
    int? explicitFuel
  }) : fuel = explicitFuel ?? (laps * fuelPerLap).ceil().clamp(1, 300);

  Map<String, dynamic> toMap() => {
    'tyre': tyre,
    'laps': laps,
    'fuel': fuel,
    'fuelPerLap': fuelPerLap,
  };
}

class _StintCard extends StatelessWidget {
  final int        index;
  final _Stint     stint;
  final int        raceLaps;
  final double     fuelPerLap;
  final int        teAttr;
  final String     trackCode;
  final bool       refuelling;
  final ValueChanged<_Stint>  onChanged;

  const _StintCard({
    required this.index, required this.stint, required this.raceLaps,required this.refuelling, 
    required this.fuelPerLap, required this.teAttr, required this.trackCode, required this.onChanged,
  });

  static const _colors = {
    'SS': Color(0xFFD65E56),
    'S':  Color(0xFFD9C777),
    'M':  Color(0xFFD9D9D9),
    'H':  Color(0xFFD99A57),
    'I':  Color(0xFF82A674),
    'W':  Color(0xFF4786B3),
  };

  String get _label => index == 0 ? 'Start' : 'Pit $index';

  @override
  Widget build(BuildContext context) {
    final c = _colors[stint.tyre] ?? AppTheme.onSurfaceDim;
    final fuelVal = refuelling ? stint.fuel.toString() : (stint.laps * fuelPerLap).toStringAsFixed(1);
        
    final wearLeft = StrategyCalc.getTyreWearPercentage(
      teAttr: teAttr,
      trackCode: trackCode,
      tyre: stint.tyre,
      laps: stint.laps,
      raceLaps: raceLaps,
    );

    return GestureDetector(
      onTap: () => showModalBottomSheet(
        context: context,
        builder: (_) => _StintEditor(
          label: _label, 
          stint: stint, 
          raceLaps: raceLaps,
          fuelPerLap: fuelPerLap, 
          refuelling: refuelling,
          teAttr: teAttr,
          trackCode: trackCode,
          onSave: onChanged, 
        ),
      ),
      child: Container(
        width:  52,
        height: 80,
        decoration: BoxDecoration(
          color:        AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_label,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onSurfaceDim)),
            const SizedBox(height: 3),
            
            SizedBox(
              width:  34,
              height: 34,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform.scale(
                    scaleX: -1,
                    child: CircularProgressIndicator(
                      value: wearLeft / 100,
                      strokeWidth: 4.5,
                      color: c,
                      backgroundColor: c.withOpacity(0.15),
                    ),
                  ),
                  Text(
                    '${stint.laps}',
                    style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.pillTextSel),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 2),
            Text('${wearLeft.round()}%',
                style: TextStyle(fontSize: 7, fontWeight: FontWeight.bold, color: c)),
            const SizedBox(height: 2),
            Text('${fuelVal}L',
                style: const TextStyle(
                    fontSize: 9, color: AppTheme.onSurfaceDim)),
          ],
        ),
      ),
    );
  }
}

class _StintEditor extends StatefulWidget {
  final String label;
  final _Stint stint;
  final int raceLaps;
  final double fuelPerLap;
  final bool refuelling;
  final int teAttr;
  final String trackCode;
  final ValueChanged<_Stint> onSave;
  final VoidCallback? onDelete;

  const _StintEditor({
    required this.label,
    required this.stint,
    required this.raceLaps,
    required this.fuelPerLap,
    required this.refuelling,
    required this.teAttr,
    required this.trackCode,
    required this.onSave,
    this.onDelete,
  });

  @override
  State<_StintEditor> createState() => _StintEditorState();
}

class _StintEditorState extends State<_StintEditor> {
  late String _tyre;
  late int    _laps;
  late int    _fuel;

  static const _colors = {
    'SS': Color(0xFFD65E56),
    'S':  Color(0xFFD9C777),
    'M':  Color(0xFFD9D9D9),
    'H':  Color(0xFFD99A57),
    'I':  Color(0xFF82A674),
    'W':  Color(0xFF4786B3),
  };
  static const _tyres  = ['SS', 'S', 'M', 'H', 'I', 'W'];

  @override
  void initState() {
    super.initState();
    _tyre = widget.stint.tyre;
    _laps = widget.stint.laps;
    _fuel = widget.stint.fuel; 
  }

  void _updateFuel(int newFuel) {
    setState(() {
      _fuel = newFuel.clamp(1, 150);
      _laps = (_fuel / widget.fuelPerLap).floor().clamp(1, widget.raceLaps);
    });
  }

  void _updateLaps(int newLaps) {
    setState(() {
      _laps = newLaps.clamp(1, widget.raceLaps);
      _fuel = (_laps * widget.fuelPerLap).ceil();
    });
  }

  @override
  Widget build(BuildContext context) {
    final wearLeft = StrategyCalc.getTyreWearPercentage(
      teAttr: widget.teAttr,
      trackCode: widget.trackCode,
      tyre: _tyre,
      laps: _laps,
      raceLaps: widget.raceLaps,
    );
    final tyreColor = _colors[_tyre] ?? AppTheme.onSurfaceDim;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 36, height: 4,
          decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        
        Row(children: [
          Text(widget.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
          const Spacer(),
          if (widget.onDelete != null)
            GestureDetector(
              onTap: () { Navigator.pop(context); widget.onDelete!(); },
              child: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error)),
        ]),
        const SizedBox(height: 16),
        
        const Align(alignment: Alignment.centerLeft,
          child: Text('Tyre', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceDim))),
        const SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: _tyres.map((t) {
            final c = _colors[t] ?? AppTheme.onSurfaceDim;
            final sel = _tyre == t;

            return SizedBox(
              width: 44,
              height: 44,
              child: GestureDetector(
                onTap: () => setState(() => _tyre = t),
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 110),
                    width: sel ? 44 : 36,
                    height: sel ? 44 : 36,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppTheme.surface,
                      border: Border.all(
                        color: sel ? c : c.withValues(alpha: 0.2),
                        width: 7.5,
                      ),
                    ),
                    child: Text(
                      t,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w800,
                        color: sel ? AppTheme.pillTextSel : c,
                      ),
                    ),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 20),
        
        Row(children: [
          Expanded(
            child: Text(
              widget.refuelling ? 'Fuel (Liters)' : 'Laps', 
              style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceDim)
            )
          ),
          _Btn(
            icon: Icons.remove, 
            onTap: widget.refuelling 
              ? (_fuel > 1 ? () => _updateFuel(_fuel - 1) : null)
              : (_laps > 1 ? () => _updateLaps(_laps - 1) : null)
          ),
          const SizedBox(width: 16),
          SizedBox(
            width: 60, 
            child: Text(
              widget.refuelling ? '$_fuel' : '$_laps', 
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: AppTheme.onSurface)
            )
          ),
          const SizedBox(width: 16),
          _Btn(
            icon: Icons.add, 
            onTap: widget.refuelling 
              ? (_fuel < 150 ? () => _updateFuel(_fuel + 1) : null)
              : (_laps < widget.raceLaps ? () => _updateLaps(_laps + 1) : null)
          ),
        ]),
        const SizedBox(height: 12),
        
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(8)
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                widget.refuelling 
                  ? 'Range: ${(_fuel / widget.fuelPerLap).toStringAsFixed(1)} Laps' 
                  : 'Required: ~${(_laps * widget.fuelPerLap).toStringAsFixed(1)}L',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
              ),
              Row(
                children: [
                  const Text('Wear: ', style: TextStyle(fontSize: 12, color: AppTheme.onSurfaceDim)),
                  Text('${wearLeft.round()}%', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: tyreColor)),
                ]
              )
            ],
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () {
            widget.onSave(_Stint(
              tyre: _tyre,
              laps: _laps,
              fuelPerLap: widget.fuelPerLap,
              explicitFuel: _fuel,
            ));
            Navigator.pop(context);
          },
          child: const Text('Confirm Stint'))),
      ]),
    );
  }
}

class _Btn extends StatelessWidget {
  final IconData icon; final VoidCallback? onTap;
  const _Btn({required this.icon, this.onTap});

  @override
  Widget build(BuildContext context) {
    final active = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32, height: 32, alignment: Alignment.center,
        decoration: BoxDecoration(shape: BoxShape.circle,
          color: active ? AppTheme.surfaceRaised : AppTheme.onSurfaceFaint.withOpacity(0.2),
          border: Border.all(color: active ? AppTheme.borderBright : AppTheme.border, width: 0.5)),
        child: Icon(icon, size: 16, color: active ? AppTheme.onSurface : AppTheme.onSurfaceFaint)));
  }
}

class _SetupSlider extends StatelessWidget {
  final String label; final int value; final ValueChanged<int> onChanged;
  const _SetupSlider({required this.label, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) => Row(children: [
    SizedBox(width: 46, child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceDim))),
    Expanded(child: SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor:   AppTheme.primary,
        inactiveTrackColor: AppTheme.border,
        thumbColor:         AppTheme.primary,
        thumbShape:         const RoundSliderThumbShape(enabledThumbRadius: 7),
        trackHeight:        3,
        overlayShape:       SliderComponentShape.noOverlay,
      ),
      child: Slider(
        value:     value.clamp(1, 100).toDouble(),
        min:       1,
        max:       100,
        onChanged: (v) => onChanged(v.round()),
      ),
    )),
    SizedBox(width: 28, child: Text('$value', textAlign: TextAlign.right,
      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurface))),
  ]);
}

class _FuelSlider extends StatelessWidget {
  final String label;
  final int value;
  final double fuelPerLap;
  final ValueChanged<int> onChanged;

  const _FuelSlider({required this.label, required this.value, required this.fuelPerLap, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceDim))),
      
      _MiniCircleBtn(icon: Icons.remove, onTap: () => onChanged((value - 1).clamp(0, 200))),
      
      Expanded(
        child: SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.primary,
            inactiveTrackColor: AppTheme.border,
            thumbColor: AppTheme.primary,
            trackHeight: 2,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
            overlayShape: SliderComponentShape.noOverlay,
          ),
          child: Slider(
            value: value.toDouble(),
            min: 0, max: 200,
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ),
      
      _MiniCircleBtn(icon: Icons.add, onTap: () => onChanged((value + 1).clamp(0, 200))),
      
      const SizedBox(width: 12),
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$value L', textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary)),
          if (fuelPerLap > 0)
            Text('~${(value / fuelPerLap).toStringAsFixed(1)} laps', textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 9, color: AppTheme.onSurfaceDim)),
        ],
      ),
    ]);
  }
}

class _MiniCircleBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _MiniCircleBtn({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(shape: BoxShape.circle, color: AppTheme.surfaceRaised),
        child: Icon(icon, size: 14, color: AppTheme.onSurfaceDim),
      ),
    );
  }
}

// ─── Car Condition Card ───────────────────────────────────────────────────────

class _CarConditionCard extends ConsumerStatefulWidget {
  final CarData carData;
  final String  accountEmail;
  final int     numCars;

  const _CarConditionCard({
    required this.carData,
    required this.accountEmail,
    required this.numCars,
  });

  @override
  ConsumerState<_CarConditionCard> createState() => _CarConditionCardState();
}

class _CarConditionCardState extends ConsumerState<_CarConditionCard> {
  final Set<String> _loading = {};
  bool _collectingManufacturing = false;

  bool _isLoading(int carNum, String type) =>
      _loading.contains('c$carNum-$type');

  /// Collect manufactured parts + engines from the HQ manufacturing facility.
  Future<void> _collectManufacturing() async {
    final mc = widget.carData.manufacturingCollect;
    if (mc == null || _collectingManufacturing) return;
    setState(() => _collectingManufacturing = true);
    try {
      await ref.read(gameServiceProvider).collectHqFacility(
        widget.accountEmail,
        collectUrl: mc.collectUrl,
      );
      await ref
          .read(sessionStateProvider(widget.accountEmail).notifier)
          .refresh();
      if (mounted) {
        final parts   = mc.parts > 0   ? '${mc.parts} parts'   : '';
        final engines = mc.engines > 0 ? '${mc.engines} engines' : '';
        final msg = [parts, engines].where((s) => s.isNotEmpty).join(' + ');
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Collected $msg!')));
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Collect failed: $e')));
    } finally {
      if (mounted) setState(() => _collectingManufacturing = false);
    }
  }

  Future<void> _repair(CarCondition cond, String type) async {
    final key = 'c${cond.carNumber}-$type';
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
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Repair failed: $e')));
    } finally {
      if (mounted) setState(() => _loading.remove(key));
    }
  }

  @override
  Widget build(BuildContext context) {
    final c1 = widget.carData.car1Condition;
    final c2 = widget.numCars >= 2 ? widget.carData.car2Condition : null;
    if (c1 == null) return const SizedBox.shrink();

    final cd = widget.carData;

    return Container(
      padding:    const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color:        AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: label · inventory counts · collect button ──────────
          Row(children: [
            const Text(
              'CAR CONDITION',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceDim, letterSpacing: 0.5),
            ),
            const Spacer(),
            // Turbo parts count
            if (cd.totalParts > 0) ...[
              const Icon(Icons.build_outlined, size: 10, color: AppTheme.onSurfaceDim),
              const SizedBox(width: 3),
              Text('${cd.totalParts}',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceDim)),
              const SizedBox(width: 8),
            ],
            // Engine count
            if (cd.totalEngines > 0) ...[
              const Icon(Icons.offline_bolt_outlined, size: 10, color: AppTheme.onSurfaceDim),
              const SizedBox(width: 3),
              Text('${cd.totalEngines}',
                  style: const TextStyle(
                      fontSize: 10, fontWeight: FontWeight.w600,
                      color: AppTheme.onSurfaceDim)),
              const SizedBox(width: 8),
            ],
            // Collect manufacturing button
            if (cd.manufacturingCollect != null)
              _CollectMfgButton(
                collectable: cd.manufacturingCollect!,
                loading:     _collectingManufacturing,
                onTap:       _collectManufacturing,
              ),
          ]),
          // ── Restock info ───────────────────────────────────────────────
          if (cd.restockRaces > 0) ...[
            const SizedBox(height: 4),
            Row(children: [
              const Icon(Icons.sync, size: 10, color: AppTheme.onSurfaceDim),
              const SizedBox(width: 3),
              Text(
                'Engine restock in ${cd.restockRaces} '
                'race${cd.restockRaces == 1 ? '' : 's'}',
                style: const TextStyle(fontSize: 9, color: AppTheme.onSurfaceDim),
              ),
            ]),
          ],
          const SizedBox(height: 10),
          _CarRow(
            cond:          c1,
            partsLoading:  _isLoading(1, 'parts'),
            engineLoading: _isLoading(1, 'engine'),
            onRepairParts:  c1.partsLocked ? null : () => _repair(c1, 'parts'),
            onRepairEngine: c1.engineLocked ? null : () => _repair(c1, 'engine'),
          ),
          if (c2 != null) ...[
            const SizedBox(height: 8),
            const Divider(color: AppTheme.border, thickness: 0.5, height: 0),
            const SizedBox(height: 8),
            _CarRow(
              cond:          c2,
              partsLoading:  _isLoading(2, 'parts'),
              engineLoading: _isLoading(2, 'engine'),
              onRepairParts:  c2.partsLocked ? null : () => _repair(c2, 'parts'),
              onRepairEngine: c2.engineLocked ? null : () => _repair(c2, 'engine'),
            ),
          ],
        ],
      ),
    );
  }
}

// ─── Collect manufacturing button ─────────────────────────────────────────────

/// Compact amber chip shown next to CAR CONDITION when the HQ manufacturing
/// facility has parts and/or engines ready to collect.
class _CollectMfgButton extends StatelessWidget {
  final HqCollectable  collectable;
  final bool           loading;
  final VoidCallback   onTap;

  const _CollectMfgButton({
    required this.collectable,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: loading ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:        AppTheme.accent.withOpacity(0.14),
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(color: AppTheme.accent, width: 0.8),
        ),
        child: loading
            ? const SizedBox(
                width: 11, height: 11,
                child: CircularProgressIndicator(
                    strokeWidth: 1.6, color: AppTheme.accent))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                if (collectable.parts > 0) ...[
                  const Icon(Icons.build_outlined,
                      size: 10, color: AppTheme.accent),
                  const SizedBox(width: 3),
                  Text('${collectable.parts}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent)),
                  if (collectable.engines > 0) const SizedBox(width: 6),
                ],
                if (collectable.engines > 0) ...[
                  const Icon(Icons.offline_bolt_outlined,
                      size: 10, color: AppTheme.accent),
                  const SizedBox(width: 3),
                  Text('${collectable.engines}',
                      style: const TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.accent)),
                ],
              ]),
      ),
    );
  }
}

class _CarRow extends StatelessWidget {
  final CarCondition  cond;
  final bool          partsLoading;
  final bool          engineLoading;
  final VoidCallback? onRepairParts;
  final VoidCallback? onRepairEngine;

  const _CarRow({
    required this.cond,
    required this.partsLoading,
    required this.engineLoading,
    this.onRepairParts,
    this.onRepairEngine,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('CAR ${cond.carNumber}',
            style: const TextStyle(
                fontSize: 9, fontWeight: FontWeight.w600,
                color: AppTheme.onSurfaceDim, letterSpacing: 0.4)),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: _ConditionItem(
              label:   'Parts',
              value:   cond.partsValue,
              cost:    cond.partsCost,
              locked:  cond.partsLocked,
              loading: partsLoading,
              onTap:   onRepairParts,
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: _ConditionItem(
              label:   'Engine',
              value:   cond.engineValue,
              cost:    cond.engineCost,
              locked:  cond.engineLocked,
              loading: engineLoading,
              onTap:   onRepairEngine,
            ),
          ),
        ]),
      ],
    );
  }
}

class _ConditionItem extends StatelessWidget {
  final String        label;
  final int           value;
  final int           cost;
  final bool          locked;
  final bool          loading;
  final VoidCallback? onTap;

  const _ConditionItem({
    required this.label,
    required this.value,
    required this.cost,
    required this.locked,
    required this.loading,
    this.onTap,
  });

  Color get _color {
    if (value >= 100) return AppTheme.success;
    if (value >= 80) return const Color.fromARGB(255, 232, 232, 32);
    if (value >= 50) return const Color(0xFFE8A020);
    return AppTheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final needsRepair = value < 100;
    final canRepair   = needsRepair && !locked && onTap != null;

    return Row(children: [
      SizedBox(
        width: 32, height: 32,
        child: Stack(alignment: Alignment.center, children: [
          CircularProgressIndicator(
            value:           value / 100,
            strokeWidth:     2.5,
            backgroundColor: AppTheme.border,
            valueColor:      AlwaysStoppedAnimation<Color>(_color),
          ),
          Text('$value',
              style: TextStyle(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: _color)),
        ]),
      ),
      const SizedBox(width: 6),
      Expanded(
        child: Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500,
                color: AppTheme.onSurface)),
      ),
      if (needsRepair)
        _InlineRepairBtn(
          cost:    cost,
          loading: loading,
          active:  canRepair,
          onTap:   canRepair ? onTap : null,
        )
      else
        const Icon(Icons.check_circle_outline_rounded,
            size: 14, color: AppTheme.success),
    ]);
  }
}

class _InlineRepairBtn extends StatelessWidget {
  final int           cost;
  final bool          loading;
  final bool          active;
  final VoidCallback? onTap;

  const _InlineRepairBtn({
    required this.cost,
    required this.loading,
    required this.active,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color:        active
              ? AppTheme.primary.withOpacity(0.12)
              : AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(6),
          border:       Border.all(
            color: active ? AppTheme.primary : AppTheme.border,
            width: 0.5,
          ),
        ),
        child: loading
            ? const SizedBox(
                width: 12, height: 12,
                child: CircularProgressIndicator(
                    strokeWidth: 1.5, color: AppTheme.primary))
            : Row(mainAxisSize: MainAxisSize.min, children: [
                Text('$cost',
                    style: TextStyle(
                        fontSize: 11, fontWeight: FontWeight.w600,
                        color: active
                            ? AppTheme.primary
                            : AppTheme.onSurfaceDim)),
                const SizedBox(width: 2),
                Icon(Icons.bolt, size: 10,
                    color: active
                        ? AppTheme.primary
                        : AppTheme.onSurfaceDim),
              ]),
      ),
    );
  }
}


// ─── Drivers & Staff Button ───────────────────────────────────────────────────

/// Full-width button giving a quick contract health glance for all drivers
/// and staff.  Tapping opens [StaffSheet] for full management.
class _DriversStaffButton extends StatelessWidget {
  final AccountData  accountData;
  final VoidCallback onTap;

  const _DriversStaffButton({
    required this.accountData,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final drivers = accountData.drivers
        .take(accountData.numCars.clamp(0, accountData.drivers.length))
        .toList();
    final staffData = accountData.staffData;
    final expiringTotal = accountData.expiringContractCount;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 10, 10),
        decoration: BoxDecoration(
          color:        AppTheme.surfaceCard,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: expiringTotal > 0
                ? AppTheme.error.withOpacity(0.4)
                : AppTheme.border,
            width: expiringTotal > 0 ? 1.0 : 0.5,
          ),
        ),
        child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // ── Left: icon ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: Icon(Icons.people_rounded,
                size: 18, color: AppTheme.onSurfaceDim),
          ),
          const SizedBox(width: 10),

          // ── Centre: compact list ─────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title row
                Row(children: [
                  const Text('Drivers & Staff',
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppTheme.onSurface)),
                  if (expiringTotal > 0) ...[
                    const SizedBox(width: 6),
                    _ExpiryBadge(count: expiringTotal),
                  ],
                ]),
                const SizedBox(height: 6),

                // Driver rows
                ...drivers.map((d) => _QuickRow(
                      label: d.fullName.isNotEmpty ? d.fullName : 'Driver',
                      races: d.contractRacesNum,
                    )),

                // Staff summary
                if (staffData != null && staffData.mainStaff.isNotEmpty)
                  _QuickRow(
                    label: staffData.mainStaff
                        .map((s) => s.roleCode)
                        .join(' · '),
                    races: -1,  // summary line — no single race count
                    staffExpiring: staffData.expiringCount,
                  ),
              ],
            ),
          ),

          // ── Right: chevron ───────────────────────────────────────
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child: Icon(Icons.chevron_right,
                size: 16, color: AppTheme.onSurfaceDim),
          ),
        ]),
      ),
    );
  }
}

/// Single compact row inside [_DriversStaffButton].
class _QuickRow extends StatelessWidget {
  final String label;
  final int    races;          // -1 = staff summary row
  final int    staffExpiring;  // used only on summary row

  const _QuickRow({
    required this.label,
    required this.races,
    this.staffExpiring = 0,
  });

  Color get _raceColor {
    if (races <= 0) return AppTheme.onSurfaceDim;
    if (races <= 3) return AppTheme.error;
    if (races <= 10) return AppTheme.accent;
    return AppTheme.onSurfaceDim;
  }

  @override
  Widget build(BuildContext context) {
    final isSummary = races < 0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(children: [
        Container(
          width: 4, height: 4,
          margin: const EdgeInsets.only(right: 6, top: 1),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: (!isSummary && races <= 3)
                ? AppTheme.error
                : AppTheme.onSurfaceFaint,
          ),
        ),
        Expanded(
          child: Text(label,
              style: const TextStyle(
                  fontSize: 11, color: AppTheme.onSurfaceDim),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
        ),
        if (!isSummary) ...[
          if (races <= 3)
            const Icon(Icons.warning_amber_rounded,
                size: 10, color: AppTheme.error),
          const SizedBox(width: 2),
          Text('${races}r',
              style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _raceColor)),
        ] else if (staffExpiring > 0) ...[
          const Icon(Icons.warning_amber_rounded,
              size: 10, color: AppTheme.error),
          const SizedBox(width: 2),
          Text('$staffExpiring expiring',
              style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: AppTheme.error)),
        ],
      ]),
    );
  }
}

/// Small red badge showing a count of expiring contracts.
class _ExpiryBadge extends StatelessWidget {
  final int count;
  const _ExpiryBadge({required this.count});

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color:        AppTheme.error.withOpacity(0.15),
          borderRadius: BorderRadius.circular(4),
          border:       Border.all(color: AppTheme.error, width: 0.6),
        ),
        child: Text('⚠ $count',
            style: const TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w700,
                color: AppTheme.error)),
      );
}

class _SectionLabel extends StatelessWidget {
  final String text; const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(text.toUpperCase(),
    style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500,
      color: AppTheme.onSurfaceDim, letterSpacing: 0.5));
}

class _HDivider extends StatelessWidget {
  const _HDivider();
  @override
  Widget build(BuildContext context) =>
    const Divider(color: AppTheme.border, thickness: 0.5, height: 0);
}

class _ActionButton extends StatelessWidget {
  final IconData icon; final String label, sub; final VoidCallback onTap;
  const _ActionButton({required this.icon, required this.label, required this.sub, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(color: AppTheme.surfaceCard, borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.border, width: 0.5)),
      child: Row(children: [
        Icon(icon, size: 20, color: AppTheme.onSurfaceDim),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisAlignment: MainAxisAlignment.center, children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
          Text(sub,   style: const TextStyle(fontSize: 10, color: AppTheme.onSurfaceDim)),
        ])),
      ]),
    ),
  );
}

class _LoadingPanel extends StatelessWidget {
  const _LoadingPanel();
  @override
  Widget build(BuildContext context) => const Center(
    child: Padding(padding: EdgeInsets.all(40),
      child: CircularProgressIndicator(strokeWidth: 2)));
}

class _ErrorPanel extends StatelessWidget {
  final String message; const _ErrorPanel({required this.message});
  @override
  Widget build(BuildContext context) => Center(child: Padding(padding: const EdgeInsets.all(24),
    child: Text(message, textAlign: TextAlign.center,
      style: const TextStyle(color: AppTheme.onSurfaceDim, fontSize: 13))));
}

class _RaceCardSkeleton extends StatelessWidget {
  const _RaceCardSkeleton();
  @override
  Widget build(BuildContext context) => Container(height: 64,
    decoration: BoxDecoration(color: AppTheme.surfaceRaised, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.border, width: 0.5)));
}

class _NoRaceCard extends StatelessWidget {
  const _NoRaceCard();
  @override
  Widget build(BuildContext context) => Container(
    height: 48, alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(color: AppTheme.surfaceRaised, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.border, width: 0.5)),
    child: const Text('No upcoming race', style: TextStyle(color: AppTheme.onSurfaceDim, fontSize: 12)));
}

class _RaceCardError extends StatelessWidget {
  const _RaceCardError();
  @override
  Widget build(BuildContext context) => Container(height: 48, alignment: Alignment.centerLeft,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(color: AppTheme.surfaceRaised, borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppTheme.border, width: 0.5)),
    child: const Text('Race data unavailable', style: TextStyle(color: AppTheme.onSurfaceDim, fontSize: 12)));
}

class SetupSuggestSheet extends ConsumerStatefulWidget {
  final String trackCode;
  final List<DriverData> drivers;
  final Map<String, CircuitSetup> circuits;
  final String accountEmail;
  final int numCars;
  final int currentRide1, currentSusp1, currentWing1;
  final int currentRide2, currentSusp2, currentWing2;
  final void Function(int r1, int s1, int w1, int? r2, int? s2, int? w2) onApply;

  const SetupSuggestSheet({
    super.key,
    required this.trackCode,
    required this.drivers,
    required this.circuits,
    required this.accountEmail,
    required this.numCars,
    required this.currentRide1, required this.currentSusp1, required this.currentWing1,
    required this.currentRide2, required this.currentSusp2, required this.currentWing2,
    required this.onApply,
  });

  @override
  ConsumerState<SetupSuggestSheet> createState() => _SetupSuggestSheetState();
}

class _SetupSuggestSheetState extends ConsumerState<SetupSuggestSheet> {
  late CircuitSetup _editing;
  bool _showEdit = false;

  @override
  void initState() {
    super.initState();
    _editing = widget.circuits[widget.trackCode.toLowerCase()] ??
        const CircuitSetup(ride: 50, wing: 50, suspension: 50);
  }

  SuggestedSetup _calculateForDriver(int index) {
    final height = widget.drivers.length > index 
        ? widget.drivers[index].heightCm : 170;
    final adj = SetupSuggestion.heightAdjustment(height);
    return SuggestedSetup(
      ride: (_editing.ride + adj).clamp(1, 100),
      wing: _editing.wing.clamp(1, 100),
      suspension: _editing.suspension.clamp(1, 100),
      trackCode: widget.trackCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    final s1 = _calculateForDriver(0);
    final s2 = widget.numCars >= 2 ? _calculateForDriver(1) : null;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 24),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Center(child: Container(width: 36, height: 4, decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),

        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Suggested setup', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
            Text(widget.trackCode.toUpperCase(), style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceDim)),
          ])),
          GestureDetector(
            onTap: () => setState(() => _showEdit = !_showEdit),
            child: Text(_showEdit ? 'Done' : 'Edit base', style: TextStyle(fontSize: 12, color: AppTheme.primary)),
          ),
        ]),
        const SizedBox(height: 16),

        _DriverHeader(index: 0, driver: widget.drivers.isNotEmpty ? widget.drivers[0] : null),
        const SizedBox(height: 8),
        Row(children: [
          _SuggestValue(label: 'Ride', value: s1.ride, current: widget.currentRide1),
          const SizedBox(width: 8),
          _SuggestValue(label: 'Susp.', value: s1.suspension, current: widget.currentSusp1),
          const SizedBox(width: 8),
          _SuggestValue(label: 'Wing', value: s1.wing, current: widget.currentWing1),
        ]),

        if (s2 != null) ...[
          const SizedBox(height: 20),
          _DriverHeader(index: 1, driver: widget.drivers.length > 1 ? widget.drivers[1] : null),
          const SizedBox(height: 8),
          Row(children: [
            _SuggestValue(label: 'Ride', value: s2.ride, current: widget.currentRide2),
            const SizedBox(width: 8),
            _SuggestValue(label: 'Susp.', value: s2.suspension, current: widget.currentSusp2),
            const SizedBox(width: 8),
            _SuggestValue(label: 'Wing', value: s2.wing, current: widget.currentWing2),
          ]),
        ],

        if (_showEdit) ...[
          const SizedBox(height: 16),
          _EditSlider(label: 'Ride base', value: _editing.ride, onChanged: (v) => setState(() => _editing = _editing.copyWith(ride: v))),
          _EditSlider(label: 'Susp. base', value: _editing.suspension, onChanged: (v) => setState(() => _editing = _editing.copyWith(suspension: v))),
          _EditSlider(label: 'Wing base', value: _editing.wing, min: -20, max: 50, onChanged: (v) => setState(() => _editing = _editing.copyWith(wing: v))),
        ],

        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () {
            widget.onApply(
              s1.ride, s1.suspension, s1.wing,
              s2?.ride, s2?.suspension, s2?.wing,
            );
            Navigator.pop(context);
          },
          child: Text(widget.numCars >= 2 ? 'Apply to both cars' : 'Apply to car'),
        )),
      ]),
    );
  }
}

class _DriverHeader extends StatelessWidget {
  final int index;
  final DriverData? driver;
  const _DriverHeader({required this.index, this.driver});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text('CAR ${index + 1}', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: AppTheme.onSurfaceDim)),
      const SizedBox(width: 8),
      Text(driver?.lastName ?? 'Driver ${index + 1}', style: const TextStyle(fontSize: 11, color: AppTheme.onSurface)),
      const Spacer(),
      Text('${driver?.heightCm ?? 170}cm', style: const TextStyle(fontSize: 10, color: AppTheme.onSurfaceDim)),
    ]);
  }
}

class _SuggestValue extends StatelessWidget {
  final String label;
  final int    value;
  final int    current; 

  const _SuggestValue({
    required this.label,
    required this.value,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final diff  = current >= 0 ? value - current : 0;
    final Color diffColor;
    final String diffStr;
    if (current < 0 || diff == 0) {
      diffColor = AppTheme.onSurfaceDim;
      diffStr   = '';
    } else if (diff > 0) {
      diffColor = AppTheme.success;
      diffStr   = '+$diff';
    } else {
      diffColor = AppTheme.error;
      diffStr   = '$diff';
    }

    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color:        AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(8),
          border:       Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(children: [
          Text(label,
              style: const TextStyle(fontSize: 10, color: AppTheme.onSurfaceDim)),
          const SizedBox(height: 4),
          Text('$value',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700,
                  color: AppTheme.onSurface)),
          if (diffStr.isNotEmpty)
            Text(diffStr,
                style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600,
                    color: diffColor)),
        ]),
      ),
    );
  }
}

class _EditSlider extends StatelessWidget {
  final String           label;
  final int              value;
  final int              min;
  final int              max;
  final ValueChanged<int> onChanged;

  const _EditSlider({
    required this.label,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 100,
  });

  @override
  Widget build(BuildContext context) {
    final clamped = value.clamp(min, max);
    return Row(children: [
      SizedBox(width: 72,
          child: Text(label,
              style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceDim))),
      Expanded(child: SliderTheme(
        data: SliderTheme.of(context).copyWith(
          activeTrackColor:   AppTheme.primary,
          inactiveTrackColor: AppTheme.border,
          thumbColor:         AppTheme.primary,
          thumbShape:         const RoundSliderThumbShape(enabledThumbRadius: 7),
          trackHeight:        3,
          overlayShape:       SliderComponentShape.noOverlay,
        ),
        child: Slider(
          value:    clamped.toDouble(),
          min:      min.toDouble(),
          max:      max.toDouble(),
          onChanged: (v) => onChanged(v.round()),
        ),
      )),
      SizedBox(width: 28,
          child: Text('$clamped', textAlign: TextAlign.right,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: AppTheme.onSurface))),
    ]);
  }
}


// ─── Strategy Formula Helper ──────────────────────────────────────────────────

class StrategyCalc {
  static const trackInfo = {
    'au': {'length': 5.3017135, 'wear': 40, 'avg': 226.1090047, 'pit': 24.0},
    'my': {'length': 5.5358276, 'wear': 80, 'avg': 208.879, 'pit': 22.0},
    'cn': {'length': 5.4417996, 'wear': 80, 'avg': 207.975, 'pit': 26.0},
    'bh': {'length': 4.7273, 'wear': 60, 'avg': 184.933, 'pit': 23.0},
    'es': {'length': 4.4580207, 'wear': 85, 'avg': 189.212, 'pit': 25.0},
    'mc': {'length': 4.0156865, 'wear': 20, 'avg': 187.0, 'pit': 16.0},
    'tr': {'length': 5.1630893, 'wear': 90, 'avg': 196.0, 'pit': 18.0},
    'de': {'length': 4.1797523, 'wear': 50, 'avg': 215.227, 'pit': 17.0},
    'hu': {'length': 3.4990127, 'wear': 30, 'avg': 165.043, 'pit': 17.0},
    'eu': {'length': 5.5907145, 'wear': 45, 'avg': 199.05, 'pit': 17.0},
    'be': {'length': 7.0406127, 'wear': 60, 'avg': 217.7, 'pit': 15.0},
    'it': {'length': 5.4024186, 'wear': 35, 'avg': 263.107, 'pit': 24.0},
    'sg': {'length': 5.049042, 'wear': 45, 'avg': 187.0866142, 'pit': 20.0},
    'jp': {'length': 5.0587635, 'wear': 70, 'avg': 197.065, 'pit': 20.0},
    'br': {'length': 3.9715014, 'wear': 60, 'avg': 203.932, 'pit': 21.0},
    'ae': {'length': 5.412688, 'wear': 50, 'avg': 213.218309, 'pit': 23.0},
    'gb': {'length': 5.75213, 'wear': 65, 'avg': 230.552, 'pit': 23.0},
    'fr': {'length': 5.882508, 'wear': 80, 'avg': 215.1585366, 'pit': 20.0},
    'at': {'length': 4.044372, 'wear': 60, 'avg': 228.546, 'pit': 27.0},
    'ca': {'length': 4.3413563, 'wear': 45, 'avg': 221.357243, 'pit': 17.0},
    'az': {'length': 6.053212, 'wear': 45, 'avg': 220.409, 'pit': 17.0},
    'mx': {'length': 4.3076024, 'wear': 60, 'avg': 172.32, 'pit': 19.0},
    'ru': {'length': 6.078335, 'wear': 50, 'avg': 197.092, 'pit': 21.0},
    'us': {'length': 4.60296, 'wear': 65, 'avg': 186.568, 'pit': 16.0},
    'nl': {'length': 4.259, 'wear': 65, 'avg': 186.568, 'pit': 18.0},
  };

  static const raceLengthMap = {
    'ae': [50, 37, 25, 12], 'au': [57, 42, 28, 14], 'at': [68, 51, 34, 17],
    'az': [46, 34, 23, 11], 'bh': [59, 44, 29, 14], 'be': [43, 32, 21, 10],
    'br': [69, 51, 34, 17], 'ca': [63, 47, 31, 15], 'cn': [55, 41, 27, 13],
    'eu': [50, 37, 25, 12], 'fr': [48, 36, 24, 12], 'de': [67, 50, 33, 16],
    'jp': [55, 41, 27, 13], 'gb': [48, 36, 24, 12], 'it': [51, 38, 25, 12],
    'my': [55, 41, 27, 13], 'mx': [70, 52, 35, 17], 'mc': [59, 44, 29, 14],
    'ru': [46, 34, 23, 11], 'sg': [60, 45, 30, 15], 'es': [62, 46, 31, 15],
    'us': [60, 45, 30, 15], 'tr': [54, 40, 27, 13], 'hu': [79, 59, 39, 19],
    'nl': [72, 59, 36, 19],
  };

  static const tyreWearFactors = { 'SS': 2.14, 'S': 1.4, 'M': 1.0, 'H': 0.78, 'I': 1.0, 'W': 1.0 };
  static const multipliers = { 100: 1.0, 75: 1.25, 50: 1.5, 25: 3.0 };

  static double getPushModifier(int pushLevel) {
    switch (pushLevel) {
      case 20: return -0.007;
      case 40: return -0.004;
      case 60: return 0.0;
      case 80: return 0.01;
      case 100: return 0.02;
      default: return 0.0;
    }
  }

  static double getFuelPerLap(int fuelAttr, String trackCode, int pushLevel) {
    if (fuelAttr <= 0) fuelAttr = 1;
    final track = trackInfo[trackCode.toLowerCase()];
    if (track == null) return 2.0; 
    
    final length = track['length'] as double;
    final fuelPerKm = 0.6983736841 * math.pow(fuelAttr, -0.08510976572);
    final baseFuel = fuelPerKm * length;
    
    return baseFuel * (1.0 + getPushModifier(pushLevel));
  }

  static int getLeagueLengthKey(String trackCode, int raceLaps) {
    final lapsArr = raceLengthMap[trackCode.toLowerCase()];
    if (lapsArr == null) return 100;
    for (int i = 0; i < lapsArr.length; i++) {
      if ((lapsArr[i] - raceLaps).abs() <= 2) {
        return [100, 75, 50, 25][i];
      }
    }
    return 100; 
  }

  static double getTyreWearPercentage({
    required int teAttr,
    required String trackCode,
    required String tyre,
    required int laps,
    required int raceLaps,
  }) {
    if (teAttr <= 0) teAttr = 1;
    final track = trackInfo[trackCode.toLowerCase()];
    if (track == null) return 100.0;
    
    final trackWear = (track['wear'] as num).toDouble();
    final trackLength = track['length'] as double;
    
    final multKey = getLeagueLengthKey(trackCode, raceLaps);
    final mult = multipliers[multKey] ?? 1.0;
    final wearFactor = tyreWearFactors[tyre] ?? 1.0;
    
    final t = (1.29 * math.pow(teAttr, -0.0696)) *
              (0.00527 * trackWear + 0.556) *
              trackLength *
              mult *
              wearFactor;
              
    final stintWearLeft = math.pow(math.e, (-t / 100 * 1.18) * laps) * 100;
    return stintWearLeft.clamp(0.0, 100.0).toDouble();
  }

  /// Evaluates strategies and returns the fastest realistic configuration.
  static List<_Stint> getOptimalStrategy({
    required int raceLaps,
    required double fuelPerLap,
    required int teAttr,
    required String trackCode,
    required bool refuelling,
  }) {
    final track = trackInfo[trackCode.toLowerCase()];
    final pitTime = (track?['pit'] as double?) ?? 22.0;

    List<_Stint>? bestStints;
    double bestTime = double.infinity;

    final tyres = ['SS', 'S', 'M', 'H'];
    final tyrePace = {'SS': 0.0, 'S': 0.3, 'M': 0.6, 'H': 0.9};

    int maxStints = (raceLaps / 14).ceil() + 1;
    if (maxStints > 5) maxStints = 5;

    for (int numStints = 1; numStints <= maxStints; numStints++) {
      int baseLaps = raceLaps ~/ numStints;
      int remainder = raceLaps % numStints;

      List<int> lapsPerStint = List.generate(
        numStints, 
        (i) => baseLaps + (i < remainder ? 1 : 0)
      );

      double totalTime = (numStints - 1) * pitTime;
      bool isValid = true;
      List<_Stint> currentStints = [];

      for (int laps in lapsPerStint) {
        String? selectedTyre;
        double bestWear = -1.0;
        double lowestPenalty = double.infinity;

        for (String t in tyres) {
          double wearLeft = getTyreWearPercentage(
            teAttr: teAttr, trackCode: trackCode, tyre: t, laps: laps, raceLaps: raceLaps
          );
          
          double penalty = 0.0;
          if (wearLeft < 45.0) {
            penalty = (45.0 - wearLeft) * 1.5; 
          }
          
          if (wearLeft > 15.0) {
             double totalTyreCost = (laps * tyrePace[t]!) + penalty;
             if (totalTyreCost < lowestPenalty) {
               lowestPenalty = totalTyreCost;
               selectedTyre = t;
               bestWear = wearLeft;
             }
          }
        }

        if (selectedTyre == null || bestWear < 15.0) {
          isValid = false; 
          break;
        }

        double tTyre = lowestPenalty; 
        double tFuel = 0.0;
        
        if (refuelling) {
           double averageFuelLiters = (laps * fuelPerLap) / 2.0;
           tFuel = laps * (averageFuelLiters * 0.025);
        }
        totalTime += tTyre + tFuel;
        
        currentStints.add(_Stint(
          tyre: selectedTyre,
          laps: laps,
          fuelPerLap: fuelPerLap,
          explicitFuel: refuelling ? (laps * fuelPerLap).ceil() : null,
        ));
      }

      if (isValid && totalTime < bestTime) {
        bestTime = totalTime;
        bestStints = currentStints;
      }
    }
    if (bestStints == null) {
      int bLaps = raceLaps ~/ 5;
      int rem = raceLaps % 5;
      bestStints = List.generate(5, (i) {
        int l = bLaps + (i < rem ? 1 : 0);
        return _Stint(
          tyre: 'H',
          laps: l,
          fuelPerLap: fuelPerLap,
          explicitFuel: refuelling ? (l * fuelPerLap).ceil() : null,
        );
      });
    }

    return bestStints;
  }
}