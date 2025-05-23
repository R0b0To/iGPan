import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse; // Used for parsing HTML strings.
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart'; // For custom icons.

// Abbreviates a large number string with a suffix (K, M, B, etc.).
String abbreviateNumber(String input) {
  final n = double.tryParse(input);
  if (n == null || n == 0) return '0';

  final suffixes = ['', 'K', 'M', 'B', 'T', 'P', 'E', 'Z', 'Y'];
  int magnitude = 0;
  double value = n;

  while (value.abs() >= 1000 && magnitude < suffixes.length - 1) {
    magnitude++;
    value /= 1000.0;
  }

  return '${value.toStringAsFixed(1)}${suffixes[magnitude]}';
}

class CarSetup {
  final String trackCode;
  final double driverHeight;
  final int tier;
  late final Map<String, dynamic> suggestedSetup; // The calculated car setup.
  late final int suspension; // Final calculated suspension value.
  late final int ride; // Final calculated ride height value.
  late final int wing; // Final calculated wing (aerodynamics) value.

  // Constructor for CarSetup.
  // `trackCode` is the identifier for the track.
  // `height` is the driver's height.
  // `tier` is the racing tier (e.g., rookie, pro, elite).
  CarSetup(this.trackCode, double height, this.tier) :
    // Rounds the driver's height down to the nearest multiple of 5.
    // This is likely done to map the height to predefined adjustment values in the `scale` map.
    driverHeight = (height ~/ 5) * 5{
    suggestedSetup = _calculateSetup();
  }


