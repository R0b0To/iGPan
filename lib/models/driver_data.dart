/// Driver stats parsed from the fireUp preCache → p=staff → vars.drivers HTML.
///
/// The `data-driver` attribute contains comma-separated values in this order:
/// overall, talent, fastCorner, slowCorner, defense, attack, composure,
/// experience, focus, morale, knowledge, stamina, health, height, bmi, age
class DriverData {
  final String id;
  final String firstName;
  final String lastName;
  final String imageUrl;
 
  // ─── Skills (from data-driver) ──────────────────────────
  final int overall;
  final int talent;
  final int fastCorner;
  final int slowCorner;
  final int defense;
  final int attack;
  final int composure;
  final int experience;
  final int focus;
  final int morale;
  final int knowledge;
  final int stamina;
  final int health;       // 0-100
  final int heightCm;     // used for setup suggestion height adjustment
  final double bmi;
  final int age;
 
  // ─── Contract / salary ──────────────────────────────────
  final String contractRaces; // e.g. "44 race(s)" or "44 gara/e"
  final String salary;        // e.g. "1m"
 
  // ─── Special ability ────────────────────────────────────
  final String specialAbility; // e.g. "Wet weather"
  final int    stars;          // 1-5 (parsed from ratingStar count)
 
  const DriverData({
    required this.id,
    required this.firstName,
    required this.lastName,
    required this.imageUrl,
    required this.overall,
    required this.talent,
    required this.fastCorner,
    required this.slowCorner,
    required this.defense,
    required this.attack,
    required this.composure,
    required this.experience,
    required this.focus,
    required this.morale,
    required this.knowledge,
    required this.stamina,
    required this.health,
    required this.heightCm,
    required this.bmi,
    required this.age,
    required this.contractRaces,
    required this.salary,
    required this.specialAbility,
    required this.stars,
  });
 
  String get fullName => '$firstName $lastName'.trim();

  // ─── Contract helpers ────────────────────────────────────

  /// Numeric races remaining on the current contract.
  ///
  /// Parses the first integer in [contractRaces] which may be
  /// "44 race(s)", "44 gara/e", or any localised variant.
  int get contractRacesNum {
    final m = RegExp(r'(\d+)').firstMatch(contractRaces);
    return int.tryParse(m?.group(1) ?? '') ?? 0;
  }

  /// True when the contract expires within the next 3 races.
  bool get isContractExpiringSoon =>
      contractRacesNum > 0 && contractRacesNum <= 3;

  /// Contract colour tier (mirrors StaffMember logic).
  bool get isContractExpiring => contractRacesNum > 3 && contractRacesNum <= 10;
  bool get isContractSafe     => contractRacesNum > 10;
 
  /// Parse both drivers from the staff page drivers HTML block.
  /// Returns a list of up to 2 DriverData objects.
  static List<DriverData> parseFromStaffHtml(String html) {
    if (html.isEmpty) return [];
 
    final drivers = <DriverData>[];
 
    // Each driver has a hoverData span with data-driver attribute
    final hoverRe = RegExp(
      r'data-driver="([^"]+)"[^>]*data-append="([^"]*)"',
      dotAll: true,
    );
    final hoverMatches = hoverRe.allMatches(html).toList();
 
    // Driver IDs from href="d=driver&id=..."
    final idRe = RegExp(r'd=driver&(?:amp;)?id=(\d+)');
    final idMatches = idRe.allMatches(html).toList();
 
    // Driver names from driverName div
    final nameRe = RegExp(
      r'<div class="driverName[^"]*">([^<]+)<br><span[^>]*>([^<]+)</span>',
      dotAll: true,
    );
    final nameMatches = nameRe.allMatches(html).toList();
 
    // Image URLs
    final imgRe = RegExp(r'<img src="(https://static\.igpmanager\.com/igp/rpm/[^"]+)"');
    final imgMatches = imgRe.allMatches(html).toList();
 
    // Contract and salary rows from the stats table
    // Row order: stars, ability%, mental%, health, contract, salary
    final contractRe = RegExp(r'(\d+ gara/e|\d+ race\(s\))');
    final contractMatches = contractRe.allMatches(html).toList();
 
    final salaryRe = RegExp(
      r'icon-24[^>]*/>\s*([\d.,]+[km]?)\s*</td>',
      dotAll: true,
    );
    final salaryMatches = salaryRe.allMatches(html).toList();
 
    for (var i = 0; i < hoverMatches.length && i < 2; i++) {
      final stats = hoverMatches[i].group(1)?.split(',') ?? [];
      final appendHtml = hoverMatches[i].group(2) ?? '';
 
      if (stats.length < 16) continue;
 
      int s(int idx) => int.tryParse(stats[idx].trim()) ?? 0;
 
      final specialAbility = _parseSpecialAbility(appendHtml);
      final stars          = _parseStars(html, i);
 
      drivers.add(DriverData(
        id:           idMatches.length > i ? idMatches[i].group(1) ?? '' : '',
        firstName:    nameMatches.length > i
            ? _stripHtml(nameMatches[i].group(1) ?? '').trim() : '',
        lastName:     nameMatches.length > i
            ? nameMatches[i].group(2)?.trim() ?? '' : '',
        imageUrl:     imgMatches.length > i
            ? imgMatches[i].group(1) ?? '' : '',
        overall:      s(0),
        talent:       s(1),
        fastCorner:   s(2),
        slowCorner:   s(3),
        defense:      s(4),
        attack:       s(5),
        composure:    s(6),
        experience:   s(7),
        focus:        s(8),
        morale:       s(9),
        knowledge:    s(10),
        stamina:      s(11),
        health:       s(12),
        heightCm:     s(13),
        bmi:          double.tryParse(stats[14].trim()) ?? 0.0,
        age:          s(15),
        contractRaces: contractMatches.length > i
            ? contractMatches[i].group(0) ?? '' : '',
        salary:        _parseSalary(html, i),
        specialAbility: specialAbility,
        stars:          stars,
      ));
    }
 
    return drivers;
  }
 
  static String _parseSpecialAbility(String appendHtml) {
    // appendHtml looks like: "<span class='specialA1 tooltip' data-tip='Common'>Wet weather</span>"
    final m = RegExp(r"'>([^<]+)</span>").firstMatch(appendHtml);
    return m?.group(1)?.trim() ?? '';
  }
 
  static int _parseStars(String html, int driverIndex) {
    // Count filled stars in the i-th ratingStar span
    final starRe = RegExp(r'<span class="ratingStar in">(.*?)</span>', dotAll: true);
    final matches = starRe.allMatches(html).toList();
    if (matches.length <= driverIndex) return 0;
    final block = matches[driverIndex].group(1) ?? '';
    // Count <icon>star</icon> (full) vs <icon>star-half-empty</icon>
    final full  = RegExp(r'<icon[^>]*>star</icon>').allMatches(block).length;
    return full; // return whole stars; half is bonus info
  }
 
  static String _parseSalary(String html, int driverIndex) {
    // Salary rows contain cash icon followed by amount
    final re = RegExp(r'icon-24[^/]*/>([\d.,]+[km]?)</td>');
    final matches = re.allMatches(html).toList();
    if (matches.length <= driverIndex) return '';
    return matches[driverIndex].group(1)?.trim() ?? '';
  }
 
  static String _stripHtml(String s) =>
      s.replaceAll(RegExp(r'<[^>]*>'), '').trim();
 
  @override
  String toString() =>
      'Driver($fullName, H:${heightCm}cm, overall:$overall, age:$age, '
      'contract:$contractRacesNum races)';
}