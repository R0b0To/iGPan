import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account.dart';
import 'accounts_provider.dart';

// ─── Selected account ─────────────────────────────────────────────────────────

/// The currently active account in the dashboard pill rail.
/// Defaults to the first enabled account.
class SelectedAccountNotifier extends Notifier<String?> {
  @override
  String? build() {
    // Auto-select first enabled account when the list loads
    final enabled = ref.watch(enabledAccountsProvider);

    if (enabled.isNotEmpty) {
      return enabled.first.email;
    }

    return null;
  }

  void select(String email) => state = email;

  void clear() => state = null;
}

final selectedAccountProvider =
    NotifierProvider<SelectedAccountNotifier, String?>(
  SelectedAccountNotifier.new,
);

// ─── Batch selection mode ─────────────────────────────────────────────────────

/// Tracks which accounts are selected for batch actions.
///
/// Empty set = single-account mode (normal dashboard).
/// Non-empty  = batch mode (blue bar, action buttons).
class BatchSelectionNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String email) {
    final current = Set<String>.from(state);
    if (current.contains(email)) {
      current.remove(email);
    } else {
      current.add(email);
    }
    state = current;
  }

  void selectAll(List<Account> accounts) {
    state = accounts.map((a) => a.email).toSet();
  }

  void clear() => state = {};

  bool isSelected(String email) => state.contains(email);

  bool get isActive => state.isNotEmpty;
}

final batchSelectionProvider =
    NotifierProvider<BatchSelectionNotifier, Set<String>>(
  BatchSelectionNotifier.new,
);

/// Convenience: selected Account objects in batch order.
final batchSelectedAccountsProvider = Provider<List<Account>>((ref) {
  final selected = ref.watch(batchSelectionProvider);
  final all      = ref.watch(accountsProvider).valueOrNull ?? [];
  return all.where((a) => selected.contains(a.email)).toList();
});