  Map<String, dynamic> _calculateSetup() {
    // The `scale` map defines adjustments to ride height based on driver height and racing tier.
    // Structure: { driverHeight (rounded) : { tier : rideHeightAdjustment } }
    // - Keys (190, 185, etc.): Driver height, rounded down to the nearest 5.
    // - Nested Keys (3, 2, 1): Racing tier (3 for Elite, 2 for Pro, 1 for Rookie).
    // - Nested Values (-8, -4, etc.): The adjustment value to be added to the base ride height.
    // Taller drivers generally get a negative adjustment (lower ride height),
    // and this adjustment can be more significant in higher tiers.
    final Map<int, Map<int, int>> scale = {
      190: {3: -8, 2: -4, 1: -2}, // Adjustments for drivers around 190cm height
      185: {3: -6, 2: -3, 1: -1}, // Adjustments for drivers around 185cm height
      180: {3: -4, 2: -2, 1: -1}, // Adjustments for drivers around 180cm height
      175: {3: -2, 2: -1, 1: 0},   // Adjustments for drivers around 175cm height
      170: {3: 0, 2: 0, 1: 0},     // Adjustments for drivers around 170cm height (neutral or base)
      165: {3: 2, 2: 1, 1: 0},     // Adjustments for drivers around 165cm height
      160: {3: 2, 2: 1, 1: 0},     // Adjustments for drivers around 160cm height
    };

    // The `circuits` map provides base car setup values (ride height, wing, suspension) for each track, categorized by tier.
    // Structure: { tier : { trackCode : { setupParameter : value } } }
    // - Outer Keys (1, 2, 3): Racing tier (1 for Rookie, 2 for Pro, 3 for Elite).
    // - Middle Keys ('17', '20', etc.): Track code/ID (e.g., '17' for Abu Dhabi). These correspond to track identifiers used elsewhere.
    // - Inner Keys ('ride', 'wing', 'suspension', 'pit'): Specific setup parameters.
    //   - 'ride': Base ride height.
    //   - 'wing': Base wing (aerodynamics) setting.
    //   - 'suspension': Base suspension setting.
    //   - 'pit': A value likely related to pit stop time or strategy for that track, not directly used in ride/wing/suspension calculation here.
    // The values associated with 'ride', 'wing', 'suspension' are the starting points before driver height adjustments.
    final Map<int, Map<String, Map<String, int>>> circuits = {
  // rookie
  1: {
    '17': {'ride': 6, 'wing': 1, 'suspension': 1, 'pit': 23},   // Abu Dhabi (ae) - Rookie tier base setup
    '20': {'ride': 4, 'wing': 0, 'suspension': 2, 'pit': 27},   // Austria (at) - Rookie tier base setup
    '1': {'ride': 9, 'wing': 4, 'suspension': 1, 'pit': 24},    // Australia (au) - Rookie tier base setup
    '22': {'ride': 8, 'wing': 1, 'suspension': 1, 'pit': 17},   // Azerbaijan (az)
    '12': {'ride': 6, 'wing': 3, 'suspension': 1, 'pit': 15},   // Belgium (be)
    '4': {'ride': 4, 'wing': 0, 'suspension': 2, 'pit': 23},    // Bahrain (bh)
    '16': {'ride': 4, 'wing': 2, 'suspension': 1, 'pit': 21},   // Brazil (br)
    '21': {'ride': 4, 'wing': -1, 'suspension': 2, 'pit': 17},  // Canada (ca)
    '3': {'ride': 2, 'wing': 2, 'suspension': 1, 'pit': 26},    // China (cn)
    '9': {'ride': 4, 'wing': 2, 'suspension': 1, 'pit': 17},    // Germany (de)
    '5': {'ride': 2, 'wing': 5, 'suspension': 0, 'pit': 25},    // Spain (es)
    '11': {'ride': 6, 'wing': 5, 'suspension': 0, 'pit': 17},   // Europe (eu)
    '19': {'ride': 8, 'wing': 2, 'suspension': 1, 'pit': 20},   // France (fr)
    '18': {'ride': 4, 'wing': 0, 'suspension': 2, 'pit': 23},   // Great Britain (gb)
    '10': {'ride': 5, 'wing': 6, 'suspension': 0, 'pit': 17},   // Hungary
    '13': {'ride': 6, 'wing': -2, 'suspension': 2, 'pit': 24},  // Italy
    '15': {'ride': 6, 'wing': 5, 'suspension': 0, 'pit': 20},   // Japan
    '6': {'ride': 11, 'wing': 9, 'suspension': 0, 'pit': 16},   // Monaco
    '23': {'ride': 3, 'wing': 2, 'suspension': 1, 'pit': 19},   // Mexico
    '2': {'ride': 6, 'wing': 1, 'suspension': 1, 'pit': 22},    // Malaysia
    '24': {'ride': 2, 'wing': 2, 'suspension': 1, 'pit': 21},   // Russia
    '14': {'ride': 8, 'wing': 7, 'suspension': 0, 'pit': 20},   // Singapore
    '7': {'ride': 6, 'wing': 2, 'suspension': 1, 'pit': 18},    // Turkey
    '25': {'ride': 2, 'wing': 2, 'suspension': 1, 'pit': 16},   // USA
  },
  // pro
  2: {
    '17': {'ride': 13, 'wing': 3, 'suspension': 1, 'pit': 23},   // Abu Dhabi
    '20': {'ride': 9, 'wing': 0, 'suspension': 2, 'pit': 27},    // Austria
    '1': {'ride': 19, 'wing': 8, 'suspension': 1, 'pit': 24},    // Australia
    '22': {'ride': 17, 'wing': 3, 'suspension': 1, 'pit': 17},   // Azerbaijan
    '12': {'ride': 12, 'wing': 6, 'suspension': 1, 'pit': 15},   // Belgium
    '4': {'ride': 8, 'wing': 0, 'suspension': 2, 'pit': 23},     // Bahrain
    '16': {'ride': 8, 'wing': 5, 'suspension': 1, 'pit': 21},    // Brazil
    '21': {'ride': 9, 'wing': -3, 'suspension': 2, 'pit': 17},   // Canada
    '3': {'ride': 5, 'wing': 5, 'suspension': 1, 'pit': 26},     // China
    '9': {'ride': 8, 'wing': 5, 'suspension': 1, 'pit': 17},     // Germany
    '5': {'ride': 5, 'wing': 10, 'suspension': 0, 'pit': 25},    // Spain
    '11': {'ride': 12, 'wing': 10, 'suspension': 0, 'pit': 17},  // Europe
    '19': {'ride': 17, 'wing': 5, 'suspension': 1, 'pit': 20},   // France
    '18': {'ride': 9, 'wing': 0, 'suspension': 2, 'pit': 23},    // Great Britain
    '10': {'ride': 10, 'wing': 13, 'suspension': 0, 'pit': 17},  // Hungary
    '13': {'ride': 12, 'wing': -5, 'suspension': 2, 'pit': 24},  // Italy
    '15': {'ride': 12, 'wing': 10, 'suspension': 0, 'pit': 20},  // Japan
    '6': {'ride': 22, 'wing': 18, 'suspension': 0, 'pit': 16},   // Monaco
    '23': {'ride': 7, 'wing': 5, 'suspension': 1, 'pit': 19},    // Mexico
    '2': {'ride': 12, 'wing': 3, 'suspension': 1, 'pit': 22},    // Malaysia
    '24': {'ride': 4, 'wing': 5, 'suspension': 1, 'pit': 21},    // Russia
    '14': {'ride': 17, 'wing': 14, 'suspension': 0, 'pit': 20},  // Singapore
    '7': {'ride': 13, 'wing': 5, 'suspension': 1, 'pit': 18},    // Turkey
    '25': {'ride': 4, 'wing': 4, 'suspension': 1, 'pit': 16},    // USA
  },
  // elite
  3: {
    '17': {'ride': 25, 'wing': 5, 'suspension': 1, 'pit': 23},   // Abu Dhabi
    '20': {'ride': 18, 'wing': 0, 'suspension': 2, 'pit': 27},   // Austria
    '1': {'ride': 38, 'wing': 15, 'suspension': 1, 'pit': 24},   // Australia
    '22': {'ride': 33, 'wing': 5, 'suspension': 1, 'pit': 17},   // Azerbaijan
    '12': {'ride': 23, 'wing': 12, 'suspension': 1, 'pit': 15},  // Belgium
    '4': {'ride': 15, 'wing': 0, 'suspension': 2, 'pit': 23},    // Bahrain
    '16': {'ride': 15, 'wing': 10, 'suspension': 1, 'pit': 21},  // Brazil
    '21': {'ride': 18, 'wing': -5, 'suspension': 2, 'pit': 17},  // Canada
    '3': {'ride': 10, 'wing': 10, 'suspension': 1, 'pit': 26},   // China
    '9': {'ride': 15, 'wing': 10, 'suspension': 1, 'pit': 17},   // Germany
    '5': {'ride': 10, 'wing': 20, 'suspension': 0, 'pit': 25},   // Spain
    '11': {'ride': 23, 'wing': 20, 'suspension': 0, 'pit': 17},  // Europe
    '19': {'ride': 33, 'wing': 10, 'suspension': 1, 'pit': 20},  // France
    '18': {'ride': 18, 'wing': 0, 'suspension': 2, 'pit': 23},   // Great Britain
    '10': {'ride': 20, 'wing': 25, 'suspension': 0, 'pit': 17},  // Hungary
    '13': {'ride': 23, 'wing': -10, 'suspension': 2, 'pit': 24}, // Italy
    '15': {'ride': 23, 'wing': 20, 'suspension': 0, 'pit': 20},  // Japan
    '6': {'ride': 43, 'wing': 35, 'suspension': 0, 'pit': 16},   // Monaco
    '23': {'ride': 13, 'wing': 10, 'suspension': 1, 'pit': 19},  // Mexico
    '2': {'ride': 23, 'wing': 5, 'suspension': 1, 'pit': 22},    // Malaysia
    '24': {'ride': 8, 'wing': 10, 'suspension': 1, 'pit': 21},   // Russia
    '14': {'ride': 33, 'wing': 27, 'suspension': 0, 'pit': 20},  // Singapore
    '7': {'ride': 25, 'wing': 10, 'suspension': 1, 'pit': 18},   // Turkey
    '25': {'ride': 8, 'wing': 7, 'suspension': 1, 'pit': 16},    // USA
  }
    };

    Map<String, dynamic> setup = Map<String, dynamic>.from(circuits[tier]![trackCode]!);

    // Apply driver height adjustment to ride height
    setup['ride'] += scale[driverHeight]![tier]!;

    // Ensure minimum values
    if (setup['ride'] == 0) {
      setup['ride'] = 1;
    }
    if (setup['wing'] <= 0) {
      setup['wing'] = 1;
    }

    // Set class properties
    suspension = setup['suspension'];
    ride = setup['ride'];
    wing = setup['wing'];

    return setup;
  }
}

