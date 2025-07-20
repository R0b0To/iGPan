import 'dart:math';
import '../models/account.dart';

// Represents a race track with its specific characteristics and data.
class Track {
  String trackId; // Identifier for the track (e.g., "1" for Australia).
  int raceLaps; // Number of laps for the current race on this track.
  late Map<String, dynamic> info; // Holds specific information about the track, loaded from trackInfoData.
  // Multipliers used to adjust calculations based on league race length percentage.
  // Keys are race length percentages (e.g., 100 for 100% race length), values are the corresponding multipliers.
  Map<int, double> multipliers = {100: 1, 75: 1.25, 50: 1.5, 25: 3};
  late int length; // Represents the effective race length percentage (e.g., 100, 75, 50, 25) for the current league.

  // Static data map containing detailed information for each track.
  // Each key is a trackId (String).
  // Values are maps where:
  //  - 'trackCode': Short code for the track (e.g., 'au' for Australia).
  //  - 'length': Physical length of the track in some unit (e.g., km). This is NOT the race length percentage.
  //  - 'wear': A base tyre wear factor for the track.
  //  - 'avg': Average speed or a similar metric for the track.
  //  - Keys like '14', '28', '42', '57' (and similar for other tracks) represent the number of race laps
  //    that correspond to a certain percentage of a full-length race.
  //  - The values associated with these lap keys (e.g., 25, 50, 75, 100) represent the race length percentage
  //    (e.g., for Australia '14' laps is a 25% length race, '57' laps is a 100% length race).
Map<String, Map<String, dynamic>> trackInfoData = {
  '1':  { 'trackCode': 'au', 'length': 5.3017135, 'wear': 40, 'avg': 226.1090047, '14': 25, '28': 50, '42': 75, '57': 100 }, // Australia
  '2':  { 'trackCode': 'my', 'length': 5.5358276, 'wear': 80, 'avg': 208.879, '13': 25, '27': 50, '41': 75, '55': 100 },     // Malaysia
  '3':  { 'trackCode': 'cn', 'length': 5.4417996, 'wear': 80, 'avg': 207.975, '13': 25, '27': 50, '41': 75, '55': 100 },     // China
  '4':  { 'trackCode': 'bh', 'length': 4.7273, 'wear': 60, 'avg': 184.933, '14': 25, '29': 50, '44': 75, '59': 100 },        // Bahrain
  '5':  { 'trackCode': 'es', 'length': 4.4580207, 'wear': 85, 'avg': 189.212, '15': 25, '31': 50, '46': 75, '62': 100 },     // Spain
  '6':  { 'trackCode': 'mc', 'length': 4.0156865, 'wear': 20, 'avg': 187, '14': 25, '29': 50, '44': 75, '59': 100 },         // Monaco
  '7':  { 'trackCode': 'tr', 'length': 5.1630893, 'wear': 90, 'avg': 196, '13': 25, '27': 50, '40': 75, '54': 100 },         // Turkey
  '9':  { 'trackCode': 'de', 'length': 4.1797523, 'wear': 50, 'avg': 215.227, '16': 25, '33': 50, '50': 75, '67': 100 },     // Germany
  '10': { 'trackCode': 'hu', 'length': 3.4990127, 'wear': 30, 'avg': 165.043, '19': 25, '39': 50, '59': 75, '79': 100 },     // Hungary
  '11': { 'trackCode': 'eu', 'length': 5.5907145, 'wear': 45, 'avg': 199.05, '12': 25, '25': 50, '37': 75, '50': 100 },      // Europe
  '12': { 'trackCode': 'be', 'length': 7.0406127, 'wear': 60, 'avg': 217.7, '10': 25, '21': 50, '32': 75, '43': 100 },       // Belgium
  '13': { 'trackCode': 'it', 'length': 5.4024186, 'wear': 35, 'avg': 263.107, '12': 25, '25': 50, '38': 75, '51': 100 },     // Italy
  '14': { 'trackCode': 'sg', 'length': 5.049042, 'wear': 45, 'avg': 187.0866142, '15': 25, '30': 50, '45': 75, '60': 100 },  // Singapore
  '15': { 'trackCode': 'jp', 'length': 5.0587635, 'wear': 70, 'avg': 197.065, '13': 25, '27': 50, '41': 75, '55': 100 },     // Japan
  '16': { 'trackCode': 'br', 'length': 3.9715014, 'wear': 60, 'avg': 203.932, '17': 25, '34': 50, '51': 75, '69': 100 },     // Brazil
  '17': { 'trackCode': 'ae', 'length': 5.412688, 'wear': 50, 'avg': 213.218309, '12': 25, '25': 50, '37': 75, '50': 100 },   // Abu Dhabi
  '18': { 'trackCode': 'gb', 'length': 5.75213, 'wear': 65, 'avg': 230.552, '12': 25, '24': 50, '36': 75, '48': 100 },       // Great Britain
  '19': { 'trackCode': 'fr', 'length': 5.882508, 'wear': 80, 'avg': 215.1585366, '12': 25, '24': 50, '36': 75, '48': 100 },  // France
  '20': { 'trackCode': 'at', 'length': 4.044372, 'wear': 60, 'avg': 228.546, '17': 25, '34': 50, '51': 75, '68': 100 },      // Austria
  '21': { 'trackCode': 'ca', 'length': 4.3413563, 'wear': 45, 'avg': 221.357243, '15': 25, '31': 50, '47': 75, '63': 100 },  // Canada
  '22': { 'trackCode': 'az', 'length': 6.053212, 'wear': 45, 'avg': 220.409, '11': 25, '23': 50, '34': 75, '46': 100 },      // Azerbaijan
  '23': { 'trackCode': 'mx', 'length': 4.3076024, 'wear': 60, 'avg': 172.32, '17': 25, '35': 50, '52': 75, '70': 100 },      // Mexico
  '24': { 'trackCode': 'ru', 'length': 6.078335, 'wear': 50, 'avg': 197.092, '11': 25, '23': 50, '34': 75, '46': 100 },      // Russia
  '25': { 'trackCode': 'us', 'length': 4.60296, 'wear': 65, 'avg': 186.568, '15': 25, '30': 50, '45': 75, '60': 100 },       // USA
};


