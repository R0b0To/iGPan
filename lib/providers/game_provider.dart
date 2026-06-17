import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/race_data.dart';
import '../core/setup_overrides_storage.dart';
import '../core/strategy_calc.dart';
import '../models/finance_data.dart';
import '../models/driver_data.dart';
import '../models/setup_suggestion.dart';
import '../services/game_service.dart';
export '../services/game_service.dart' show BatchResult;
import 'providers.dart';
import 'session_provider.dart';

// ─── Service providers ────────────────────────────────────────────────────────

final gameServiceProvider = Provider<GameService>((ref) {
  return GameService(httpClient: ref.watch(httpClientProvider));
});

// ─── Per-account race data ────────────────────────────────────────────────────

/// Race data for one account.
/// Usage: ref.watch(raceDataProvider('user@example.com'))
final raceDataProvider =
    FutureProvider.family<RaceData, String>((ref, email) async {
  return ref.watch(raceServiceProvider).fetchRaceData(email);
});

// ─── Batch action state ───────────────────────────────────────────────────────

/// Tracks in-progress and completed batch action results.
class BatchActionState {
  final bool                     isRunning;
  final Map<String, BatchResult> results; // email → result

  const BatchActionState({
    this.isRunning = false,
    this.results   = const {},
  });

  bool get hasResults => results.isNotEmpty;
  bool get allSuccess => results.values.every((r) => r.success);

  BatchActionState copyWith({
    bool?                     isRunning,
    Map<String, BatchResult>? results,
  }) {
    return BatchActionState(
      isRunning: isRunning ?? this.isRunning,
      results:   results   ?? this.results,
    );
  }
}

class BatchActionNotifier extends Notifier<BatchActionState> {
  @override
  BatchActionState build() => const BatchActionState();

  // ─── Claim daily reward ─────────────────────────────────────────────────

  /// Claim daily reward for all [emails] concurrently.
  Future<void> claimDailyRewardAll(List<String> emails) async {
    if (emails.isEmpty) return;
    state = const BatchActionState(isRunning: true, results: {});

    final results = await ref
        .read(gameServiceProvider)
        .claimDailyRewardAll(emails);

    state = BatchActionState(isRunning: false, results: results);

    // Refresh session state for successful accounts so the UI updates.
    for (final entry in results.entries) {
      if (entry.value.success) {
        ref.read(sessionStateProvider(entry.key).notifier).refresh();
      }
    }
  }

  // ─── Auto setup ─────────────────────────────────────────────────────────

  /// Apply suggested setup (ride/susp/wing) and optimal strategy to all
  /// [emails] concurrently, then save.
  ///
  /// Skips accounts with no upcoming race or a race that is already live.
  Future<void> autoSetupAll(List<String> emails) async {
    if (emails.isEmpty) return;
    state = const BatchActionState(isRunning: true, results: {});

    final futures = emails.map((email) async {
      try {
        final result = await _autoSetupForAccount(email);
        return MapEntry(email, result);
      } catch (e) {
        return MapEntry(email, BatchResult.failure(e.toString()));
      }
    });

    final results = Map.fromEntries(await Future.wait(futures));
    state = BatchActionState(isRunning: false, results: results);

    for (final entry in results.entries) {
      if (entry.value.success) {
        ref.read(sessionStateProvider(entry.key).notifier).refresh();
        ref.invalidate(raceDataProvider(entry.key));
      }
    }
  }