// A custom UI widget that displays a button with a circular progress indicator around it.
class CircularProgressButton extends StatelessWidget {
  final double progress; // Progress value from 0 to 100, determines the fill of the circle.
  final String label; // Label text displayed in the center of the button.
  final VoidCallback onPressed; // Callback function executed when the button is tapped.
  final double size; // Size of the circular progress indicator
  final Color backgroundColor; // Color of the background arc

  const CircularProgressButton({
    super.key,
    required this.progress,
    required this.label,
    required this.onPressed,
    this.size = 50.0,
    this.backgroundColor = const Color.fromARGB(0, 255, 255, 255), // Default transparent background for the track.
  });

  // Determines the color of the progress arc based on the current progress value.
  Color _getProgressColor() {
    // Defines color stops for a gradient-like effect based on progress.
      final List<MapEntry<double, Color>> colorStops = [
    MapEntry(0.0, Colors.red), // Progress 0% is red.
    MapEntry(90.0, Colors.orange), // Progress 90% is orange.
    MapEntry(100.0, Colors.green), // Progress 100% is green.
  ];
    // Interpolates color between defined stops.
      for (int i = 0; i < colorStops.length - 1; i++) {
    final currentStop = colorStops[i];
    final nextStop = colorStops[i + 1];

    if (progress >= currentStop.key && progress <= nextStop.key) {
      // Calculate how far we are between the two stops (0.0 to 1.0)
      final t = (progress - currentStop.key) / (nextStop.key - currentStop.key);

      // Interpolate between the two colors
      return Color.lerp(currentStop.value, nextStop.value, t)!;
    }
  }
    return Colors.blue; // Default color if progress is outside defined ranges (should not happen with clamp).
  }

