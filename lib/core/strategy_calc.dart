import 'dart:math' as math;

/// One stint — compound, laps, fuel.
/// Used both in the inline race card UI and by the batch auto-setup action.
class StrategyStint {
  String tyre;
  int    laps;
  double fuelPerLap;
  int    fuel;

  StrategyStint({
    this.tyre       = 'M',
    this.laps       = 7,
    this.fuelPerLap = 0.0,
    int? explicitFuel,
  }) : fuel = explicitFuel ?? (laps * fuelPerLap).ceil().clamp(1, 300);

  Map<String, dynamic> toMap() => {
    'tyre':       tyre,
    'laps':       laps,
    'fuel':       fuel,
    'fuelPerLap': fuelPerLap,
  };
}

/// Strategy and setup-suggestion maths shared across the app.
///
/// Key improvement over the previous greedy algorithm:
///   • For each candidate compound sequence, we first compute how many laps
///     each tyre can safely run before dropping below [_targetWearPct] (40 %).
///   • Laps are then distributed *proportionally* to that safe capacity, so
///     harder compounds that last longer automatically receive more laps.
///   • Any sequence whose combined safe capacity is less than the race distance
///     is rejected outright — the algorithm adds another stint instead.
///   • The two-tyre rule is integral from the start: sequences with only one
///     compound are excluded when the rule is active, not patched afterward.
class StrategyCalc {
  StrategyCalc._();

  // ── Compounds considered for dry-weather strategies ───────────────────────
  static const _dryTyres = ['SS', 'S', 'M', 'H'];

  /// Target minimum wear at the end of each stint.
  /// Stints that drop below this are penalised; the absolute floor is 15 %.
  static const double _targetWearPct = 40.0;

  // ── Per-lap pace cost relative to SS (used for scoring only) ─────────────
  static const _tyrePace = {'SS': 0.0, 'S': 0.3, 'M': 0.6, 'H': 0.9};

  // ── Track data ────────────────────────────────────────────────────────────
  static const trackInfo = {
    'au': {'length': 5.3017135,  'wear': 40, 'pit': 24.0},
    'my': {'length': 5.5358276,  'wear': 80, 'pit': 22.0},
    'cn': {'length': 5.4417996,  'wear': 80, 'pit': 26.0},
    'bh': {'length': 4.7273,     'wear': 60, 'pit': 23.0},
    'es': {'length': 4.4580207,  'wear': 85, 'pit': 25.0},
    'mc': {'length': 4.0156865,  'wear': 20, 'pit': 16.0},
    'tr': {'length': 5.1630893,  'wear': 90, 'pit': 18.0},
    'de': {'length': 4.1797523,  'wear': 50, 'pit': 17.0},
    'hu': {'length': 3.4990127,  'wear': 30, 'pit': 17.0},
    'eu': {'length': 5.5907145,  'wear': 45, 'pit': 17.0},
    'be': {'length': 7.0406127,  'wear': 60, 'pit': 15.0},
    'it': {'length': 5.4024186,  'wear': 35, 'pit': 24.0},
    'sg': {'length': 5.049042,   'wear': 45, 'pit': 20.0},
    'jp': {'length': 5.0587635,  'wear': 70, 'pit': 20.0},
    'br': {'length': 3.9715014,  'wear': 60, 'pit': 21.0},
    'ae': {'length': 5.412688,   'wear': 50, 'pit': 23.0},
    'gb': {'length': 5.75213,    'wear': 65, 'pit': 23.0},
    'fr': {'length': 5.882508,   'wear': 80, 'pit': 20.0},
    'at': {'length': 4.044372,   'wear': 60, 'pit': 27.0},
    'ca': {'length': 4.3413563,  'wear': 45, 'pit': 17.0},
    'az': {'length': 6.053212,   'wear': 45, 'pit': 17.0},
    'mx': {'length': 4.3076024,  'wear': 60, 'pit': 19.0},
    'ru': {'length': 6.078335,   'wear': 50, 'pit': 21.0},
    'us': {'length': 4.60296,    'wear': 65, 'pit': 16.0},
    'nl': {'length': 4.259,      'wear': 65, 'pit': 18.0},
  };

