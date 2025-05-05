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

List<Map<String, dynamic>> parseRaces(String htmlString) {
  // Wrap the HTML string in a table to make it valid HTML
  final wrappedHtml = '<table>$htmlString</table>';
  
  // Parse the HTML
  final document = parse(wrappedHtml);
  
  // Get all table rows
  final rows = document.querySelectorAll('tr');
  
  List<Map<String, dynamic>> races = [];
  
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
      final img = row.querySelector('img[class*="f-"]');
      final classAttr = img?.attributes['class'];
      final track = RegExp(r'f-([a-z]{2})').firstMatch(classAttr ?? '')?.group(1);

      final textNode = row.querySelector('td:nth-child(1)');
      final leagueSpan = row.querySelector('span.grey');
      final league = leagueSpan?.text ?? '';
      final text = textNode?.text.trim().replaceAll(league, "").trim();
      //final track = trackMatch?.group(1) ?? '';
      //final text = trackMatch?.group(2) ?? '';
      
      
      // Create a map with the extracted data
      final raceInfo = {
        'id': id,
        'date': extractDate(date),
        'track': track,
        'league': league,
        'text': text 
      };
      //debugPrint(raceInfo['date']);
      races.add(raceInfo);
    } catch (e) {
      debugPrint('Error parsing row: $e');
    }
  }
  
  return races;
}

String extractDate(String text) {
  // Remove any hidden spans and links
  final strippedText = text.replaceAll(RegExp(r'<[^>]*>'), '');
  
  // Extract the date part, assuming it's at the end of the text
  final dateRegex = RegExp(r'(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})');
  final match = dateRegex.firstMatch(strippedText);
  
  return match?.group(1) ?? strippedText.trim();
}

Map<dynamic,dynamic> parseRaceReport(Map jsonData) {
  // Wrap the HTML string in a table to make it valid HTML
  final wrappedHtmlRace = '<table>${jsonData['rResult']}</table>';
  final wrappedHtmlQualifying = '<table>${jsonData['qResult']}</table>';
  final wrappedHtmlPractice = '<table>${jsonData['pResult']}</table>';


  final raceName = jsonData['raceName'] ?? ''; //to parse
  final raceRules = jsonData['rRules'] ?? ''; //to parse

  final raceResults = parseRaceResults(wrappedHtmlRace);
  final qualifyingResults = parsePQResults(wrappedHtmlQualifying);
  final practiceResults = parsePQResults(wrappedHtmlPractice);
  
 
  
  try{
      final Map reportInfo = {
        'raceName': raceName,
        'raceResults': raceResults,
        'qualifyingResults':qualifyingResults,
        'practiceResults':practiceResults
       
      };
      return reportInfo;
    } catch (e) {
      debugPrint('Error parsing row: $e');
    }
  
return {}; // Return an empty map in case of error or if try block fails
  
 
}


List<dynamic> parseRaceResults(String html) {
  
  final document = parse(html);
  final rows = document.querySelectorAll('tr');
  final List results = [];
  Map<String,dynamic> driverRow;
  final RegExp idRegExp = RegExp(r'id=(\d+)');
  for (final row in rows) {
     final myTeam = row.className.contains('myTeam');
     final tds = row.querySelectorAll('td');
     final team = tds[1].querySelector('.teamName')?.text.trim() ?? '';
     final driverName =  tds[1].text.trim().replaceAll(team, "").trim();
     final raceTime = tds[2].text.trim();
     final driverReportId = idRegExp.firstMatch(tds[2].querySelector('a')?.attributes['href']??'')?.group(1)??'';
     final bestLap = tds[3].text.trim();
     final topSpeed = tds[4].text.trim();
     final pits = tds[5].text.trim();
     final points = tds[6].text.trim();
     
     
     driverRow = {
      'driver':driverName,
      'team':team,
      'raceTime':raceTime,
      'bestLap':bestLap,
      'topSpeed':topSpeed,
      'pits':pits,
      'points':points,
      'myTeam':myTeam,
      'driverReportId':driverReportId
     };
     results.add(driverRow);
  }
  return results;

}

List<dynamic> parsePQResults(String html) {
  
  final document = parse(html);
  final rows = document.querySelectorAll('tr');
  final List results = [];
  Map<String,dynamic> driverRow;

  if(rows.length>1){
    for (final row in rows) {
     final myTeam = row.className.contains('myTeam');
     final tds = row.querySelectorAll('td');
     final team = tds[1].querySelector('.teamName')?.text.trim() ?? '';
     final driverName =  tds[1].text.trim().replaceAll(team, "").trim();
     final lapTime = tds[2].text.trim();
     final gap = tds[3].text.trim();
     final tyre = tds[4].className.replaceAll('ts-', '');

     driverRow = {
      'driver':driverName,
      'team':team,
      'lapTime':lapTime,
      'tyre': tyre,
      'myTeam':myTeam,
      'gap':gap
     };
     results.add(driverRow);
     }
     return results;
  
  }
  return [{
      'driver':'',
      'team':'',
      'lapTime':'',
      'tyre': '',
      'myTeam':'',
      'gap':''
     }];
  
  

}