  // Determines the label to display, with special handling for "Engine" and "Parts" labels based on progress.
  String _getDisplayLabel() {
    // If the label is 'Engine' and progress is less than 100, display 'Replace'.
    if (label == 'Engine' && progress < 100) {
      return 'Replace';
    }
    // If the label is not 'Engine' (implicitly 'Parts' in its typical use case) and progress is 100, display 'Parts'.
     if (label != 'Engine' && progress == 100) {
      return 'Parts';
    }
    // Otherwise, return the original label.
    return label;
  }
  @override
  Widget build(BuildContext context) {
    // Ensure progress is between 0 and 100
    final normalizedProgress = progress.clamp(0.0, 100.0);

    final displayLabel = _getDisplayLabel();
    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Background circle
            CustomPaint(
              size: Size(size, size),
              painter: CircularProgressPainter(
                progress: normalizedProgress / 100,
                progressColor: _getProgressColor(),
                backgroundColor: backgroundColor,
              ),
            ),
            // Center content
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  displayLabel,
                  style: TextStyle(
                    fontSize: size / 4,
                  ),
                ),
              ],)
          ],
        ),
      ),
    );
  }
}

// A custom painter responsible for drawing the circular progress arc and its background.
class CircularProgressPainter extends CustomPainter {
  final double progress; // Normalized progress value (0.0 to 1.0).
  final Color progressColor; // Color of the progress arc.
  final Color backgroundColor; // Color of the track/background of the arc.