  static const raceLengthMap = {
    'ae': [50, 37, 25, 12], 'au': [57, 42, 28, 14], 'at': [68, 51, 34, 17],
    'az': [46, 34, 23, 11], 'bh': [59, 44, 29, 14], 'be': [43, 32, 21, 10],
    'br': [69, 51, 34, 17], 'ca': [63, 47, 31, 15], 'cn': [55, 41, 27, 13],
    'eu': [50, 37, 25, 12], 'fr': [48, 36, 24, 12], 'de': [67, 50, 33, 16],
    'jp': [55, 41, 27, 13], 'gb': [48, 36, 24, 12], 'it': [51, 38, 25, 12],
    'my': [55, 41, 27, 13], 'mx': [70, 52, 35, 17], 'mc': [59, 44, 29, 14],
    'ru': [46, 34, 23, 11], 'sg': [60, 45, 30, 15], 'es': [62, 46, 31, 15],
    'us': [60, 45, 30, 15], 'tr': [54, 40, 27, 13], 'hu': [79, 59, 39, 19],
    'nl': [72, 59, 36, 19],
  };

  static const tyreWearFactors = {
    'SS': 2.14, 'S': 1.4, 'M': 1.0, 'H': 0.78, 'I': 1.0, 'W': 1.0,
  };
  static const _multipliers = {100: 1.0, 75: 1.25, 50: 1.5, 25: 3.0};

  // ── Public helpers ────────────────────────────────────────────────────────

  static double getPushModifier(int pushLevel) => switch (pushLevel) {
    20 => -0.007, 40 => -0.004, 60 => 0.0, 80 => 0.01, 100 => 0.02,
    _  => 0.0,
  };

  static double getFuelPerLap(int fuelAttr, String trackCode, int pushLevel) {
    if (fuelAttr <= 0) fuelAttr = 1;
    final track = trackInfo[trackCode.toLowerCase()];
    if (track == null) return 2.0;
    final length    = track['length'] as double;
    final fuelPerKm = 0.6983736841 * math.pow(fuelAttr, -0.08510976572);
    return fuelPerKm * length * (1.0 + getPushModifier(pushLevel));
  }

  static int getLeagueLengthKey(String trackCode, int raceLaps) {
    final arr = raceLengthMap[trackCode.toLowerCase()];
    if (arr == null) return 100;
    for (int i = 0; i < arr.length; i++) {
      if ((arr[i] - raceLaps).abs() <= 2) return [100, 75, 50, 25][i];
    }
    return 100;
  }

  static double getTyreWearPercentage({
    required int    teAttr,
    required String trackCode,
    required String tyre,
    required int    laps,
    required int    raceLaps,
  }) {
    if (teAttr <= 0) teAttr = 1;
    final track = trackInfo[trackCode.toLowerCase()];
    if (track == null) return 100.0;

    final trackWear   = (track['wear'] as num).toDouble();
    final trackLength = track['length'] as double;
    final mult        = _multipliers[getLeagueLengthKey(trackCode, raceLaps)] ?? 1.0;
    final wearFactor  = tyreWearFactors[tyre] ?? 1.0;

    final t = (1.29 * math.pow(teAttr, -0.0696)) *
              (0.00527 * trackWear + 0.556) *
              trackLength * mult * wearFactor;

    return (math.pow(math.e, (-t / 100 * 1.18) * laps) * 100)
        .clamp(0.0, 100.0)
        .toDouble();
  }

  // ── Strategy optimiser ────────────────────────────────────────────────────

