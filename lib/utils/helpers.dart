import 'dart:math';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse;
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart'; 

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
  late final Map<String, dynamic> suggestedSetup;
  late final int suspension;
  late final int ride;
  late final int wing;

  CarSetup(this.trackCode, double height, this.tier) : 
    driverHeight = (height ~/ 5) * 5{
    suggestedSetup = _calculateSetup();
  }


  Map<String, dynamic> _calculateSetup() {
    final Map<int, Map<int, int>> scale = {
      190: {3: -8, 2: -4, 1: -2},
      185: {3: -6, 2: -3, 1: -1},
      180: {3: -4, 2: -2, 1: -1},
      175: {3: -2, 2: -1, 1: 0},
      170: {3: 0, 2: 0, 1: 0},
      165: {3: 2, 2: 1, 1: 0},
      160: {3: 2, 2: 1, 1: 0},
    };

    final Map<int, Map<String, Map<String, int>>> circuits = {
  // rookie
  1: {
    '17': {'ride': 6, 'wing': 1, 'suspension': 1, 'pit': 23},   // Abu Dhabi (ae)
    '20': {'ride': 4, 'wing': 0, 'suspension': 2, 'pit': 27},   // Austria (at)
    '1': {'ride': 9, 'wing': 4, 'suspension': 1, 'pit': 24},    // Australia (au)
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
    '10': {'ride': 5, 'wing': 6, 'suspension': 0, 'pit': 17},   // Hungary (hu)
    '13': {'ride': 6, 'wing': -2, 'suspension': 2, 'pit': 24},  // Italy (it)
    '15': {'ride': 6, 'wing': 5, 'suspension': 0, 'pit': 20},   // Japan (jp)
    '6': {'ride': 11, 'wing': 9, 'suspension': 0, 'pit': 16},   // Monaco (mc)
    '23': {'ride': 3, 'wing': 2, 'suspension': 1, 'pit': 19},   // Mexico (mx)
    '2': {'ride': 6, 'wing': 1, 'suspension': 1, 'pit': 22},    // Malaysia (my)
    '24': {'ride': 2, 'wing': 2, 'suspension': 1, 'pit': 21},   // Russia (ru)
    '14': {'ride': 8, 'wing': 7, 'suspension': 0, 'pit': 20},   // Singapore (sg)
    '7': {'ride': 6, 'wing': 2, 'suspension': 1, 'pit': 18},    // Turkey (tr)
    '25': {'ride': 2, 'wing': 2, 'suspension': 1, 'pit': 16},   // USA (us)
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

class CircularProgressButton extends StatelessWidget {
  final double progress; // Progress value from 0 to 100
  final String label; // Label to display in the center
  final VoidCallback onPressed; // Button callback
  final double size; // Size of the circular progress indicator
  final Color backgroundColor; // Color of the background arc

  const CircularProgressButton({
    super.key,
    required this.progress,
    required this.label,
    required this.onPressed,
    this.size = 50.0,
    this.backgroundColor = const Color.fromARGB(0, 255, 255, 255),
  });
  
  Color _getProgressColor() {
    // Otherwise, determine color based on progress
      final List<MapEntry<double, Color>> colorStops = [
    MapEntry(0.0, Colors.red), 
     
    MapEntry(90.0, Colors.orange),          
    MapEntry(100.0, Colors.green),       // 100% progress - Green
  ];
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
   return Colors.blue;
  }
  String _getDisplayLabel() {
    // If label is 'Engine' and progress is 100, return '1'
    if (label == 'Engine' && progress < 100) {
      return 'Replace';
    }
     if (label != 'Engine' && progress == 100) {
      return 'Parts';
    }

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

class CircularProgressPainter extends CustomPainter {
  final double progress; // Value between 0.0 and 1.0
  final Color progressColor;
  final Color backgroundColor;
  
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
  // Placeholder implementation
  if (fireUpData is Map) {
    
    fireUpData['preCache']?['p=cars']?['vars']?['totalParts'] = extractDataValueFromHtml(fireUpData['preCache']?['p=cars']?['vars']?['totalParts'],'totalParts');
    fireUpData['preCache']?['p=cars']?['vars']?['totalEngines'] = extractDataValueFromHtml(fireUpData['preCache']?['p=cars']?['vars']?['totalEngines'],'totalEngines');
    fireUpData['preCache']?['p=cars']?['vars']?['c1CarBtn'] = extractDataValueFromHtml(fireUpData['preCache']?['p=cars']?['vars']?['c1CarBtn'].split(' ').last,'');
    fireUpData['preCache']?['p=cars']?['vars']?['c2CarBtn'] = extractDataValueFromHtml(fireUpData['preCache']?['p=cars']?['vars']?['c2CarBtn'].split(' ').last,'');
    fireUpData['preCache']?['p=cars']?['vars']?['c1Condition'] = extractDataValueAttribute(fireUpData['preCache']?['p=cars']?['vars']?['c1Condition']);
    fireUpData['preCache']?['p=cars']?['vars']?['c2Condition'] = extractDataValueAttribute(fireUpData['preCache']?['p=cars']?['vars']?['c2Condition']);
    fireUpData['preCache']?['p=cars']?['vars']?['c2Engine'] = extractDataValueAttribute(fireUpData['preCache']?['p=cars']?['vars']?['c2Engine']);
    fireUpData['preCache']?['p=cars']?['vars']?['c1Engine'] = extractDataValueAttribute(fireUpData['preCache']?['p=cars']?['vars']?['c1Engine']);
    fireUpData['preCache']?['p=cars']?['vars']?['carAttributes'] = parseCarAttributes(fireUpData['preCache']?['p=cars']?['vars']?['carAttributes']);
    return Map<String, dynamic>.from(fireUpData);
  } else {
    // Handle other data types or return an empty map if data is not as expected.
    print('Warning: fireUpData is not a Map. Cannot parse/sanitize.');
    return {};
  }
}

String extractDataValueFromHtml(String htmlString, String elementId) {
    if (htmlString.isEmpty) {
      return '';
    }
    final document = parse(htmlString);
    final element = document.getElementById(elementId);
    return element?.text ?? ''; // Return empty string if element not found
  }
  String? extractDataValueAttribute(String htmlString ) {
    if (htmlString.isEmpty) {
      return null;
    }
    final wrapFragment ='<html><body>$htmlString</body></html>'; // Wrap the HTML string in a body tag
    final document = parse(wrapFragment);

    final element = document.querySelector('.ratingCircle');
    final attribute = element?.attributes['data-value'];

    return attribute;
  }

Map<String, int> parseCarAttributes(String htmlString) {
  final Map<String, int> attributes = {};
  
  // Parse the HTML
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
    value: '60',
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

// Return the pre-built items directly
List<DropdownMenuItem<String>> buildStrategyDropdownItems() {
  return _strategyDropdownItems;
}

    final pushLevelFactorMap = {
      '100': 0.02,
      '80': 0.01,
      '60': 0.0,
      '40': -0.004,
      '20': -0.007,
    };

    int hashCode(String string) {
  int hash = 0;
  for (int i = 0; i < string.length; i++) {
    int code = string.codeUnitAt(i);
    hash = ((hash << 5) - hash + code) & 0xFFFFFFFF;
  }
  // Convert to signed 32-bit integer
  return hash >= 0x80000000 ? hash - 0x100000000 : hash;
}

List<Map<String, String>> parseRaces(String htmlString) {
  // Wrap the HTML string in a table to make it valid HTML
  final wrappedHtml = '<table>$htmlString</table>';
  
  // Parse the HTML
  final document = parse(wrappedHtml);
  
  // Get all table rows
  final rows = document.querySelectorAll('tr');
  
  List<Map<String, String>> races = [];
  
  for (var row in rows) {
    try {
      // Extract the race ID from the href attribute
      final anchor = row.querySelector('a[href*="id="]');
      final href = anchor?.attributes['href'] ?? '';
      
      // Use RegExp to extract the ID
      final idMatch = RegExp(r'id=(\d+)').firstMatch(href);
      final id = idMatch?.group(1) ?? '';
      
      // Extract the date from the first td
      final firstTd = row.querySelector('td');
      final dateText = firstTd?.text ?? '';
      final date = dateText;
      
      // Extract the track code from the flag class
      final imgElement = row.querySelector('img.flag');
      final flagClass = imgElement?.attributes['class'] ?? '';
      final trackMatch = RegExp(r'f-([a-z]{2})').firstMatch(flagClass);
      final track = trackMatch?.group(1) ?? '';
      
      // Extract the league from the span with class 'grey'
      final leagueSpan = row.querySelector('span.grey');
      final league = leagueSpan?.text ?? '';
      
      // Create a map with the extracted data
      final raceInfo = {
        'id': id,
        'date': date,
        'track': track,
        'league': league,
      };
      
      races.add(raceInfo);
    } catch (e) {
      debugPrint('Error parsing row: $e');
    }
  }
  
  return races;
}