  Track(this.trackId, this.raceLaps) {
    // Loads the specific track's data from the static trackInfoData map.
    info = trackInfoData[trackId]!;
    // Derives the 'length' (which is the race length percentage, e.g., 100, 75, 50, 25)
    // by using the current raceLaps (converted to a string) as a key into the loaded track 'info' map.
    // For example, if raceLaps is 57 for Australia (trackId '1'), info['57'] will give 100.
    length = info[raceLaps.toString()] as int;
  }

  // Returns a multiplier based on the league's race length percentage.
  // This is used to adjust wear calculations for shorter or longer races compared to a standard (100%) length.
  double getLeagueLengthMultiplier() {
    // Uses the derived 'length' (race length percentage) to look up the corresponding multiplier in the 'multipliers' map.
    return multipliers[length]!;
  }

}

// Calculates the base tyre wear per lap for different tyre compounds on a given track.
// `tyreEco` is the driver's tyre economy skill.
// `track` is an instance of the Track class for the current track.
Map<String, String> wearCalc(double tyreEco, Track track) {
  // Factors for adjusting wear based on tyre compound. Softer tyres wear faster.
  Map<String, double> tyreWearFactors = {'SS': 2.14, 'S': 1.4, 'M': 1.0, 'H': 0.78};

  // This is the core wear calculation formula, incorporating driver skill, track characteristics,
  // track length percentage, and a league length multiplier.
  // The overall purpose is to estimate a base wear value per lap.
  double calculation = (1.43 * pow(tyreEco, -0.0778)) * (0.00364 * track.info['wear'] + 0.354) *   track.info['length'] * 1.384612 * track.getLeagueLengthMultiplier();

  return {
    "SS": (calculation * tyreWearFactors['SS']!).toStringAsFixed(1), // SuperSoft
    "S": (calculation * tyreWearFactors['S']!).toStringAsFixed(1),  // Soft
    "M": (calculation * tyreWearFactors['M']!).toStringAsFixed(1),  // Medium
    "H": (calculation * tyreWearFactors['H']!).toStringAsFixed(1),  // Hard
    // Intermediate ('I') and Wet ('W') tyres currently use the Medium ('M') tyre wear factor as a placeholder or approximation.
    "I": (calculation * tyreWearFactors['M']!).toStringAsFixed(1),  // Intermediate
    "W": (calculation * tyreWearFactors['M']!).toStringAsFixed(1),  // Wet
  };
}