  /// Returns the best strategy for the given race conditions.
  ///
  /// When [twoTyreRule] is true the result is guaranteed to contain at least
  /// two distinct compounds, using extra stints where necessary — not a
  /// post-hoc swap of the last stint.
  ///
  /// How it works:
  ///   1. Pre-compute [_maxSafeLaps] per compound: the maximum laps before
  ///      tyre wear drops below [_targetWearPct] (40 %).
  ///   2. Enumerate every compound sequence of length 1–5 stints.
  ///      Sequences with all-same compound are excluded when [twoTyreRule].
  ///   3. Skip sequences whose total safe capacity is less than [raceLaps]:
  ///      the compounds simply can't cover the race even at maximum duration.
  ///   4. Distribute laps *proportionally to safe capacity* so harder tyres
  ///      (larger capacity) receive more laps and every stint naturally stays
  ///      near [_targetWearPct].
  ///   5. Score by: pit-stop time + per-lap pace penalty + soft wear penalty.
  ///   6. Return the lowest-scoring valid strategy.
  static List<StrategyStint> getOptimalStrategy({
    required int    raceLaps,
    required double fuelPerLap,
    required int    teAttr,
    required String trackCode,
    required bool   refuelling,
    bool twoTyreRule = false,
  }) {
    final track   = trackInfo[trackCode.toLowerCase()];
    final pitTime = (track?['pit'] as double?) ?? 22.0;

    // Step 1 — maximum safe laps per compound at the 40 % wear target.
    final safeLaps = {
      for (final t in _dryTyres)
        t: _maxSafeLaps(
            teAttr: teAttr, trackCode: trackCode,
            tyre: t, raceLaps: raceLaps),
    };

    final minStints = twoTyreRule ? 2 : 1;
    // Cap at 5; require at least enough stints to cover the distance.
    final minRequired = _minStintsNeeded(raceLaps, safeLaps);
    final minN   = math.max(minStints, minRequired);
    final maxN   = math.min(5, math.max(minN, (raceLaps / 8).ceil()));

    List<StrategyStint>? best;
    double bestScore = double.infinity;

    for (int n = minN; n <= maxN; n++) {
      for (final seq in _compoundSequences(n, twoTyreRule)) {
        // Step 3 — reject if any compound has zero safe laps.
        final caps = seq.map((t) => safeLaps[t]!).toList();
        if (caps.any((c) => c == 0)) continue;

        final totalCap = caps.fold(0, (a, b) => a + b);
        if (totalCap < raceLaps) continue;

        // Step 4 — proportional lap distribution.
        final laps = _distributeLaps(raceLaps, caps);

        // Step 5 — scoring.
        double score = (n - 1) * pitTime;
        bool   valid = true;

        for (int i = 0; i < n; i++) {
          if (laps[i] <= 0) { valid = false; break; }

          final wear = getTyreWearPercentage(
            teAttr: teAttr, trackCode: trackCode,
            tyre: seq[i], laps: laps[i], raceLaps: raceLaps,
          );

          // Absolute floor: tyre destroyed, discard this sequence.
          if (wear < 15.0) { valid = false; break; }

          // Per-lap pace disadvantage vs SS.
          score += laps[i] * (_tyrePace[seq[i]] ?? 0.9);

          // Graduated penalty for running below the 40 % target.
          // Each percentage point below the target costs 1.5 score units.
          if (wear < _targetWearPct) {
            score += (_targetWearPct - wear) * 1.5;
          }
        }

        if (valid && score < bestScore) {
          bestScore = score;
          best = _makeStints(seq, laps, fuelPerLap, refuelling);
        }
      }
    }

    return best ??
        _fallbackStrategy(raceLaps, fuelPerLap, refuelling, twoTyreRule);
  }

  // ── Private: safe-lap computation ─────────────────────────────────────────

