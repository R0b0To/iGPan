class AppConfig {
  AppConfig._();

  // ─── Server ───────────────────────────────────────────────
  static const String baseUrl  = 'https://igpmanager.com';
  static const String homePage = 'https://igpmanager.com/app/';

  // ─── Auth endpoints ───────────────────────────────────────
  static const String loginEndpoint =
      '/index.php?action=send&addon=igp&type=login&jsReply=login&ajax=1';

  /// Returns full account state: team, manager, preCache pages, notify, csrf.
  static const String fireUpEndpoint =
      '/index.php?action=fireUp&addon=igp&ajax=1&jsReply=fireUp&uwv=false';

  // ─── Race endpoints ───────────────────────────────────────
  static const String raceEndpoint =
      '/index.php?action=fetch&p=race&csrfName=&csrfToken=';

  // ─── Save all ─────────────────────────────────────────────
  /// Saves setup + strategy for both cars in one POST.
  /// Body: JSON map with keys d1setup, d1strategy, d1strategyAdvanced,
  ///       d2setup, d2strategy, d2strategyAdvanced.
  static const String saveAllEndpoint =
      '/index.php?action=send&type=saveAll&addon=igp&ajax=1&jsReply=saveAll&pageId=race';

  // ─── Game action endpoints ────────────────────────────────
  static const String dailyRewardEndpoint =
      '/content/misc/igp/ajax/dailyReward.php';

  static const String repairPartsBase =
      '/index.php?action=send&type=fix&jsReply=fix&csrfName=&csrfToken=';

  static const String replaceEngineBase =
      '/index.php?action=send&type=engine&jsReply=fix&csrfName=&csrfToken=';

  static const String setupEndpoint =
      '/index.php?action=send&addon=igp&type=setup&ajax=1';

  // ─── Other fetch endpoints ────────────────────────────────
  static const String historyEndpoint =
      '/index.php?action=send&type=history&jsReply=scrollLoader&el=history&csrfName=&csrfToken=';

  static const String leagueEndpoint =
      '/index.php?action=fetch&p=league&csrfName=&csrfToken=';

  static const String raceReportEndpoint =
      '/index.php?action=fetch&d=result&tab=race&csrfName=&csrfToken=';

  static const String researchEndpoint =
      '/index.php?action=fetch&d=research&csrfName=&csrfToken=';

  static const String designEndpoint =
      '/index.php?action=fetch&d=design&csrfName=&csrfToken=';

  static const String sponsorEndpoint =
      '/index.php?action=fetch&d=sponsor&csrfName=&csrfToken=';

  // ─── Timeouts ─────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout    = Duration(seconds: 15);

  // ─── Session ──────────────────────────────────────────────
  static const Duration sessionDuration = Duration(hours: 24);

  // ─── Debug ────────────────────────────────────────────────
  static const bool enableDioLogging = true;
}