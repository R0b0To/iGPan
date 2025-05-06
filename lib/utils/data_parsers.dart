import 'dart:convert';
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