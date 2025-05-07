import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/driver.dart'; // We'll need the Driver model

List<Driver> parseDriversFromHtml(String htmlString) {
  final document = html_parser.parse(htmlString);
  final List<Driver> drivers = [];

  // Find driver names
  final driverNameDivs = document.querySelectorAll('.driverName');

  // Find driver attributes from hoverData
  final driverAttributesSpans = document.querySelectorAll('.hoverData');

  // Find contract info
  final contractTds = document.querySelectorAll('[id^="nDriverC"]');

  for (int i = 0; i < driverNameDivs.length; i++) {
    // Extract name - correctly combining first name and last name
    final nameElement = driverNameDivs[i];
    final nameText = nameElement.text.trim();
    final nameSpan = nameElement.querySelector('.medium');

    String firstName, lastName;
    if (nameSpan != null) {
      lastName = nameSpan.text.trim();
      // Remove the lastName and any whitespace/newlines to get firstName
      firstName = nameText.replaceAll(lastName, '').trim();
      // Further clean up any newlines
      firstName = firstName.replaceAll('\n', '').trim();
    } else {
      // Fallback if structure isn't as expected
      final parts = nameText.split('\n');
      firstName = parts[0].trim();
      lastName = parts.length > 1 ? parts[1].trim() : '';
    }

    final fullName = '$firstName $lastName';

    // Extract attributes
    final attributesData = driverAttributesSpans[i].attributes['data-driver'] ?? '';
    final attributes = attributesData.split(',').map((attr) {
      // Convert to appropriate type (number or empty string)
      if (attr.isEmpty) return '';
      return double.tryParse(attr) ?? attr;
    }).toList();

    // Extract contract
    final contract = contractTds[i].text.trim();

    drivers.add(Driver(
        name: fullName,
        attributes: attributes,
        contract: contract
    ));
  }

  return drivers;
}

List<List<List<dynamic>>> extractStrategyData(Map<String, dynamic> jsonData, String d1PushLevel, String? d2PushLevel) {
  List<List<List<dynamic>>> allStrategies = [];

  // Process first strategy (d1) - always included
  allStrategies.add(_extractStrategySet(jsonData, 'd1', d1PushLevel));

  // Process second strategy (d2) if d2Pits is not 0 and d2PushLevel is provided
  if (jsonData['d2Pits'] != 0 && d2PushLevel != null) {
    allStrategies.add(_extractStrategySet(jsonData, 'd2', d2PushLevel));
  }

  return allStrategies;
}

// Helper function to extract a strategy set
List<List<dynamic>> _extractStrategySet(Map<String, dynamic> jsonData, String prefix, String pushLevel) {
  var document = html_parser.parse(jsonData['${prefix}FuelOrLaps']);
  List<List<dynamic>> strategyData = [];

  for (int i = 1; i <= 5; i++) {
    var lapsInput = document.querySelector('input[name="laps$i"]');
    var fuelInput = document.querySelector('input[name="fuel$i"]');

    strategyData.add([
      jsonData['${prefix}s${i}Tyre'],
      lapsInput?.attributes['value'] ?? '',
      fuelInput?.attributes['value'] ?? '',
      pushLevel // Use the passed pushLevel
    ]);
  }

  return strategyData;
}