  Future<BatchResult> _autoSetupForAccount(String email) async {
    final accountData = ref.read(accountDataProvider(email));
    if (accountData == null) {
      return BatchResult.failure('Account data unavailable for $email');
    }

    final raceService = ref.read(raceServiceProvider);
    final raceData    = await raceService.fetchRaceData(email);

    if (raceData.raceId.isEmpty) {
      return BatchResult.failure('No upcoming race');
    }
    if (raceData.raceLocked) {
      return BatchResult.failure('Race is live — setup locked');
    }

    final trackCode = raceData.raceTrackFlag.isNotEmpty
        ? raceData.raceTrackFlag
        : raceData.raceTrackId;

    final circuits  = await ref.read(setupOverridesStorageProvider).getAllCircuits(email);
    final overrides = circuits[trackCode.toLowerCase()];
    final drivers   = accountData.drivers;
    final twoCars   = accountData.numCars >= 2;

    // ── Setup suggestion (ride/susp/wing per car, from driver height) ──────
    final height1     = drivers.isNotEmpty ? drivers[0].heightCm : 170;
    final suggestion1 = SetupSuggestion.forTrack(trackCode, height1, overrides: overrides);

    final ride1 = suggestion1?.ride       ?? raceData.d1Ride;
    final susp1 = suggestion1?.suspension ?? raceData.d1Suspension;
    final wing1 = suggestion1?.wing       ?? raceData.d1Aerodynamics;

    var ride2 = raceData.d2Ride;
    var susp2 = raceData.d2Suspension;
    var wing2 = raceData.d2Aerodynamics;
    if (twoCars) {
      final height2     = drivers.length > 1 ? drivers[1].heightCm : 170;
      final suggestion2 = SetupSuggestion.forTrack(trackCode, height2, overrides: overrides);
      if (suggestion2 != null) {
        ride2 = suggestion2.ride;
        susp2 = suggestion2.suspension;
        wing2 = suggestion2.wing;
      }
    }

    // ── Car attributes (fuel economy index 4, tyre economy index 7) ───────
    int fuelAttr = 50;
    int teAttr   = 50;
    final car = accountData.carData;
    if (car != null && car.attributes.length > 7) {
      fuelAttr = car.attributes[4].currentValue;
      teAttr   = car.attributes[7].currentValue;
    }

    // ── Strategy for car 1 ─────────────────────────────────────────────────
    final fuelPerLap1 = StrategyCalc.getFuelPerLap(
        fuelAttr, trackCode, raceData.d1PushLevel);
    final stints1 = StrategyCalc.getOptimalStrategy(
      raceLaps:    raceData.raceLaps,
      fuelPerLap:  fuelPerLap1,
      teAttr:      teAttr,
      trackCode:   trackCode,
      refuelling:  raceData.refuelling,
      twoTyreRule: raceData.twoTyreRule,
    );

    if (stints1.isEmpty) {
      return BatchResult.failure('Could not compute a valid strategy for car 1');
    }

    final advancedFuel1 = (raceData.raceLaps * fuelPerLap1).ceil().clamp(1, 200);

    // ── Strategy for car 2 ─────────────────────────────────────────────────
    var stints2       = <Map<String, dynamic>>[];
    var advancedFuel2 = 0;
    if (twoCars) {
      final fuelPerLap2 = StrategyCalc.getFuelPerLap(
          fuelAttr, trackCode, raceData.d2PushLevel);
      final s2 = StrategyCalc.getOptimalStrategy(
        raceLaps:    raceData.raceLaps,
        fuelPerLap:  fuelPerLap2,
        teAttr:      teAttr,
        trackCode:   trackCode,
        refuelling:  raceData.refuelling,
        twoTyreRule: raceData.twoTyreRule,
      );

      if (s2.isEmpty) {
        return BatchResult.failure('Could not compute a valid strategy for car 2');
      }

      stints2       = s2.map((s) => s.toMap()).toList();
      advancedFuel2 = (raceData.raceLaps * fuelPerLap2).ceil().clamp(1, 200);
    }

    // ── Save ───────────────────────────────────────────────────────────────
    final data = await raceService.saveAll(
      accountEmail:   email,
      raceId:         raceData.raceId,
      twoCars:        twoCars,
      refuelling:     raceData.refuelling,
      d1Ride:         ride1,
      d1Suspension:   susp1,
      d1Wing:         wing1,
      d1PracticeTyre: raceData.d1PracticeTyre.isEmpty ? 'M' : raceData.d1PracticeTyre,
      d1Stints:       stints1.map((s) => s.toMap()).toList(),
      d1NumPits:      stints1.length - 1,
      d1PushLevel:    raceData.d1PushLevel,
      d1AdvancedFuel: advancedFuel1,
      d1Saved:        true,
      d2Ride:         ride2,
      d2Suspension:   susp2,
      d2Wing:         wing2,
      d2PracticeTyre: raceData.d2PracticeTyre.isEmpty ? 'M' : raceData.d2PracticeTyre,
      d2Stints:       stints2,
      d2NumPits:      twoCars ? (stints2.length - 1) : 0,
      d2PushLevel:    raceData.d2PushLevel,
      d2AdvancedFuel: advancedFuel2,
      d2Saved:        twoCars,  // ← was missing; marks car-2 strategy as saved
    );

    return BatchResult.success(data);
  }

