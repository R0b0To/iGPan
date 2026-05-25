import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/session_manager.dart';
import '../network/http_client.dart';
import '../services/account_service.dart';
import '../services/auth_service.dart';
import '../services/finance_service.dart';
import '../services/race_service.dart';

/// Single HttpClient instance — already initialized in main().
final httpClientProvider = Provider<HttpClient>((_) => HttpClient());

/// Single SessionManager instance.
final sessionManagerProvider = Provider<SessionManager>((_) => SessionManager());

/// AuthService wired to shared HttpClient + SessionManager.
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService(
    httpClient:     ref.watch(httpClientProvider),
    sessionManager: ref.watch(sessionManagerProvider),
  );
});

/// AccountService wired to shared dependencies.
final accountServiceProvider = Provider<AccountService>((ref) {
  return AccountService(
    sessionManager: ref.watch(sessionManagerProvider),
    authService:    ref.watch(authServiceProvider),
    httpClient:     ref.watch(httpClientProvider),
  );
});

/// RaceService wired to shared HttpClient.
final raceServiceProvider = Provider<RaceService>((ref) {
  return RaceService(httpClient: ref.watch(httpClientProvider));
});


/// FinanceService wired to shared HttpClient.
final financeServiceProvider = Provider<FinanceService>((ref) {
  return FinanceService(httpClient: ref.watch(httpClientProvider));
});