List<dynamic> parseDriverResult(String html) {
  
  final document = parse(html);
  final rows = document.querySelector('tbody')?.querySelectorAll('tr') ?? [];
  final List results = [];

    for (final row in rows) {
     final pitstop = row.className.contains('pit');
     Map info;
     final tds = row.querySelectorAll('td');
     if(pitstop){
      final span = tds[1].querySelectorAll('span');
      String duration = '';
      String tyre;
      if(span.length >= 2){
           duration = span[0].text;
           tyre = span[1].text;
  
      }else{
         tyre = getTyreCode(span[0].text);
      }
      
       info = {
        'tyre': tyre,
        'duration': duration
      };
     }else{

      final lap = tds[0].text;
      final time = tds[1].text;
      final gap = tds[2].text;
      final average = tds[3].text;
      final pos = tds[4].text;
      final tyreWear = tds[5].text;
      final fuel = tds[6].text;
      
      info = {
      'lap':lap,
      'time':time,
      'gap':gap,
      'average': average,
      'pos':pos,
      'tyreWear':tyreWear,
      'fuel':fuel,
     };

     }

     results.add(info);
     }
  
     return results;


}


// Function to get tyre code from name
String getTyreCode(String tyreName) {
  // Map of tyre names to their corresponding codes
  final tyreMap = {
    // English
    'Full wet tyres': 'W',
    'Intermediate wet tyres': 'I',
    'Hard tyres': 'H',
    'Medium tyres': 'M',
    'Soft tyres': 'S',
    'Super soft tyres': 'SS',
    
    // Italian
    'Pneumatici da bagnato': 'W',
    'Pneumatici intermedi': 'I',
    'Pneumatici duri': 'H',
    'Pneumatici medi': 'M',
    'Pneumatici morbidi': 'S',
    'Pneumatici super morbidi': 'SS',
    
    // Spanish
    'Neumáticos de Lluvia': 'W',
    'Neumáticos Intermedios': 'I',
    'Neumáticos Duros': 'H',
    'Neumáticos Medios': 'M',
    'Neumáticos Blandos': 'S',
    'Neumáticos Súper Blandos': 'SS',
    
    // German
    'Vollregen-Reifen': 'W',
    'Intermediate Reifen': 'I',
    'Hart Reifen': 'H',
    'Medium Reifen': 'M',
    'Soft Reifen': 'S',
    'Super Soft Reifen': 'SS',
    
    // Portuguese
    'Pneus de chuva': 'W',
    'Pneus intermediários': 'I',
    'Pneus duros': 'H',
    'Pneus médios': 'M',
    'Pneus macios': 'S',
    'Pneus super macios': 'SS',
    
    // Russian
    'Дождевые шины': 'W',
    'Промежуточные шины': 'I',
    'Твердые шины': 'H',
    'Средние шины': 'M',
    'Мягкие шины': 'S',
    'Супермягкие шины': 'SS',
    
    // French
    'Pneus pluie': 'W',
    'Pneus intermédiaires humides': 'I',
    'Pneus durs': 'H',
    'Pneus moyens': 'M',
    'Pneus tendres': 'S',
    'Pneus super tendres': 'SS',
  };
  
  // Return the tyre code, defaulting to 'M' if not found
  return tyreMap[tyreName] ?? 'M';
}
/// Function to get the asset path for a given tyre code.
String getTyreAssetPath(String tyreCode) {
  // Assuming tyre images are named like '_S.png', '_M.png' etc. in assets/tyres/
  // and the tyreCode is already the single letter code (S, M, H, I, W, SS)
  final validTyreCodes = ['S', 'M', 'H', 'I', 'W', 'SS'];
  if (validTyreCodes.contains(tyreCode)) {
    return 'assets/tyres/_$tyreCode.png';
  }
  // Return a default or placeholder path if the code is not recognized
  return 'assets/tyres/_M.png'; // Default to Medium tyre asset
}

int parseBest(String htmlString, int tierFactor) {
  final document = parse(htmlString);
  final svg = document.querySelector('svg');

  if (svg != null) {
    String? style = svg.attributes['style'];
    if (style != null && style.contains('calc(')) {
      String percentagePart = style.split('calc(')[1].split('%')[0];
      int value = int.tryParse(percentagePart) ?? 0;
      return value * tierFactor;
    }
  }

  return 0;
}

bool isChecked(String htmlString) {
  final document = parse(htmlString);
  final input = document.querySelector('input');
  return input?.attributes.containsKey('checked') ?? false;
}