import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/account_data.dart';
import '../models/session.dart';
import 'providers.dart';

/// Per-account session state — validated against the server via fireUp.
///
/// Usage:
///   ref.watch(sessionStateProvider('user@example.com'))
///
/// Returns [SessionState] which holds both the [Session] metadata
/// and the live [AccountData] fetched from fireUp.
class SessionState {
  final Session?     session;
  final AccountData? accountData;
  final bool         isValidating;
  final String?      error;

  const SessionState({
    this.session,
    this.accountData,
    this.isValidating = false,
    this.error,
  });

  bool get isValid      => session != null && session!.isValid && accountData != null;
  bool get isExpired    => session == null || session!.isExpired;
  bool get needsReLogin => isExpired || (accountData?.isGuest ?? true);

  SessionState copyWith({
    Session?     session,
    AccountData? accountData,
    bool?        isValidating,
    String?      error,
  }) {
    return SessionState(
      session:      session      ?? this.session,
      accountData:  accountData  ?? this.accountData,
      isValidating: isValidating ?? this.isValidating,
      error:        error        ?? this.error,
    );
  }
}

/// Family notifier — one per account email.
class SessionNotifier extends FamilyAsyncNotifier<SessionState, String> {
  @override
  Future<SessionState> build(String email) async {
    return _validate(email);
  }

  Future<SessionState> _validate(String email) async {
    debugPrint('[SessionNotifier] Validating session for $email');
    // Check local session first
    final session = await ref
        .read(sessionManagerProvider)
        .getSession(email);

    if (session == null || session.isExpired) {
      return const SessionState();
    }

    // Validate with server — fetches live AccountData
    final accountData = await ref
        .read(authServiceProvider)
        .validateSession(email);

    if (accountData == null) {
      // Cookie gone — clear local metadata
      await ref.read(sessionManagerProvider).clearSession(email);
      return const SessionState();
    }

    return SessionState(session: session, accountData: accountData);
  }

  /// Re-validate (e.g. after app foreground).
  Future<void> refresh() async {
    debugPrint('[SessionNotifier] Refreshing session for ${arg}');
    state = const AsyncLoading();
    state = await AsyncValue.guard(() => _validate(arg));
  }

  /// Called after a successful login to update state immediately.
  Future<void> onLoginSuccess(Session session, String email) async {
    debugPrint('[SessionNotifier] Login success for $email, updating session state');
    final accountData = await ref
        .read(authServiceProvider)
        .validateSession(email);

    state = AsyncData(
      SessionState(session: session, accountData: accountData),
    );
  }

  /// Clear state (logout).
  void invalidate() {
    state = const AsyncData(SessionState());
  }
}

final sessionStateProvider = AsyncNotifierProviderFamily<
    SessionNotifier, SessionState, String>(
  SessionNotifier.new,
);

/// Convenience: just the AccountData for a given email, or null.
final accountDataProvider = Provider.family<AccountData?, String>((ref, email) {
  return ref
      .watch(sessionStateProvider(email))
      .valueOrNull
      ?.accountData;
});