// Calculates the estimated tyre condition after a stint of a certain number of laps.
// `t` is the base tyre wear percentage per lap (from wearCalc for a specific compound).
// `l` is the number of laps in the stint.
// `track` is an instance of the Track class.
String stintWearCalc(double t, int l, Track track) {
  // `stint`: First method of calculating remaining tyre percentage after `l` laps.
  // This appears to be an exponential decay model.
  double stint = pow(e, (-t / 100 * 1.18) * l) * 100;
  
  // `stint2`: Second method of calculating remaining tyre percentage.
  // This seems to be a more complex iterative model, potentially accounting for per-lap variations or track length effects.
  double stint2 = (1 - (1 * ((t) + (0.0212 * l - 0.00926) * track.info['length']) / 100));
  for (int j = 1; j < l; j++) {
    stint2 *= (1 - (1 * ((t) + (0.0212 * j - 0.00926) * track.info['length']) / 100));
  }
  stint2 *= 100;

  // The function returns the average of the two calculation methods.
  // This might be an attempt to create a more robust or empirically adjusted estimate.
  double average = (stint + stint2) / 2;
  average = double.parse(average.toStringAsFixed(2));

  return average.toString();
}

// Calculates a fuel consumption factor based on the driver's fuel economy skill (`f`).
// The purpose is to determine how efficiently a driver uses fuel, which affects fuel load calculations for stints.
// Higher fuel economy skill (`f`) should result in a lower consumption factor (better efficiency).
double fuelCalc(double f) {
  if (f >= 250) {
    return (pow(0.6666 * f, -0.08434) * 0.669);
  } else if (f >= 200) {
    return (pow(0.6666 * f, -0.08434) * 0.669);
  } else if (f >= 150) {
    return (pow(0.6666 * f, -0.08473) * 0.669);
  } else if (f >= 100) {
    return (pow(0.6666 * f, -0.08505) * 0.669);
  } else if (f >= 80) {
    return (pow(0.6666 * f, -0.08505) * 0.669);
  } else if (f >= 60) {
    return (pow(0.6666 * f, -0.08505) * 0.669);
  } else if (f >= 40) {
    return (pow(0.6666 * f, -0.0842) * 0.669);
  } else if (f >= 20) {
    return (pow(0.6666 * f, -0.083) * 0.669);
  } else {
    return (pow(0.6666 * f, -0.11) * 0.725);
  }
}

