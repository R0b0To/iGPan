/// Represents a stored iGP Manager account.
/// Pure data — no HTTP calls, no service logic.
///
/// Passwords are NEVER written to the account list in secure storage.
/// They are persisted separately via SessionManager.saveCredential and
/// only live in memory on the [Account] instance returned by [addAccount].
class Account {
  final String email;

  /// In-memory only — stripped before any storage write.
  /// Loaded from SessionManager.getCredential on re-login.
  final String password;

  /// User-given label (e.g. "Main", "Alt1").
  final String nickname;

  /// Whether to show this account in the carousel and auto-refresh.
  final bool enabled;

  const Account({
    required this.email,
    required this.password,
    required this.nickname,
    this.enabled = true,
  });

  Account copyWith({
    String? email,
    String? password,
    String? nickname,
    bool?   enabled,
  }) {
    return Account(
      email:    email    ?? this.email,
      password: password ?? this.password,
      nickname: nickname ?? this.nickname,
      enabled:  enabled  ?? this.enabled,
    );
  }

  /// Deserialise from stored JSON.
  /// [password] is never in the stored JSON — always returns empty string.
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      email:    json['email']    as String,
      password: '',               // never stored; fetched from credential vault
      nickname: json['nickname'] as String,
      enabled:  json['enabled']  as bool? ?? true,
    );
  }

  /// Serialise for storage — password intentionally omitted.
  Map<String, dynamic> toJson() => {
    'email':    email,
    'nickname': nickname,
    'enabled':  enabled,
    // 'password' is intentionally excluded — stored separately in the
    // credential vault via SessionManager.saveCredential.
  };

  @override
  String toString() => 'Account($nickname / $email, enabled: $enabled)';
}