import 'dart:math';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse; 

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
        'ae': {'ride': 6, 'wing': 1, 'suspension': 1, 'pit': 23},
        'at': {'ride': 4, 'wing': 0, 'suspension': 2, 'pit': 27},
        'au': {'ride': 9, 'wing': 4, 'suspension': 1, 'pit': 24},
        'az': {'ride': 8, 'wing': 1, 'suspension': 1, 'pit': 17},
        'be': {'ride': 6, 'wing': 3, 'suspension': 1, 'pit': 15},
        'bh': {'ride': 4, 'wing': 0, 'suspension': 2, 'pit': 23},
        'br': {'ride': 4, 'wing': 2, 'suspension': 1, 'pit': 21},
        'ca': {'ride': 4, 'wing': -1, 'suspension': 2, 'pit': 17},
        'cn': {'ride': 2, 'wing': 2, 'suspension': 1, 'pit': 26},
        'de': {'ride': 4, 'wing': 2, 'suspension': 1, 'pit': 17},
        'es': {'ride': 2, 'wing': 5, 'suspension': 0, 'pit': 25},
        'eu': {'ride': 6, 'wing': 5, 'suspension': 0, 'pit': 17},
        'fr': {'ride': 8, 'wing': 2, 'suspension': 1, 'pit': 20},
        'gb': {'ride': 4, 'wing': 0, 'suspension': 2, 'pit': 23},
        'hu': {'ride': 5, 'wing': 6, 'suspension': 0, 'pit': 17},
        'it': {'ride': 6, 'wing': -2, 'suspension': 2, 'pit': 24},
        'jp': {'ride': 6, 'wing': 5, 'suspension': 0, 'pit': 20},
        'mc': {'ride': 11, 'wing': 9, 'suspension': 0, 'pit': 16},
        'mx': {'ride': 3, 'wing': 2, 'suspension': 1, 'pit': 19},
        'my': {'ride': 6, 'wing': 1, 'suspension': 1, 'pit': 22},
        'ru': {'ride': 2, 'wing': 2, 'suspension': 1, 'pit': 21},
        'sg': {'ride': 8, 'wing': 7, 'suspension': 0, 'pit': 20},
        'tr': {'ride': 6, 'wing': 2, 'suspension': 1, 'pit': 18},
        'us': {'ride': 2, 'wing': 2, 'suspension': 1, 'pit': 16},
      },
      // pro
      2: {
        'ae': {'ride': 13, 'wing': 3, 'suspension': 1, 'pit': 23},
        'at': {'ride': 9, 'wing': 0, 'suspension': 2, 'pit': 27},
        'au': {'ride': 19, 'wing': 8, 'suspension': 1, 'pit': 24},
        'az': {'ride': 17, 'wing': 3, 'suspension': 1, 'pit': 17},
        'be': {'ride': 12, 'wing': 6, 'suspension': 1, 'pit': 15},
        'bh': {'ride': 8, 'wing': 0, 'suspension': 2, 'pit': 23},
        'br': {'ride': 8, 'wing': 5, 'suspension': 1, 'pit': 21},
        'ca': {'ride': 9, 'wing': -3, 'suspension': 2, 'pit': 17},
        'cn': {'ride': 5, 'wing': 5, 'suspension': 1, 'pit': 26},
        'de': {'ride': 8, 'wing': 5, 'suspension': 1, 'pit': 17},
        'es': {'ride': 5, 'wing': 10, 'suspension': 0, 'pit': 25},
        'eu': {'ride': 12, 'wing': 10, 'suspension': 0, 'pit': 17},
        'fr': {'ride': 17, 'wing': 5, 'suspension': 1, 'pit': 20},
        'gb': {'ride': 9, 'wing': 0, 'suspension': 2, 'pit': 23},
        'hu': {'ride': 10, 'wing': 13, 'suspension': 0, 'pit': 17},
        'it': {'ride': 12, 'wing': -5, 'suspension': 2, 'pit': 24},
        'jp': {'ride': 12, 'wing': 10, 'suspension': 0, 'pit': 20},
        'mc': {'ride': 22, 'wing': 18, 'suspension': 0, 'pit': 16},
        'mx': {'ride': 7, 'wing': 5, 'suspension': 1, 'pit': 19},
        'my': {'ride': 12, 'wing': 3, 'suspension': 1, 'pit': 22},
        'ru': {'ride': 4, 'wing': 5, 'suspension': 1, 'pit': 21},
        'sg': {'ride': 17, 'wing': 14, 'suspension': 0, 'pit': 20},
        'tr': {'ride': 13, 'wing': 5, 'suspension': 1, 'pit': 18},
        'us': {'ride': 4, 'wing': 4, 'suspension': 1, 'pit': 16},
      },
      // elite
      3: {
        'ae': {'ride': 25, 'wing': 5, 'suspension': 1, 'pit': 23},
        'at': {'ride': 18, 'wing': 0, 'suspension': 2, 'pit': 27},
        'au': {'ride': 38, 'wing': 15, 'suspension': 1, 'pit': 24},
        'az': {'ride': 33, 'wing': 5, 'suspension': 1, 'pit': 17},
        'be': {'ride': 23, 'wing': 12, 'suspension': 1, 'pit': 15},
        'bh': {'ride': 15, 'wing': 0, 'suspension': 2, 'pit': 23},
        'br': {'ride': 15, 'wing': 10, 'suspension': 1, 'pit': 21},
        'ca': {'ride': 18, 'wing': -5, 'suspension': 2, 'pit': 17},
        'cn': {'ride': 10, 'wing': 10, 'suspension': 1, 'pit': 26},
        'de': {'ride': 15, 'wing': 10, 'suspension': 1, 'pit': 17},
        'es': {'ride': 10, 'wing': 20, 'suspension': 0, 'pit': 25},
        'eu': {'ride': 23, 'wing': 20, 'suspension': 0, 'pit': 17},
        'fr': {'ride': 33, 'wing': 10, 'suspension': 1, 'pit': 20},
        'gb': {'ride': 18, 'wing': 0, 'suspension': 2, 'pit': 23},
        'hu': {'ride': 20, 'wing': 25, 'suspension': 0, 'pit': 17},
        'it': {'ride': 23, 'wing': -10, 'suspension': 2, 'pit': 24},
        'jp': {'ride': 23, 'wing': 20, 'suspension': 0, 'pit': 20},
        'mc': {'ride': 43, 'wing': 35, 'suspension': 0, 'pit': 16},
        'mx': {'ride': 13, 'wing': 10, 'suspension': 1, 'pit': 19},
        'my': {'ride': 23, 'wing': 5, 'suspension': 1, 'pit': 22},
        'ru': {'ride': 8, 'wing': 10, 'suspension': 1, 'pit': 21},
        'sg': {'ride': 33, 'wing': 27, 'suspension': 0, 'pit': 20},
        'tr': {'ride': 25, 'wing': 10, 'suspension': 1, 'pit': 18},
        'us': {'ride': 8, 'wing': 7, 'suspension': 1, 'pit': 16},
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
    Key? key,
    required this.progress,
    required this.label,
    required this.onPressed,
    this.size = 50.0,
    this.backgroundColor = const Color.fromARGB(0, 255, 255, 255),
  }) : super(key: key);
  
  Color _getProgressColor() {
    // Otherwise, determine color based on progress
      final List<MapEntry<double, Color>> colorStops = [
    MapEntry(60.0, Colors.red),          // 50% progress - Red
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
    debugPrint(attribute); // Debug print to check if the element is found
    return attribute;
  }
