import 'dart:math';

class Track {
  String trackId;
  int raceLaps;
  late Map<String, dynamic> info;
  Map<int, double> multipliers = {100: 1, 75: 1.25, 50: 1.5, 25: 3};
  late int length; // Changed to int based on analysis
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
    info = trackInfoData[trackId]!;
    length = info[raceLaps.toString()] as int; // Assuming raceLaps is used as a string key and the value is an int
  }

  double getLeagueLengthMultiplier() {
    return multipliers[length]!;
  }

}

Map<String, String> wearCalc(double tyreEco, Track track) { // Updated track type
  Map<String, double> tyreWearFactors = {'SS': 2.14, 'S': 1.4, 'M': 1.0, 'H': 0.78};

  // Assuming track.info is a Map and track has a getLeagueLengthMultiplier method
  double calculation = (1.43 * pow(tyreEco, -0.0778)) * (0.00364 * track.info['wear'] + 0.354) *   track.info['length'] * 1.384612 * track.getLeagueLengthMultiplier();

  return {
    "SS": (calculation * tyreWearFactors['SS']!).toStringAsFixed(1),
    "S": (calculation * tyreWearFactors['S']!).toStringAsFixed(1),
    "M": (calculation * tyreWearFactors['M']!).toStringAsFixed(1),
    "H": (calculation * tyreWearFactors['H']!).toStringAsFixed(1),
    "I": (calculation * tyreWearFactors['M']!).toStringAsFixed(1), // Assuming 'I' uses 'M' factor
    "W": (calculation * tyreWearFactors['M']!).toStringAsFixed(1), // Assuming 'W' uses 'M' factor
  };
}

// t is wear, l is laps, track is an instance of Track
String stintWearCalc(double t, int l, Track track) {
  double stint = pow(e, (-t / 100 * 1.18) * l) * 100;
  
  double stint2 = (1 - (1 * ((t) + (0.0212 * l - 0.00926) * track.info['length']) / 100));
  for (int j = 1; j < l; j++) {
    stint2 *= (1 - (1 * ((t) + (0.0212 * j - 0.00926) * track.info['length']) / 100));
  }
  stint2 *= 100;

  double average = (stint + stint2) / 2;
  average = double.parse(average.toStringAsFixed(2));

  return average.toString();
}

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
