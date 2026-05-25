class AppConfig {
  AppConfig._();

  // ─── Server ───────────────────────────────────────────────
  static const String baseUrl = 'https://igpmanager.com';

  // ─── Auth endpoints ───────────────────────────────────────
  static const String loginEndpoint =
      '/index.php?action=send&addon=igp&type=login&jsReply=login&ajax=1';

  /// Returns full account state: team, manager, preCache pages, notify, csrf
  static const String fireUpEndpoint =
      '/index.php?action=fireUp&addon=igp&ajax=1&jsReply=fireUp&uwv=false';

  // ─── Race endpoints ───────────────────────────────────────
  /// Returns {vars: {...}, page: "..."} — all race/setup/strategy data
  static const String raceEndpoint =
      '/index.php?action=fetch&p=race&csrfName=&csrfToken=';

  // ─── Game action endpoints ────────────────────────────────
  /// Daily reward — GET, no params
  static const String dailyRewardEndpoint =
      '/content/misc/igp/ajax/dailyReward.php';

  /// Repair car parts — append &car={carId}&btn=c{n}PartSwap
  static const String repairPartsBase =
      '/index.php?action=send&type=fix&jsReply=fix&csrfName=&csrfToken=';

  /// Replace engine — append &car={carId}&btn=c{n}EngSwap
  static const String replaceEngineBase =
      '/index.php?action=send&type=engine&jsReply=fix&csrfName=&csrfToken=';

  /// Setup save (practice lap + save) — GET with query params
  static const String setupEndpoint =
      '/index.php?action=send&addon=igp&type=setup&ajax=1';

  // ─── Other endpoints ──────────────────────────────────────
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
  static const String saveAllEndpoint =
      '/index.php?action=send&type=saveAll&addon=igp&ajax=1&jsReply=saveAll&pageId=race';

  // ─── Timeouts ─────────────────────────────────────────────
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 30);
  static const Duration sendTimeout    = Duration(seconds: 15);

  // ─── Session ──────────────────────────────────────────────
  static const Duration sessionDuration = Duration(hours: 24);

  // ─── Misc ─────────────────────────────────────────────────
  static const bool enableDioLogging = true;
}

  // Added: saveAll endpoint — saves setup + strategy in one POST
  // POST body: JSON map with keys d1setup, d1strategy, d1strategyAdvanced, d2setup, d2st