Map<String, dynamic> generateDefaultStrategy(Account account) {
  final raceLaps = int.tryParse(account.raceData!['vars']!['raceLaps']!.toString()) ?? 0;
  final track = Track(account.raceData?['vars']?['trackId']?.toString() ?? '1', raceLaps);

  final carAttributes = account.fireUpData?['preCache']?['p=cars']?['vars']?['carAttributes'];
  final tyreEconomy = carAttributes?['tyre_economy']?.toDouble() ?? 0.0;
  final calculatedWear = wearCalc(tyreEconomy, track); // e.g. { 'S': '6.3', 'M': '5.1' }

  final fuelEconomy = account.fireUpData?['preCache']?['p=cars']?['vars']?['carAttributes']?['fuel_economy']?.toDouble() ?? 0.0;
  final trackLength = (track.info['length'] as num?)?.toDouble() ?? 0.0;
  final kmPerLiter = fuelCalc(fuelEconomy);
  final fuelPerLap = ( kmPerLiter ) * trackLength;
  final totalFuel = fuelPerLap * raceLaps;

  if(account.raceData?['vars']?['rulesJson']?['refuelling'] == '0'){
    //to do: car 1 and car 2
        account.raceData!['parsedStrategy'][0][0][2] = totalFuel.ceil();
        account.raceData?['vars']['d${1}AdvancedFuel'] = totalFuel.ceil(); 
        
      }
    // always enable advanced settings ??
    String ignoreAdvancedKey = 'd${1}IgnoreAdvanced';
    account.raceData!['vars']?[ignoreAdvancedKey] = true; // enable advanced
 
  account.raceData?['kmPerLiter'] = kmPerLiter; 
  account.raceData?['track'] = track; 

  const int push = 3;
  const double minWear = 44.0;
  const double maxWear = 60.0;

  
List<Map<String, dynamic>> bestStints = [];
int lapsRemaining = raceLaps;
int stintIndex = 0;

while (lapsRemaining > 0) {
  String selectedTyre = 'S';
  int bestLapCount = 1;

  if (stintIndex == 0) {
    // First stint must use 'S'
    double tyreWear = double.tryParse(calculatedWear['S'] ?? '0.0') ?? 0.0;
    for (int testLaps = 1; testLaps <= lapsRemaining; testLaps++) {
      double wear = double.tryParse(stintWearCalc(tyreWear, testLaps, track)) ?? 0.0;
      //if (wear > maxWear) break;
      if (wear >= minWear) bestLapCount = testLaps;
    }
  } else {
    // Try both tyres after first stint
    for (final tyre in ['S', 'M']) {
      double tyreWear = double.tryParse(calculatedWear[tyre] ?? '0.0') ?? 0.0;
      int maxValidLaps = 1;
      for (int testLaps = 1; testLaps <= lapsRemaining; testLaps++) {
        double wear = double.tryParse(stintWearCalc(tyreWear, testLaps, track)) ?? 0.0;
        //if (wear > maxWear) break;
        if (wear >= minWear) maxValidLaps = testLaps;
      }

      // Keep tyre if it gives more laps
      if (maxValidLaps > bestLapCount) {
        bestLapCount = maxValidLaps;
        selectedTyre = tyre;
      }
    }
  }

  bestStints.add({
    'tyre': selectedTyre,
    'laps': bestLapCount,
    'push': push,
  });

  lapsRemaining -= bestLapCount;
  stintIndex++;
}

  // Fallback if nothing worked
 

  // Create result map
  Map<String, dynamic> stintsMap = {};
  for (int i = 0; i < bestStints.length; i++) {
    stintsMap[i.toString()] = {
      'tyre': 'ts-${bestStints[i]['tyre']}',
      'laps': bestStints[i]['laps'].toString(),
      'push': bestStints[i]['push'],
    };
  }

  return {
    'track': track.info['trackCode'],
    'length': track.length,
    'laps': {'total': raceLaps, 'doing': raceLaps},
    'stints': stintsMap,
  };
}

List<List<int>> generateLapSplits(int total, int parts) {
  List<List<int>> results = [];

  void helper(List<int> current, int remaining, int depth) {
    if (depth == parts) {
      if (remaining == 0) results.add(List.from(current));
      return;
    }

    // Allow each stint to be at least 1 lap
    for (int i = 1; i <= remaining - (parts - depth - 1); i++) {
      current.add(i);
      helper(current, remaining - i, depth + 1);
      current.removeLast();
    }
  }

  helper([], total, 0);
  return results;
}