List<dynamic> parseSponsorsFromHtml(String html) {
  final document = html_parser.parse(html);
  final sponsors = [];

  // Loop through each sponsor table
  for (final sponsorTable in document.querySelectorAll("table.acp")) {
    final sponsorName = sponsorTable.querySelector("th")?.text.trim() ?? "";
    int sponsorNumber;
    String income;

    // Extract income
    final incomeSpan = sponsorTable.querySelector(".token-cost"); // Primary sponsor has token-cost class
    if (incomeSpan != null) {
      income = incomeSpan.text.trim();
      sponsorNumber = 1;
    } else {
      sponsorNumber = 2;
      // Ensure there are enough rows and cells before accessing
      final rows = sponsorTable.querySelectorAll("tr");
      if (rows.length > 1) {
        final cells = rows[1].querySelectorAll("td");
        if (cells.length > 1) {
          income = cells[1].text.trim();
        } else {
          income = ""; // Default if structure is not as expected
        }
      } else {
        income = ""; // Default if structure is not as expected
      }
    }

    // Extract bonus
    String bonus = "";
    final rows = sponsorTable.querySelectorAll("tr");
    if (rows.length > 2) {
      final cells = rows[2].querySelectorAll("td");
      if (cells.length > 1) {
        bonus = cells[1].text.trim();
      }
    }
    
    // Extract contract duration
    String contractDuration = "";
    if (rows.length > 3) {
      final cells = rows[3].querySelectorAll("td");
      if (cells.length > 1) {
        contractDuration = cells[1].text.trim();
      }
    }

    sponsors.add({
      "number": sponsorNumber,
      "Sponsor": sponsorName,
      "Income": income,
      "Bonus": bonus,
      "Contract": contractDuration
    });
  }
  return sponsors;
}

Map<String, List<String>> parsePickSponsorData(Map<String, dynamic> jsonData, int number) {
  final String parser = number == 1 ? 'span' : 'td';

  final incomeFragment = jsonData['vars']['row2'];
  final wrappedIncomeHtml = html_parser.parse('<table><tr>$incomeFragment</tr></table>');
  final incomeSoup = wrappedIncomeHtml.querySelectorAll(parser);

  final bonusFragment = jsonData['vars']['row3'];
  final wrappedBonusHtml = html_parser.parse('<table><tr>$bonusFragment</tr></table>');
  final bonusSoup = wrappedBonusHtml.querySelectorAll('td');

  final idFragment = jsonData['vars']['row1'];
  final wrappedIdHtml = html_parser.parse('<table><tr>$idFragment</tr></table>');
  final idSoup = wrappedIdHtml.querySelectorAll('img');

  final incomeList = incomeSoup.map((element) => element.text.trim()).toList();
  final bonusList = bonusSoup.map((element) => element.text.trim()).toList();
  final idList = idSoup.map((e) {
    final src = e.attributes['src'] ?? '';
    final filename = src.split('/').last;
    final nameOnly = filename.split('.').first;
    return nameOnly;
  }).toList();

  return {
    'incomeList': incomeList,
    'bonusList': bonusList,
    'idList': idList,
  };
}

// Placeholder for parseRaces - definition not found in original igp_client.dart
// List<dynamic> parseRaces(String htmlSrc) {
//   // Implementation would go here
//   return [];
// }

// Placeholder for parseRaceReport - definition not found in original igp_client.dart
// Map<String, dynamic> parseRaceReport(Map<String, dynamic> vars) {
//   // Implementation would go here
//   return {};
// }

// Placeholder for parseDriverResult - definition not found in original igp_client.dart
// List<dynamic> parseDriverResult(String htmlResults) {
//   // Implementation would go here
//   return [];
// }

// Placeholder for parseBest - definition not found in original igp_client.dart
// int parseBest(String ratingHtml, int tierFactor) {
//   // Implementation would go here
//   return 0;
// }

int parseBest(String htmlString, int tierFactor) {
  final document = html_parser.parse(htmlString);
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

// Placeholder for isChecked - definition not found in original igp_client.dart
// bool isChecked(String checkHtml) {
//   // Implementation would go here
//   return false;
// }
String extractDate(String text) {
  // Remove any hidden spans and links
  final strippedText = text.replaceAll(RegExp(r'<[^>]*>'), '');

  // Extract the date part, assuming it's at the end of the text
  final dateRegex = RegExp(r'(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})');
  final match = dateRegex.firstMatch(strippedText);

  return match?.group(1) ?? strippedText.trim();
}
List<Map<String, dynamic>> parseRaces(String htmlString) {
  // Wrap the HTML string in a table to make it valid HTML
  final wrappedHtml = '<table>$htmlString</table>';

  // Parse the HTML
  final document = html_parser.parse(wrappedHtml);

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

  final document = html_parser.parse(html);
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

  final document = html_parser.parse(html);
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

  final document = html_parser.parse(html);
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