import 'package:flutter_riverpod/flutter_riverpod.dart';
 
import '../models/account_data.dart';
import '../models/race_data.dart';
 

import '../core/setup_overrides_storage.dart';
import '../models/finance_data.dart';
import '../models/driver_data.dart';
import '../models/setup_suggestion.dart';
import '../services/game_service.dart';
export '../services/game_service.dart' show BatchResult;

import 'providers.dart';
// 🟢 Import session_provider to access accountDataProvider and sessionStateProvider
import 'session_provider.dart'; 
 
// ─── Service providers ────────────────────────────────────────────────────────
 
final gameServiceProvider = Provider<GameService>((ref) {
  return GameService(httpClient: ref.watch(httpClientProvider));
});
 

// ─── Per-account race data ────────────────────────────────────────────────────
 
/// Race data for one account.
///
/// Usage:  ref.watch(raceDataProvider('user@example.com'))
final raceDataProvider =
    FutureProvider.family<RaceData, String>((ref, email) async {
  return ref.watch(raceServiceProvider).fetchRaceData(email);
});
 
// ─── Batch action state ───────────────────────────────────────────────────────
 
/// Tracks in-progress and completed batch action results.
class BatchActionState {
  final bool                    isRunning;
  final Map<String, BatchResult> results;  // email → result
 
  const BatchActionState({
    this.isRunning = false,
    this.results   = const {},
  });
 
  bool get hasResults => results.isNotEmpty;
  bool get allSuccess => results.values.every((r) => r.success);
 
  BatchActionState copyWith({
    bool?                    isRunning,
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
 
  /// Claim daily reward for all [emails] concurrently.
  Future<void> claimDailyRewardAll(List<String> emails) async {
    state = const BatchActionState(isRunning: true, results: {});
 
    final results = await ref
        .read(gameServiceProvider)
        .claimDailyRewardAll(emails);
 
    state = BatchActionState(isRunning: false, results: results);
 
    // 🟢 Tell the SessionNotifier to refresh. This automatically pulls 
    // fresh AccountData for all dependent providers instantly!
    for (final entry in results.entries) {
      if (entry.value.success) {
        ref.read(sessionStateProvider(entry.key).notifier).refresh();
      }
    }
  }
 
  /// Repair car for multiple accounts concurrently.
  /// [emailToCarId] maps each email to its primary car ID.
  Future<void> repairCarAll(Map<String, String> emailToCarId) async {
    state = const BatchActionState(isRunning: true, results: {});
 
    // Uncomment and implement when your backend logic is ready
    // final results = await ref
    //     .read(gameServiceProvider)
    //     .repairCarAll(emailToCarId); 
    
    // 🟢 Temporarily an empty map instead of `null` so `.entries` below doesn't crash
    final results = <String, BatchResult>{}; 
 
    state = BatchActionState(isRunning: false, results: results);
 
    // 🟢 Refresh session state instead of invalidating a FutureProvider
    for (final entry in results.entries) {
      if (entry.value.success) {
        ref.read(sessionStateProvider(entry.key).notifier).refresh();
      }
    }
  }
 
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

/// Per-account drivers, synchronously pulled from the cached AccountData
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