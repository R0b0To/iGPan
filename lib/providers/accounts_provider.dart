import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import 'providers.dart';

/// Reactive list of all stored accounts.
///
/// UI watches this to rebuild the pill rail and accounts screen.
/// Mutating methods (add, delete, toggle) update state and persist.
class AccountsNotifier extends AsyncNotifier<List<Account>> {
  @override
  Future<List<Account>> build() async {
    return ref.read(accountServiceProvider).getAccounts();
  }

  // ─── Add ──────────────────────────────────────────────────

  /// Login + persist a new account. Updates state on success.
  Future<void> addAccount({
    required String email,
    required String password,
    required String nickname,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      await ref.read(accountServiceProvider).addAccount(
        email:    email,
        password: password,
        nickname: nickname,
      );
      return ref.read(accountServiceProvider).getAccounts();
    });
  }

  // ─── Delete ───────────────────────────────────────────────

  Future<void> deleteAccount(String email) async {
    await ref.read(accountServiceProvider).deleteAccount(email);
    state = AsyncData(
      (state.valueOrNull ?? []).where((a) => a.email != email).toList(),
    );
  }

  // ─── Enable / disable ─────────────────────────────────────

  Future<void> setEnabled(String email, {required bool enabled}) async {
    await ref.read(accountServiceProvider).setEnabled(email, enabled: enabled);
    state = AsyncData(
      (state.valueOrNull ?? []).map((a) {
        return a.email == email ? a.copyWith(enabled: enabled) : a;
      }).toList(),
    );
  }

  // ─── Rename ───────────────────────────────────────────────

  Future<void> renameAccount(String email, String nickname) async {
    await ref.read(accountServiceProvider).renameAccount(email, nickname);
    state = AsyncData(
      (state.valueOrNull ?? []).map((a) {
        return a.email == email ? a.copyWith(nickname: nickname) : a;
      }).toList(),
    );
  }

  // ─── Reorder ──────────────────────────────────────────────

  Future<void> reorder(List<Account> reordered) async {
    await ref.read(accountServiceProvider).reorderAccounts(reordered);
    state = AsyncData(reordered);
  }

  // ─── Refresh ──────────────────────────────────────────────

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = AsyncData(
      await ref.read(accountServiceProvider).getAccounts(),
    );
  }
}

final accountsProvider =
    AsyncNotifierProvider<AccountsNotifier, List<Account>>(
  AccountsNotifier.new,
);

/// Convenience: only enabled accounts.
final enabledAccountsProvider = Provider<List<Account>>((ref) {
  return ref
      .watch(accountsProvider)
      .valueOrNull
      ?.where((a) => a.enabled)
      .toList() ?? [];
});
