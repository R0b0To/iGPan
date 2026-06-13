import 'dart:math' as math;

/// One stint in a race strategy — tyre choice, lap count, and fuel.
///
/// Shared between the inline race card UI (action_panel.dart) and the
/// batch "auto setup" action (game_provider.dart).
class StrategyStint {
  String tyre;
  int    laps;
  double fuelPerLap;
  int    fuel;

  StrategyStint({
    this.tyre = 'M',
    this.laps = 7,
    this.fuelPerLap = 0.0,
    int? explicitFuel,
  }) : fuel = explicitFuel ?? (laps * fuelPerLap).ceil().clamp(1, 300);

  Map<String, dynamic> toMap() => {
    'tyre': tyre,
    'laps': laps,
    'fuel': fuel,
    'fuelPerLap': fuelPerLap,
  };
}

/// Strategy / setup math shared across the app.
class StrategyCalc {
  static const trackInfo = {
    'au': {'length': 5.3017135, 'wear': 40, 'avg': 226.1090047, 'pit': 24.0},
    'my': {'length': 5.5358276, 'wear': 80, 'avg': 208.879, 'pit': 22.0},
    'cn': {'length': 5.4417996, 'wear': 80, 'avg': 207.975, 'pit': 26.0},
    'bh': {'length': 4.7273, 'wear': 60, 'avg': 184.933, 'pit': 23.0},
    'es': {'length': 4.4580207, 'wear': 85, 'avg': 189.212, 'pit': 25.0},
    'mc': {'length': 4.0156865, 'wear': 20, 'avg': 187.0, 'pit': 16.0},
    'tr': {'length': 5.1630893, 'wear': 90, 'avg': 196.0, 'pit': 18.0},
    'de': {'length': 4.1797523, 'wear': 50, 'avg': 215.227, 'pit': 17.0},
    'hu': {'length': 3.4990127, 'wear': 30, 'avg': 165.043, 'pit': 17.0},
    'eu': {'length': 5.5907145, 'wear': 45, 'avg': 199.05, 'pit': 17.0},
    'be': {'length': 7.0406127, 'wear': 60, 'avg': 217.7, 'pit': 15.0},
    'it': {'length': 5.4024186, 'wear': 35, 'avg': 263.107, 'pit': 24.0},
    'sg': {'length': 5.049042, 'wear': 45, 'avg': 187.0866142, 'pit': 20.0},
    'jp': {'length': 5.0587635, 'wear': 70, 'avg': 197.065, 'pit': 20.0},
    'br': {'length': 3.9715014, 'wear': 60, 'avg': 203.932, 'pit': 21.0},
    'ae': {'length': 5.412688, 'wear': 50, 'avg': 213.218309, 'pit': 23.0},
    'gb': {'length': 5.75213, 'wear': 65, 'avg': 230.552, 'pit': 23.0},
    'fr': {'length': 5.882508, 'wear': 80, 'avg': 215.1585366, 'pit': 20.0},
    'at': {'length': 4.044372, 'wear': 60, 'avg': 228.546, 'pit': 27.0},
    'ca': {'length': 4.3413563, 'wear': 45, 'avg': 221.357243, 'pit': 17.0},
    'az': {'length': 6.053212, 'wear': 45, 'avg': 220.409, 'pit': 17.0},
    'mx': {'length': 4.3076024, 'wear': 60, 'avg': 172.32, 'pit': 19.0},
    'ru': {'length': 6.078335, 'wear': 50, 'avg': 197.092, 'pit': 21.0},
    'us': {'length': 4.60296, 'wear': 65, 'avg': 186.568, 'pit': 16.0},
    'nl': {'length': 4.259, 'wear': 65, 'avg': 186.568, 'pit': 18.0},
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

  static const tyreWearFactors = { 'SS': 2.14, 'S': 1.4, 'M': 1.0, 'H': 0.78, 'I': 1.0, 'W': 1.0 };
  static const multipliers = { 100: 1.0, 75: 1.25, 50: 1.5, 25: 3.0 };

  static double getPushModifier(int pushLevel) {
    switch (pushLevel) {
      case 20: return -0.007;
      case 40: return -0.004;
      case 60: return 0.0;
      case 80: return 0.01;
      case 100: return 0.02;
      default: return 0.0;
    }
  }

  static double getFuelPerLap(int fuelAttr, String trackCode, int pushLevel) {
    if (fuelAttr <= 0) fuelAttr = 1;
    final track = trackInfo[trackCode.toLowerCase()];
    if (track == null) return 2.0;

    final length = track['length'] as double;
    final fuelPerKm = 0.6983736841 * math.pow(fuelAttr, -0.08510976572);
    final baseFuel = fuelPerKm * length;

    return baseFuel * (1.0 + getPushModifier(pushLevel));
  }

  static int getLeagueLengthKey(String trackCode, int raceLaps) {
    final lapsArr = raceLengthMap[trackCode.toLowerCase()];
    if (lapsArr == null) return 100;
    for (int i = 0; i < lapsArr.length; i++) {
      if ((lapsArr[i] - raceLaps).abs() <= 2) {
        return [100, 75, 50, 25][i];
      }
    }
    return 100;
  }

  static double getTyreWearPercentage({
    required int teAttr,
    required String trackCode,
    required String tyre,
    required int laps,
    required int raceLaps,
  }) {
    if (teAttr <= 0) teAttr = 1;
    final track = trackInfo[trackCode.toLowerCase()];
    if (track == null) return 100.0;

    final trackWear = (track['wear'] as num).toDouble();
    final trackLength = track['length'] as double;

    final multKey = getLeagueLengthKey(trackCode, raceLaps);
    final mult = multipliers[multKey] ?? 1.0;
    final wearFactor = tyreWearFactors[tyre] ?? 1.0;

    final t = (1.29 * math.pow(teAttr, -0.0696)) *
              (0.00527 * trackWear + 0.556) *
              trackLength *
              mult *
              wearFactor;

    final stintWearLeft = math.pow(math.e, (-t / 100 * 1.18) * laps) * 100;
    return stintWearLeft.clamp(0.0, 100.0).toDouble();
  }

  /// Evaluates strategies and returns the fastest realistic configuration.
  ///
  /// [twoTyreRule] — when true (from raceData.twoTyreRule / rulesJson.two_tyres
  /// == "1"), the returned strategy is guaranteed to use at least 2 different
  /// tyre compounds, and a single-stint strategy is never returned (you can't
  /// satisfy the rule with only one compound available for the whole race).
  static List<StrategyStint> getOptimalStrategy({
    required int raceLaps,
    required double fuelPerLap,
    required int teAttr,
    required String trackCode,
    required bool refuelling,
    bool twoTyreRule = false,
  }) {
    final track = trackInfo[trackCode.toLowerCase()];
    final pitTime = (track?['pit'] as double?) ?? 22.0;

    List<StrategyStint>? bestStints;
    double bestTime = double.infinity;

    final tyres = ['SS', 'S', 'M', 'H'];
    final tyrePace = {'SS': 0.0, 'S': 0.3, 'M': 0.6, 'H': 0.9};

    int maxStints = (raceLaps / 14).ceil() + 1;
    if (maxStints > 5) maxStints = 5;

    // The 2-tyre rule needs at least 2 different compounds across the race,
    // which is impossible with a single stint — force at least 2 stints.
    final minStints = twoTyreRule ? 2 : 1;

    for (int numStints = minStints; numStints <= maxStints; numStints++) {
      int baseLaps = raceLaps ~/ numStints;
      int remainder = raceLaps % numStints;

      List<int> lapsPerStint = List.generate(
        numStints,
        (i) => baseLaps + (i < remainder ? 1 : 0)
      );

      double totalTime = (numStints - 1) * pitTime;
      bool isValid = true;
      List<StrategyStint> currentStints = [];

      for (int laps in lapsPerStint) {
        String? selectedTyre;
        double bestWear = -1.0;
        double lowestPenalty = double.infinity;

        for (String t in tyres) {
          double wearLeft = getTyreWearPercentage(
            teAttr: teAttr, trackCode: trackCode, tyre: t, laps: laps, raceLaps: raceLaps
          );

          double penalty = 0.0;
          if (wearLeft < 45.0) {
            penalty = (45.0 - wearLeft) * 1.5;
          }

          if (wearLeft > 15.0) {
             double totalTyreCost = (laps * tyrePace[t]!) + penalty;
             if (totalTyreCost < lowestPenalty) {
               lowestPenalty = totalTyreCost;
               selectedTyre = t;
               bestWear = wearLeft;
             }
          }
        }

        if (selectedTyre == null || bestWear < 15.0) {
          isValid = false;
          break;
        }

        double tTyre = lowestPenalty;
        double tFuel = 0.0;

        if (refuelling) {
           double averageFuelLiters = (laps * fuelPerLap) / 2.0;
           tFuel = laps * (averageFuelLiters * 0.025);
        }
        totalTime += tTyre + tFuel;

        currentStints.add(StrategyStint(
          tyre: selectedTyre,
          laps: laps,
          fuelPerLap: fuelPerLap,
          explicitFuel: refuelling ? (laps * fuelPerLap).ceil() : null,
        ));
      }

      if (isValid && totalTime < bestTime) {
        bestTime = totalTime;
        bestStints = currentStints;
      }
    }

    if (bestStints == null) {
      int bLaps = raceLaps ~/ 5;
      int rem = raceLaps % 5;
      bestStints = List.generate(5, (i) {
        int l = bLaps + (i < rem ? 1 : 0);
        return StrategyStint(
          tyre: 'H',
          laps: l,
          fuelPerLap: fuelPerLap,
          explicitFuel: refuelling ? (l * fuelPerLap).ceil() : null,
        );
      });
    }

    // Enforce the 2-tyre rule: ensure at least 2 distinct compounds appear.
    if (twoTyreRule && bestStints.length >= 2) {
      final usedTyres = bestStints.map((s) => s.tyre).toSet();
      if (usedTyres.length < 2) {
        final last = bestStints.last;
        for (final t in tyres) {
          if (t == last.tyre) continue;
          final wearLeft = getTyreWearPercentage(
            teAttr: teAttr, trackCode: trackCode, tyre: t,
            laps: last.laps, raceLaps: raceLaps,
          );
          if (wearLeft > 15.0) {
            bestStints[bestStints.length - 1] = StrategyStint(
              tyre: t,
              laps: last.laps,
              fuelPerLap: fuelPerLap,
              explicitFuel: refuelling ? (last.laps * fuelPerLap).ceil() : null,
            );
            break;
          }
        }
      }
    }

    return bestStints;
  }
}