  // ─── Repair all ─────────────────────────────────────────────────────────

  /// Repair worn parts and engines for all [emails] concurrently.
  Future<void> repairAllAccounts(List<String> emails) async {
    if (emails.isEmpty) return;
    state = const BatchActionState(isRunning: true, results: {});

    final futures = emails.map((email) async {
      try {
        final result = await _repairAllForAccount(email);
        return MapEntry(email, result);
      } catch (e) {
        return MapEntry(email, BatchResult.failure(e.toString()));
      }
    });

    final results = Map.fromEntries(await Future.wait(futures));
    state = BatchActionState(isRunning: false, results: results);

    for (final entry in results.entries) {
      if (entry.value.success) {
        ref.read(sessionStateProvider(entry.key).notifier).refresh();
      }
    }
  }

  Future<BatchResult> _repairAllForAccount(String email) async {
    final accountData = ref.read(accountDataProvider(email));
    final carData     = accountData?.carData;
    if (carData == null) {
      return BatchResult.failure('No car data available');
    }

    final conditions = [
      if (carData.car1Condition != null) carData.car1Condition!,
      if ((accountData?.numCars ?? 1) >= 2 && carData.car2Condition != null)
        carData.car2Condition!,
    ];

    if (conditions.isEmpty) {
      return BatchResult.failure('No car conditions found');
    }

    final carService = ref.read(carServiceProvider);
    var didRepair = false;
    Map<String, dynamic> lastData = {};

    for (final cond in conditions) {
      if (cond.partsValue < 100 && !cond.partsLocked) {
        lastData  = await carService.repairParts(
            email, carId: cond.carId, carNumber: cond.carNumber);
        didRepair = true;
      }
      if (cond.engineValue < 100 && !cond.engineLocked) {
        lastData  = await carService.replaceEngine(
            email, carId: cond.carId, carNumber: cond.carNumber);
        didRepair = true;
      }
    }

    return didRepair
        ? BatchResult.success(lastData)
        : BatchResult.success(const {'message': 'Already in good condition'});
  }

  // ─── Reset ──────────────────────────────────────────────────────────────

  void clear() => state = const BatchActionState();
}

final batchActionProvider =
    NotifierProvider<BatchActionNotifier, BatchActionState>(
  BatchActionNotifier.new,
);

// ─── Finance / sponsor provider ───────────────────────────────────────────────

final financeDataProvider =
    FutureProvider.family<FinanceData, String>((ref, email) async {
  return ref.read(financeServiceProvider).fetchFinances(email);
});

// ─── Driver provider ──────────────────────────────────────────────────────────

/// Per-account drivers, synchronously pulled from the cached AccountData.
final driversProvider = Provider.family<List<DriverData>, String>((ref, email) {
  final accountData = ref.watch(accountDataProvider(email));
  return accountData?.drivers ?? [];
});

// ─── Setup overrides provider ─────────────────────────────────────────────────

final setupOverridesStorageProvider =
    Provider<SetupOverridesStorage>((_) => SetupOverridesStorage());

/// All circuits (defaults merged with account overrides) for one account.
final circuitsProvider =
    FutureProvider.family<Map<String, CircuitSetup>, String>((ref, email) async {
  return ref.read(setupOverridesStorageProvider).getAllCircuits(email);
});