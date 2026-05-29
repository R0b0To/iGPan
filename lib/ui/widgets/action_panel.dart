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
import 'car_research_sheet.dart';
 
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
 
  // Handle case where user switches account while this is loading
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
      
      // Once this completes, the sessionStateProvider updates, 
      // and ActionPanel (the parent) will automatically rebuild 
      // into the normal content.
    } catch (e) {
      // If even the auto-login fails (e.g. password changed), 
      // then we actually show an error message.
      if (mounted) {
        debugPrint('Auto-relogin error: $e');
      }
    }
  }
 
  @override
  Widget build(BuildContext context) {
    // Show a loading screen while we silently fix the session
    return const _LoadingPanel();
  }
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
        // ── Compact overview ────────────────────────────────
        _CompactOverview(
          accountData:  accountData,
          financeAsync: financeAsync,
          accountEmail: accountEmail,
        ),
        const SizedBox(height: 12),
        const _HDivider(),
        const SizedBox(height: 10),
        // ── Actions ──────────────────────────────────────────
        _SectionLabel('Actions'),
        const SizedBox(height: 6),
        GridView.count(
          crossAxisCount:   2,
          shrinkWrap:       true,
          physics:          const NeverScrollableScrollPhysics(),
          crossAxisSpacing: 8,
          mainAxisSpacing:  8,
          childAspectRatio: 2.4,
          children: [
            _ActionButton(
              icon:  Icons.people_rounded,
              label: 'Drivers',
              sub:   '${accountData.numDrivers} active',
              onTap: () {},
            ),
            if (accountData.carData != null)
              _ActionButton(
                icon:  Icons.science_outlined,
                label: 'Research',
                sub:   _researchSub(accountData.carData!),
                onTap: () => _openResearch(context, accountData.carData!),
              ),
          ],
        ),
        // ── Car condition ─────────────────────────────────────
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
        // ── Race card ─────────────────────────────────────────
        _SectionLabel('Next race'),
        const SizedBox(height: 6),
        raceAsync.when(
          loading: () => const _RaceCardSkeleton(),
          error:   (_, __) => const _RaceCardError(),
          data:    (race) {
            if (race.raceId.isEmpty) return const _NoRaceCard();
            
            // ADDED ValueKey HERE:
            // This forces the StatefulWidget to reset its internal state (sliders/stints)
            // whenever the account or the race changes.
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
          // Row 1 — stats + claim button
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
          // Row 2 — sponsors
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
    super.key, // Added super.key to support ValueKey
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
 
  // ── Car 2 state (only used when numCars == 2) ──────────
  late int    _d2Ride, _d2Suspension, _d2Wing;
  late String _d2PracticeTyre;
  late List<_Stint> _d2Stints;
  int  _d2PushLevel = 60;
 
  @override
  void initState() {
    super.initState();
    final r = widget.race;
 
    _ride         = r.d1Ride.clamp(1, 100);
    _suspension   = r.d1Suspension.clamp(1, 100);
    _wing         = r.d1Aerodynamics.clamp(1, 100);
    _practiceTyre = r.d1PracticeTyre.isEmpty ? 'M' : r.d1PracticeTyre;
    _pushLevel    = r.d1PushLevel;
    _d1AdvancedFuel = r.d1AdvancedFuel;
    _d2AdvancedFuel = r.d2AdvancedFuel;
 
    // Load saved stints from server, fall back to default if none
    if (r.d1Stints.isNotEmpty) {
      _stints = r.d1Stints.map((s) => _Stint(
        tyre:       s.tyre,
        laps:       s.laps,
        fuelPerLap: r.d1FuelPrediction,
      )).toList();
    } else {
      final n = (r.d1Pits + 1).clamp(1, 5);
      _stints = List.generate(n, (_) => _Stint(fuelPerLap: r.d1FuelPrediction));
    }
 
    // Car 2 — only meaningful when twoCars
    _d2Ride         = r.d2Ride.clamp(1, 100);
    _d2Suspension   = r.d2Suspension.clamp(1, 100);
    _d2Wing         = r.d2Aerodynamics.clamp(1, 100);
    _d2PracticeTyre = r.d2PracticeTyre.isEmpty ? 'M' : r.d2PracticeTyre;
    _d2PushLevel    = r.d2PushLevel;
 
    if (r.d2Stints.isNotEmpty) {
      _d2Stints = r.d2Stints.map((s) => _Stint(
        tyre:       s.tyre,
        laps:       s.laps,
        fuelPerLap: r.d2FuelPrediction,
      )).toList();
    } else {
      final n2 = (r.d2Pits + 1).clamp(1, 5);
      _d2Stints = List.generate(n2, (_) => _Stint(fuelPerLap: r.d2FuelPrediction));
    }
  }
 
  int  get _totalLaps => _stints.fold(0, (s, st) => s + st.laps);
  bool get _lapsOk    => _totalLaps >= widget.race.raceLaps;
 
 // Inside _InlineRaceCardState
Future<void> _showSuggestSetup(BuildContext context, WidgetRef ref) async {
  final drivers = ref.read(driversProvider(widget.accountEmail));
  final circuits = await ref.read(circuitsProvider(widget.accountEmail).future);
 
  final trackCode = widget.race.raceTrackFlag.isNotEmpty
      ? widget.race.raceTrackFlag
      : widget.race.raceTrackId;
 
  if (!context.mounted) return;
 
  showModalBottomSheet(
    context: context,
    backgroundColor: AppTheme.surfaceCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => SetupSuggestSheet(
      trackCode: trackCode,
      drivers: drivers,
      circuits: circuits,
      accountEmail: widget.accountEmail,
      numCars: widget.accountData.numCars, // Pass numCars
      // Pass current values for comparison
      currentRide1: _ride,
      currentSusp1: _suspension,
      currentWing1: _wing,
      currentRide2: _d2Ride,
      currentSusp2: _d2Suspension,
      currentWing2: _d2Wing,
      onApply: (r1, s1, w1, r2, s2, w2) => setState(() {
        // Apply Car 1
        _ride = r1;
        _suspension = s1;
        _wing = w1;
        // Apply Car 2 (if provided)
        if (r2 != null && s2 != null && w2 != null) {
          _d2Ride = r2;
          _d2Suspension = s2;
          _d2Wing = w2;
        }
      }),
    ),
  );
}
 
  Future<void> _save(BuildContext context, WidgetRef ref) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await ref.read(raceServiceProvider).saveAll(
        accountEmail:   widget.accountEmail,
        raceId:         widget.race.raceId,
        twoCars:        widget.accountData.numCars >= 2,
        refuelling:     widget.race.refuelling, // Important flag
        d1Ride:         _ride,
        d1Suspension:   _suspension,
        d1Wing:         _wing,
        d1PracticeTyre: _practiceTyre,
        d1Stints:       _stints.map((s) => s.toMap()).toList(),
        d1NumPits:      _stints.length - 1,
        d1PushLevel:    _pushLevel,
        d1AdvancedFuel: _d1AdvancedFuel, // Pass the local state variable
        d1Saved:        true,
        d2Ride:         _d2Ride,
        d2Suspension:   _d2Suspension,
        d2Wing:         _d2Wing,
        d2PracticeTyre: _d2PracticeTyre,
        d2Stints:       _d2Stints.map((s) => s.toMap()).toList(),
        d2NumPits:      _d2Stints.length - 1,
        d2PushLevel:    _d2PushLevel,
        d2AdvancedFuel: _d2AdvancedFuel, // Pass the local state variable
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
    return Consumer(builder: (ctx, ref, _) => Container(
      decoration: BoxDecoration(
        color:        AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(12),
        border:       Border.all(color: AppTheme.border, width: 0.5),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
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
 
        // Setup sliders
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Setup header with Suggest button
            Row(children: [
              const Expanded(
                child: Text('SETUP', style: TextStyle(
                    fontSize: 10, fontWeight: FontWeight.w500,
                    color: AppTheme.onSurfaceDim, letterSpacing: 0.5))),
              GestureDetector(
                onTap: () => _showSuggestSetup(ctx, ref),
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
              ),
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
 
        // Strategy
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // ── Strategy header with add/delete controls ─────
            Row(children: [
              const Text('STRATEGY', style: TextStyle(
                fontSize: 10, fontWeight: FontWeight.w500,
                color: AppTheme.onSurfaceDim, letterSpacing: 0.5)),
              const Spacer(),
              // +/- centred in the remaining space
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
                      _Stint(fuelPerLap: widget.race.d1FuelPrediction))),
                ),
              const Spacer(),
              Text('$_totalLaps / ${widget.race.raceLaps}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                  color: _lapsOk ? AppTheme.onSurfaceDim : AppTheme.error)),
            ]),
            const SizedBox(height: 4),
            Text('~${widget.race.d1FuelPrediction.toStringAsFixed(2)}L/lap',
              style: const TextStyle(fontSize: 10, color: AppTheme.onSurfaceDim)),
            const SizedBox(height: 8),
 
            // Stint row — draggable reorder by long-press
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: ReorderableRow(
                stints:    _stints,
                fuelPerLap: widget.race.d1FuelPrediction,
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
 
 
// Show Total Fuel only if NO refuelling
if (!widget.race.refuelling) ...[
  _FuelSlider(
    label: 'Total Fuel',
    value: _d1AdvancedFuel,
    onChanged: (v) => setState(() => _d1AdvancedFuel = v),
  ),
  const SizedBox(height: 10),
],
 
            // Push level
            Row(children: [
              const Text('Push:', style: TextStyle(fontSize: 11, color: AppTheme.onSurfaceDim)),
              const SizedBox(width: 8),
              ...{20: 'V.Low', 40: 'Low', 60: 'Mid', 80: 'High', 100: 'V.High'}.entries.map((e) {
                final sel = _pushLevel == e.key;
                return GestureDetector(
                  onTap: () => setState(() => _pushLevel = e.key),
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
 
            // ── Car 2 section (2-car leagues only) ─────────
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
                        _Stint(fuelPerLap: widget.race.d2FuelPrediction))),
                  ),
                const Spacer(),
                Text('${_d2Stints.fold(0, (s, st) => s + st.laps)} / ${widget.race.raceLaps}',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: _d2Stints.fold(0, (s, st) => s + st.laps) >= widget.race.raceLaps
                        ? AppTheme.onSurfaceDim : AppTheme.error)),
              ]),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: ReorderableRow(
                  stints:     _d2Stints,
                  fuelPerLap: widget.race.d2FuelPrediction,
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
                    onTap: () => setState(() => _d2PushLevel = e.key),
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
 
 
// ─── Stint header button (+ / -) ─────────────────────────────────────────────
 
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
 
// ─── Draggable reorderable stint row ─────────────────────────────────────────
 
/// Horizontal row of stint cards that can be long-pressed to drag and
/// dropped onto another card to swap positions.
class ReorderableRow extends StatefulWidget {
  final List<_Stint>                stints;
  final double                      fuelPerLap;
  final int                         raceLaps;
  final bool                        refuelling;   // ADD THIS
  final void Function(int, int)     onReorder;   
  final void Function(int, _Stint)  onChanged;
 
  const ReorderableRow({
    super.key,
    required this.stints,
    required this.fuelPerLap,
    required this.raceLaps,
    required this.refuelling, // ADD THIS
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
// ─── Stint model ──────────────────────────────────────────────────────────────
 
class _Stint {
  String tyre;
  int laps;
  double fuelPerLap;
 
  _Stint({this.tyre = 'M', this.laps = 7, this.fuelPerLap = 0.0});
 
  // Calculate fuel based on current laps
  int get fuel => (laps * fuelPerLap).ceil().clamp(1, 300);
 
  // Helper to calculate how many laps we can do with a specific amount of fuel
  static int lapsFromFuel(int fuelAmount, double consumption) {
    if (consumption <= 0) return 1;
    // We use floor because we can't complete a lap if we have partial fuel
    return (fuelAmount / consumption).floor().clamp(1, 100);
  }
 
  Map<String, dynamic> toMap() => {
    'tyre': tyre,
    'laps': laps,
    'fuel': fuel,
    'fuelPerLap': fuelPerLap,
  };
}
 
// ─── Stint card ───────────────────────────────────────────────────────────────
 
class _StintCard extends StatelessWidget {
  final int        index;
  final _Stint     stint;
  final int        raceLaps;
  final double     fuelPerLap;
  final bool       refuelling;
  final ValueChanged<_Stint>  onChanged;
 
 
  const _StintCard({
    required this.index, required this.stint, required this.raceLaps,required this.refuelling, 
    required this.fuelPerLap, required this.onChanged,
  });
 
  // Real F1-style tyre colours
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
    final fuel = (stint.laps * fuelPerLap).toStringAsFixed(1);
 
    return GestureDetector(
      onTap: () => showModalBottomSheet(
  context: context,
  // ...
  builder: (_) => _StintEditor(
    label: _label, 
    stint: stint, 
    raceLaps: raceLaps,
    fuelPerLap: fuelPerLap, 
    refuelling: refuelling,
    onSave: onChanged, 
  ),
),
      child: Container(
        width:  52,
        height: 72,
        decoration: BoxDecoration(
          color:        AppTheme.surfaceRaised,
          borderRadius: BorderRadius.circular(10),
          border:       Border.all(color: AppTheme.border, width: 0.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Label
            Text(_label,
                style: const TextStyle(
                    fontSize: 9,
                    fontWeight: FontWeight.w500,
                    color: AppTheme.onSurfaceDim)),
            const SizedBox(height: 4),
            // Tyre circle with laps inside
            Container(
              width:  36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.surface,
                border:       Border.all(color: c, width: 6.5),
              ),
              child: Text(
                '${stint.laps}',
                style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.pillTextSel),
              ),
            ),
            const SizedBox(height: 4),
            // Fuel load
            Text('${fuel}L',
                style: const TextStyle(
                    fontSize: 9, color: AppTheme.onSurfaceDim)),
          ],
        ),
      ),
    );
  }
}
 
// ─── Stint editor bottom sheet ────────────────────────────────────────────────
 
class _StintEditor extends StatefulWidget {
  final String label;
  final _Stint stint;
  final int raceLaps;
  final double fuelPerLap;
  final bool refuelling; // Added this
  final ValueChanged<_Stint> onSave;
  final VoidCallback? onDelete;
 
  const _StintEditor({
    required this.label,
    required this.stint,
    required this.raceLaps,
    required this.fuelPerLap,
    required this.refuelling,
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
 
  // These need to be here for the tyre selection
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
      _fuel = newFuel.clamp(1, 100);
      _laps = _Stint.lapsFromFuel(_fuel, widget.fuelPerLap);
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
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 16, 20, MediaQuery.of(context).viewInsets.bottom + 20),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        // Top Handle
        Center(child: Container(width: 36, height: 4,
          decoration: BoxDecoration(color: AppTheme.border, borderRadius: BorderRadius.circular(2)))),
        const SizedBox(height: 16),
        
        // Header (Label + Delete)
        Row(children: [
          Text(widget.label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppTheme.onSurface)),
          const Spacer(),
          if (widget.onDelete != null)
            GestureDetector(
              onTap: () { Navigator.pop(context); widget.onDelete!(); },
              child: const Icon(Icons.delete_outline, size: 20, color: AppTheme.error)),
        ]),
        const SizedBox(height: 16),
        
        // --- THIS IS THE MISSING TYRE SELECTION UI ---
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
      height: 44, // fixed row height
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
        
        // --- NEW DYNAMIC FUEL/LAPS EDITOR ---
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
              ? (_fuel < 100 ? () => _updateFuel(_fuel + 1) : null)
              : (_laps < widget.raceLaps ? () => _updateLaps(_laps + 1) : null)
          ),
        ]),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppTheme.surfaceRaised,
            borderRadius: BorderRadius.circular(8)
          ),
          child: Text(
            widget.refuelling 
              ? 'Estimated Range: $_laps Laps' 
              : 'Required Fuel: ~${(_laps * widget.fuelPerLap).toStringAsFixed(1)}L',
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppTheme.primary),
          ),
        ),
        const SizedBox(height: 24),
        SizedBox(width: double.infinity, child: ElevatedButton(
          onPressed: () {
            widget.onSave(_Stint(
              tyre: _tyre,
              laps: _laps,
              fuelPerLap: widget.fuelPerLap,
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
 
// ─── Setup slider ─────────────────────────────────────────────────────────────
 
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
 
// ─── Shared utils ─────────────────────────────────────────────────────────────
 
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
 
// ─── Setup suggestion sheet ───────────────────────────────────────────────────
 
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
 
  // Helper to calculate setup for a specific driver index
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
 
        // --- CAR 1 ---
        _DriverHeader(index: 0, driver: widget.drivers.isNotEmpty ? widget.drivers[0] : null),
        const SizedBox(height: 8),
        Row(children: [
          _SuggestValue(label: 'Ride', value: s1.ride, current: widget.currentRide1),
          const SizedBox(width: 8),
          _SuggestValue(label: 'Susp.', value: s1.suspension, current: widget.currentSusp1),
          const SizedBox(width: 8),
          _SuggestValue(label: 'Wing', value: s1.wing, current: widget.currentWing1),
        ]),
 
        // --- CAR 2 (Conditional) ---
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
 
        // Edit Sliders (hidden by default)
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
 
// Small helper widget for the Driver labels inside the sheet
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
  final int    current; // -1 = no comparison
 
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
class _FuelSlider extends StatelessWidget {
  final String label;
  final int value;
  final ValueChanged<int> onChanged;
 
  const _FuelSlider({required this.label, required this.value, required this.onChanged});
 
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      SizedBox(width: 60, child: Text(label, style: const TextStyle(fontSize: 11, color: AppTheme.onSurfaceDim))),
      
      // Minus Button
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
            min: 0, max: 200, // Adjust max based on typical iGP needs
            onChanged: (v) => onChanged(v.round()),
          ),
        ),
      ),
      
      // Plus Button
      _MiniCircleBtn(icon: Icons.add, onTap: () => onChanged((value + 1).clamp(0, 200))),
      
      SizedBox(width: 35, child: Text('$value L', textAlign: TextAlign.right,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppTheme.primary))),
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
 
// ─── Car condition card ───────────────────────────────────────────────────────
 
/// Inline compact card showing parts + engine condition for up to 2 cars.
/// Lives inside _PanelContent so it rebuilds automatically when the session
/// refreshes after a repair — no stale data problem.
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
  // 'c1-parts', 'c1-engine', 'c2-parts', 'c2-engine'
  final Set<String> _loading = {};
 
  bool _isLoading(int carNum, String type) =>
      _loading.contains('c$carNum-$type');
 
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
      // Session refresh triggers _PanelContent rebuild with fresh carData
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
          const Text('CAR CONDITION',
              style: TextStyle(
                  fontSize: 10, fontWeight: FontWeight.w600,
                  color: AppTheme.onSurfaceDim, letterSpacing: 0.5)),
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
  final int           value;   // 0-100
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
      // Condition circle
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
      // Label
      Expanded(
        child: Text(label,
            style: const TextStyle(
                fontSize: 11, fontWeight: FontWeight.w500,
                color: AppTheme.onSurface)),
      ),
      // Repair button or checkmark
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