  /// Binary-search for the highest lap count where wear ≥ [_targetWearPct].
  /// Returns 0 when even 1 lap drops below the threshold.
  static int _maxSafeLaps({
    required int    teAttr,
    required String trackCode,
    required String tyre,
    required int    raceLaps,
  }) {
    // Guard: 1 lap already below threshold?
    if (getTyreWearPercentage(
          teAttr: teAttr, trackCode: trackCode,
          tyre: tyre, laps: 1, raceLaps: raceLaps) < _targetWearPct) {
      return 0;
    }

    int lo = 1, hi = raceLaps;
    while (lo < hi) {
      final mid  = (lo + hi + 1) ~/ 2;
      final wear = getTyreWearPercentage(
          teAttr: teAttr, trackCode: trackCode,
          tyre: tyre, laps: mid, raceLaps: raceLaps);
      if (wear >= _targetWearPct) lo = mid; else hi = mid - 1;
    }
    return lo;
  }

  /// Minimum number of stints to cover [raceLaps] given [safeLaps] per tyre.
  /// Uses the hardest (longest-lasting) compound to get a lower bound.
  static int _minStintsNeeded(int raceLaps, Map<String, int> safeLaps) {
    final best = safeLaps.values.fold(1, math.max);
    if (best <= 0) return 5;
    return (raceLaps / best).ceil().clamp(1, 5);
  }

  // ── Private: lap distribution ─────────────────────────────────────────────

  /// Distribute [total] laps across stints proportionally to [caps].
  /// The sum is guaranteed to equal [total].
  static List<int> _distributeLaps(int total, List<int> caps) {
    final capSum = caps.fold(0, (a, b) => a + b);
    final laps   = List<int>.generate(
        caps.length, (i) => (total * caps[i] / capSum).floor());

    // Assign remainder to the stints with the most unused safe capacity.
    int rem = total - laps.fold(0, (a, b) => a + b);
    if (rem > 0) {
      final indices = List<int>.generate(caps.length, (i) => i)
        ..sort((a, b) => (caps[b] - laps[b]).compareTo(caps[a] - laps[a]));
      for (final i in indices) {
        if (rem <= 0) break;
        laps[i]++;
        rem--;
      }
    }
    return laps;
  }

  // ── Private: sequence enumeration ─────────────────────────────────────────

  /// All dry-compound sequences of length [n].
  /// When [twoRequired] is true only sequences with ≥ 2 distinct compounds
  /// are included — enforced at generation time, not as a post-hoc filter.
  static List<List<String>> _compoundSequences(int n, bool twoRequired) {
    final out = <List<String>>[];
    _buildSeq(_dryTyres, n, twoRequired, <String>[], out);
    return out;
  }

  static void _buildSeq(
    List<String> pool, int rem, bool twoRequired,
    List<String> cur, List<List<String>> out,
  ) {
    if (rem == 0) {
      if (!twoRequired || cur.toSet().length >= 2) out.add(List<String>.from(cur));
      return;
    }
    for (final t in pool) {
      cur.add(t);
      _buildSeq(pool, rem - 1, twoRequired, cur, out);
      cur.removeLast();
    }
  }

  // ── Private: stint construction ───────────────────────────────────────────

  static List<StrategyStint> _makeStints(
    List<String> seq, List<int> laps,
    double fuelPerLap, bool refuelling,
  ) =>
      List.generate(seq.length, (i) => StrategyStint(
        tyre:         seq[i],
        laps:         laps[i],
        fuelPerLap:   fuelPerLap,
        explicitFuel: refuelling ? (laps[i] * fuelPerLap).ceil() : null,
      ));

  /// Conservative last-resort strategy when the optimiser finds nothing.
  static List<StrategyStint> _fallbackStrategy(
    int raceLaps, double fuelPerLap, bool refuelling, bool twoTyreRule,
  ) {
    final tyres = twoTyreRule ? ['M', 'H'] : ['H', 'H', 'H'];
    final n     = tyres.length;
    final base  = raceLaps ~/ n;
    final rem   = raceLaps % n;
    return List.generate(n, (i) {
      final l = base + (i < rem ? 1 : 0);
      return StrategyStint(
        tyre:         tyres[i],
        laps:         l,
        fuelPerLap:   fuelPerLap,
        explicitFuel: refuelling ? (l * fuelPerLap).ceil() : null,
      );
    });
  }
}