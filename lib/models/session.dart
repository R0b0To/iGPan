/// Represents authentication state for one account.
///
/// This server uses cookie-based auth — no bearer token in the response body.
/// [accessToken] is null for all current accounts.
/// The session cookie is managed by PersistCookieJar in HttpClient.
class Session {
  final String? accessToken;   // null = cookie-based auth
  final String? refreshToken;  // null = not supported by this server
  final DateTime expiresAt;
  final DateTime createdAt;

  const Session({
    this.accessToken,
    this.refreshToken,
    required this.expiresAt,
    required this.createdAt,
  });

  // ─── Computed ─────────────────────────────────────────────

  bool get isValid   => DateTime.now().isBefore(expiresAt);
  bool get isExpired => !isValid;

  Duration get timeRemaining => expiresAt.difference(DateTime.now());

  /// True when this session uses a Bearer token (future accounts).
  bool get isTokenBased  => accessToken != null;

  /// True when this session is authenticated via cookies (current server).
  bool get isCookieBased => accessToken == null;

  // ─── Serialisation ────────────────────────────────────────

  factory Session.fromJson(Map<String, dynamic> json) {
    return Session(
      accessToken:  json['accessToken']  as String?,
      refreshToken: json['refreshToken'] as String?,
      expiresAt:    DateTime.parse(json['expiresAt'] as String),
      createdAt:    DateTime.parse(
        json['createdAt'] as String? ??
            DateTime.now().toIso8601String(),
      ),
    );
  }

  Map<String, dynamic> toJson() => {
    'accessToken':  accessToken,
    'refreshToken': refreshToken,
    'expiresAt':    expiresAt.toIso8601String(),
    'createdAt':    createdAt.toIso8601String(),
  };

  Session copyWith({
    String?   accessToken,
    String?   refreshToken,
    DateTime? expiresAt,
    DateTime? createdAt,
  }) {
    return Session(
      accessToken:  accessToken  ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt:    expiresAt    ?? this.expiresAt,
      createdAt:    createdAt    ?? this.createdAt,
    );
  }

  @override
  String toString() =>
      'Session(cookieBased: $isCookieBased, valid: $isValid, '
      'expiresAt: $expiresAt)';
}
