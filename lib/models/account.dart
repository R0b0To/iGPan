/// Represents a stored iGP Manager account.
/// Pure data — no HTTP calls, no service logic.
class Account {
  final String email;
  final String password;   // stored encrypted via flutter_secure_storage
  final String nickname;   // user-given label (e.g. "Main", "Alt1")
  final bool   enabled;    // whether to show in carousel and auto-refresh

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

  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      email:    json['email']    as String,
      password: json['password'] as String,
      nickname: json['nickname'] as String,
      enabled:  json['enabled']  as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'email':    email,
    'password': password,
    'nickname': nickname,
    'enabled':  enabled,
  };

  @override
  String toString() => 'Account($nickname / $email, enabled: $enabled)';
}