  CircularProgressPainter({
    required this.progress,
    required this.progressColor,
    required this.backgroundColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;
    const startAngle = -1.5708; // -90 degrees in radians (start from top)
    final sweepAngle = 2 * 3.14159 * progress; // Full circle is 2*PI

    // Draw background circle
    final backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width / 15;

    canvas.drawCircle(center, radius - backgroundPaint.strokeWidth / 2, backgroundPaint);

    // Draw progress arc
    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width / 15
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius - progressPaint.strokeWidth / 2),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(CircularProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.progressColor != progressColor ||
           oldDelegate.backgroundColor != backgroundColor;
  }
}
/// Parses and sanitizes the fireUpData.
Map<String, dynamic> parseFireUpData(dynamic fireUpData) {
  if (fireUpData is Map) {
    // Extracts the total number of spare parts from an HTML snippet.
    fireUpData['preCache']?['p=cars']?['vars']?['totalParts'] = extractDataValueFromHtml(fireUpData['preCache']?['p=cars']?['vars']?['totalParts'],'totalParts');
    // Extracts the total number of spare engines from an HTML snippet.
    fireUpData['preCache']?['p=cars']?['vars']?['totalEngines'] = extractDataValueFromHtml(fireUpData['preCache']?['p=cars']?['vars']?['totalEngines'],'totalEngines');
    // Extracts the cost (likely in parts) to repair car 1 from an HTML string (e.g., "Repair (120)"). It takes the last part after splitting by space.
    fireUpData['preCache']?['p=cars']?['vars']?['c1CarBtn'] = extractDataValueFromHtml(fireUpData['preCache']?['p=cars']?['vars']?['c1CarBtn'].split(' ').last,'');
    // Extracts the cost (likely in parts) to repair car 2.
    fireUpData['preCache']?['p=cars']?['vars']?['c2CarBtn'] = extractDataValueFromHtml(fireUpData['preCache']?['p=cars']?['vars']?['c2CarBtn'].split(' ').last,'');
    // Extracts the overall condition percentage of car 1 from a 'data-value' attribute in an HTML snippet.
    fireUpData['preCache']?['p=cars']?['vars']?['c1Condition'] = extractDataValueAttribute(fireUpData['preCache']?['p=cars']?['vars']?['c1Condition']);
    // Extracts the overall condition percentage of car 2.
    fireUpData['preCache']?['p=cars']?['vars']?['c2Condition'] = extractDataValueAttribute(fireUpData['preCache']?['p=cars']?['vars']?['c2Condition']);
    // Extracts the engine condition percentage for car 2.
    fireUpData['preCache']?['p=cars']?['vars']?['c2Engine'] = extractDataValueAttribute(fireUpData['preCache']?['p=cars']?['vars']?['c2Engine']);
    // Extracts the engine condition percentage for car 1.
    fireUpData['preCache']?['p=cars']?['vars']?['c1Engine'] = extractDataValueAttribute(fireUpData['preCache']?['p=cars']?['vars']?['c1Engine']);
    // Parses a block of HTML containing car attributes (like acceleration, braking) into a structured map.
    fireUpData['preCache']?['p=cars']?['vars']?['carAttributes'] = parseCarAttributes(fireUpData['preCache']?['p=cars']?['vars']?['carAttributes']);
    return Map<String, dynamic>.from(fireUpData);
  } else {
    print('Warning: fireUpData is not a Map. Cannot parse/sanitize.');
    return {};
  }
}

// Extracts the text content of an HTML element with a specific ID from an HTML string.
String extractDataValueFromHtml(String htmlString, String elementId) {
    if (htmlString.isEmpty) {
      return '';
    }
    final document = parse(htmlString);
    final element = document.getElementById(elementId);
    return element?.text ?? ''; // Return empty string if element not found or htmlString is empty.
  }

// Extracts the value of a 'data-value' attribute from an element (typically with class '.ratingCircle') within an HTML string.
  String? extractDataValueAttribute(String htmlString ) {
    if (htmlString.isEmpty) {
      return null; // Return null if htmlString is empty.
    }
    // Wrap the fragment in a basic HTML structure to ensure querySelector works reliably.
    final wrapFragment ='<html><body>$htmlString</body></html>';
    final document = parse(wrapFragment);

    final element = document.querySelector('.ratingCircle'); // Selects the first element with class 'ratingCircle'.
    final attribute = element?.attributes['data-value']; // Retrieves the 'data-value' attribute.

    return attribute;
  }

// Parses an HTML string containing car attribute rows and extracts them into a map of attribute name to value.
Map<String, int> parseCarAttributes(String htmlString) {
  final Map<String, int> attributes = {};

  final document = parse(htmlString);

  // Find all attribute rows
  final attributeRows = document.querySelectorAll('.attribute-row');

  for (var row in attributeRows) {
    // Extract the attribute name (converting to lowercase for consistency)
    final nameElement = row.querySelector('.attribute-rating-header span');
    if (nameElement == null) continue;

    String name = nameElement.text.toLowerCase().replaceAll(' ', '_');

    // Extract the attribute value
    final valueElement = row.querySelector('.ratingVal');
    if (valueElement == null) continue;

    // Parse the value as an integer
    int value = int.tryParse(valueElement.text) ?? 0;

    // Add to the map
    attributes[name] = value;
  }

  return attributes;
}
final List<DropdownMenuItem<String>> _strategyDropdownItems = [
  DropdownMenuItem<String>(
    value: '100',
    child: Center(child: Icon(Icons.keyboard_double_arrow_up, color: Colors.red, size: 20)),
  ),
  DropdownMenuItem<String>(
    value: '80',
    child: Center(child: Icon(Icons.keyboard_arrow_up, color: Colors.orange, size: 20)),
  ),
  DropdownMenuItem<String>(
    value: '60', // Neutral push level.
    child: Center(child: Icon(MdiIcons.circleDouble, color: Colors.white, size: 20)),
  ),
  DropdownMenuItem<String>(
    value: '40',
    child: Center(child: Icon(Icons.keyboard_arrow_down, color: Colors.lightGreen, size: 20)),
  ),
  DropdownMenuItem<String>(
    value: '20',
    child: Center(child: Icon(Icons.keyboard_double_arrow_down, color: Colors.green, size: 20)),
  ),
];

// Returns a pre-built list of DropdownMenuItem widgets for strategy push level selection.
List<DropdownMenuItem<String>> buildStrategyDropdownItems() {
  return _strategyDropdownItems;
}

// Maps push level string values (e.g., '100', '80') to numerical factors, likely for calculations.
    final pushLevelFactorMap = {
      '100': 0.02, // Highest push level factor.
      '80': 0.01,
      '60': 0.0,  // Neutral push level factor.
      '40': -0.004,
      '20': -0.007, // Lowest push level factor (most conservative).
    };

// A simple string hashing function (djb2 variation).
    int hashCode(String string) {
  int hash = 0;
  for (int i = 0; i < string.length; i++) {
    int code = string.codeUnitAt(i);
    hash = ((hash << 5) - hash + code) & 0xFFFFFFFF; // Keep within 32-bit integer range.
  }
  // Convert to signed 32-bit integer, similar to Java's String.hashCode().
  return hash >= 0x80000000 ? hash - 0x100000000 : hash;
}

// Checks if an input element within an HTML string is marked as 'checked'.
bool isChecked(String htmlString) {
  final document = parse(htmlString);
  final input = document.querySelector('input');
  return input?.attributes.containsKey('checked') ?? false;
}

// Parses the weather HTML string to extract water level, weather icon, and temperature.
Map<String, dynamic> parseWeatherHtml(String htmlString) {
  final document = parse(htmlString);
  String waterLevel = '';
  String weatherIcon = '';
  String temperature = '';

  // Extract water level
  final waterLevelTextElement = document.querySelector('.waterLevelText');
  if (waterLevelTextElement != null) {
    waterLevel = waterLevelTextElement.text.trim();
  }

  // Extract weather icon
  final iconElement = document.querySelector('icon');
  if (iconElement != null) {
    weatherIcon = iconElement.text.trim();
  }

  // Extract temperature (assuming it's the last numeric part before the icon or at the end)
  // This regex looks for a number followed by a degree symbol and 'C'
  final tempMatch = RegExp(r'(\d+°C)').firstMatch(htmlString);
  if (tempMatch != null) {
    temperature = tempMatch.group(1)!;
  } else {
    // Fallback: if no degree symbol, try to find a number followed by 'C'
    final simpleTempMatch = RegExp(r'(\d+C)').firstMatch(htmlString);
    if (simpleTempMatch != null) {
      temperature = simpleTempMatch.group(1)!;
    }
  }

  return {
    'waterLevel': waterLevel,
    'weatherIcon': weatherIcon,
    'temperature': temperature,
  };
}