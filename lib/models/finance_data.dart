/// Finance and sponsor data from the p=finances endpoint.
class FinanceData {
  final int    balance;
  final String seasonSponsors;    // e.g. "62,700,000"
  final String seasonPrizes;
  final String seasonWages;
  final String seasonCars;
  final String dailyTotal;
  final String seasonTotal;
  final List<SponsorInfo> sponsors;

  const FinanceData({
    required this.balance,
    required this.seasonSponsors,
    required this.seasonPrizes,
    required this.seasonWages,
    required this.seasonCars,
    required this.dailyTotal,
    required this.seasonTotal,
    required this.sponsors,
  });

  factory FinanceData.fromJson(Map<String, dynamic> json) {
    final vars = json['vars'] as Map<String, dynamic>? ?? {};

    // Sponsor names come clean in vars.s1Name / s2Name
    final s1Name = vars['s1Name']?.toString() ?? '';
    final s2Name = vars['s2Name']?.toString() ?? '';

    // Parse sponsor details from the HTML block
    final sponsorsHtml = vars['sponsors']?.toString() ?? '';
    final sponsors = _parseSponsors(sponsorsHtml, s1Name, s2Name);

    return FinanceData(
      balance:        int.tryParse(
        json['_balance']?.toString().replaceAll(',', '') ?? '0') ?? 0,
      seasonSponsors: _stripHtml(vars['sSponsors']?.toString() ?? ''),
      seasonPrizes:   _stripHtml(vars['sPrizes']?.toString()   ?? ''),
      seasonWages:    _stripHtml(vars['sWages']?.toString()    ?? ''),
      seasonCars:     _stripHtml(vars['sCars']?.toString()     ?? ''),
      dailyTotal:     _stripHtml(vars['dTotal']?.toString()    ?? ''),
      seasonTotal:    _stripHtml(vars['sTotal']?.toString()    ?? ''),
      sponsors:       sponsors,
    );
  }

  /// Parse sponsor cards from the HTML block.
  /// Uses the s1Name / s2Name from vars (already clean strings).
  static List<SponsorInfo> _parseSponsors(
      String html, String s1Name, String s2Name) {
    final sponsors = <SponsorInfo>[];

    // Extract each c-wrap block — one per sponsor
    final blockRe = RegExp(
      r'<div class="c-wrap[^"]*">(.*?)</div>\s*</div>\s*</div>',
      dotAll: true,
    );

    // Simpler approach: just extract rows from tables inside the HTML
    final tableRe = RegExp(
      r'<table[^>]*>(.*?)</table>',
      dotAll: true,
    );
    final rowRe = RegExp(r'<tr>(.*?)</tr>', dotAll: true);
    final cellRe = RegExp(r'<td[^>]*>(.*?)</td>', dotAll: true);

    final tables = tableRe.allMatches(html).toList();
    final names  = [s1Name, s2Name];

    for (var t = 0; t < tables.length && t < 2; t++) {
      final tableHtml = tables[t].group(1) ?? '';
      final rows = rowRe.allMatches(tableHtml).toList();

      String income = '';
      String bonus  = '';
      String contract = '';

      for (var r = 0; r < rows.length; r++) {
        final cells = cellRe
            .allMatches(rows[r].group(1) ?? '')
            .map((m) => _stripHtml(m.group(1) ?? ''))
            .toList();

        if (cells.length >= 2) {
          final label = cells[0].toLowerCase();
          final value = cells[1];
          if (label.contains('income'))   income   = value;
          if (label.contains('bonus'))    bonus    = value;
          if (label.contains('contract')) contract = value;
        }
      }

      // Image URL for sponsor logo
      final imgRe = RegExp(r'src="([^"]*sponsor[^"]*)"');
      final imgMatch = imgRe.firstMatch(html.substring(
        t == 0 ? 0 : html.length ~/ 2,
        t == 0 ? html.length ~/ 2 : html.length,
      ));
      final logoUrl = imgMatch?.group(1) ?? '';

      sponsors.add(SponsorInfo(
        name:          names.length > t ? names[t] : '',
        isPrimary:     t == 0,
        income:        income,
        bonus:         bonus,
        contractRaces: contract,
        logoUrl:       logoUrl,
      ));
    }

    return sponsors;
  }

  static String _stripHtml(String s) =>
      s.replaceAll(RegExp(r'<[^>]*>'), '').trim();
}

class SponsorInfo {
  final String name;
  final bool   isPrimary;
  final String income;
  final String bonus;
  final String contractRaces;
  final String logoUrl;

  const SponsorInfo({
    required this.name,
    required this.isPrimary,
    required this.income,
    required this.bonus,
    required this.contractRaces,
    required this.logoUrl,
  });

  String get label => isPrimary ? 'Primary' : 'Secondary';
}
