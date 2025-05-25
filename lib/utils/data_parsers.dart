import 'package:flutter/foundation.dart';
import 'package:html/parser.dart' as html_parser;
import '../models/driver.dart'; // We'll need the Driver model

// Parses driver information from an HTML string.
// Extracts details like name, attributes, and contract information for each driver.
List<Driver> parseDriversFromHtml(String htmlString) {
  final document = html_parser.parse(htmlString);
  final List<Driver> drivers = [];

  // Find driver names using the '.driverName' CSS class.
  final driverNameDivs = document.querySelectorAll('.driverName');

  // Find driver attributes from elements with the '.hoverData' CSS class.
  // These attributes are typically stored in a 'data-driver' HTML attribute.
  final driverAttributesSpans = document.querySelectorAll('.hoverData');

  // Find contract information.
  // `contractTds` refers to table data cells (<td> elements) that contain contract details.
  // The CSS selector '[id^="nDriverC"]' targets elements whose 'id' attribute starts with "nDriverC",
  // which is a common pattern for elements holding contract data in the source HTML.
  final contractTds = document.querySelectorAll('[id^="nDriverC"]');

  for (int i = 0; i < driverNameDivs.length; i++) {
    // Extract first and last names.
    // The full name is usually in a div with class '.driverName'.
    // The last name is often within a nested span with class '.medium'.
    // The logic is to get the full text, identify the last name, and then subtract it (and trim whitespace)
    // to get the first name. A fallback splits by newline if the '.medium' span isn't present.
    final nameElement = driverNameDivs[i];
    final nameText = nameElement.text.trim();
    final nameSpan = nameElement.querySelector('.medium');

    String firstName, lastName;
    if (nameSpan != null) {
      lastName = nameSpan.text.trim();
      // The first name is derived by taking the full text of the driver name element,
      // removing the last name (which is inside a '.medium' span), and trimming whitespace.
      // Newlines are also removed to ensure clean extraction.
      firstName = nameText.replaceAll(lastName, '').trim().replaceAll('\n', '').trim();
    } else {
      // Fallback if the expected '.medium' span for the last name is not found.
      // Assumes the name parts might be separated by a newline.
      final parts = nameText.split('\n');
      firstName = parts[0].trim();
      lastName = parts.length > 1 ? parts[1].trim() : '';
    }

    final fullName = '$firstName $lastName';

    // Extract driver attributes from the 'data-driver' attribute.
    // This attribute contains a comma-separated string of values representing various driver skills or stats.
    // Each part is parsed into a double if possible, otherwise kept as a string (or empty string if originally empty).
    final attributesData = driverAttributesSpans[i].attributes['data-driver'] ?? '';
    final attributes = attributesData.split(',').map((attr) {
      // Convert to appropriate type (number or empty string)
      if (attr.isEmpty) return ''; // Keep empty attributes as empty strings.
      return double.tryParse(attr) ?? attr; // Attempt to parse as double, otherwise keep as string.
    }).toList();

    // Extract contract information from the corresponding <td> element.
    final contract = RegExp(r'\d+').firstMatch(contractTds[i].text.trim())?.group(0) ?? '';;

    drivers.add(Driver(
        name: fullName,
        attributes: attributes,
        contract: contract
    ));
  }

  return drivers;
}

// Parses strategy data, which may include multiple strategies (d1, d2), from JSON data.
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

// Helper function to extract a specific set of strategy data (e.g., for d1 or d2) from JSON.
// It parses HTML content within the JSON to find lap and fuel inputs.
List<List<dynamic>> _extractStrategySet(Map<String, dynamic> jsonData, String prefix, String pushLevel) {
  // The HTML containing fuel/lap inputs is stored within the JSON data under keys like 'd1FuelOrLaps'.
  var document = html_parser.parse(jsonData['${prefix}FuelOrLaps']);
  List<List<dynamic>> strategyData = [];

  for (int i = 1; i <= 5; i++) { // Loop through up to 5 stints for the strategy
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

// Parses sponsor information from an HTML string.
// It identifies sponsor tables, extracts details like name, income, bonus, and contract duration.
List<dynamic> parseSponsorsFromHtml(String html) {
  final document = html_parser.parse(html);
  final sponsors = [];

  // Loop through each sponsor table.
  // 'table.acp' selects <table> elements with the class 'acp'. 'acp' likely signifies tables containing active sponsor data.
  for (final sponsorTable in document.querySelectorAll("table.acp")) {
    final sponsorName = sponsorTable.querySelector("th")?.text.trim() ?? "";
    int sponsorNumber; // 1 for primary, 2 for secondary
    String income;

    // Extract income and determine sponsor type (primary/secondary).
    // Primary sponsors often have their income displayed in an element with class '.token-cost'.
    // If this class is present, it's sponsorNumber 1 (primary).
    final incomeSpan = sponsorTable.querySelector(".token-cost");
    if (incomeSpan != null) {
      // If '.token-cost' is found, it's the primary sponsor.
      income = incomeSpan.text.trim();
      sponsorNumber = 1; // Indicates primary sponsor
    } else {
      // If '.token-cost' is not found, assume it's a secondary sponsor (sponsorNumber 2).
      // Income for secondary sponsors is typically in the second row, second cell of the table.
      sponsorNumber = 2; // Indicates secondary sponsor
      final rows = sponsorTable.querySelectorAll("tr");
      if (rows.length > 1) { // Check if second row exists
        final cells = rows[1].querySelectorAll("td");
        if (cells.length > 1) { // Check if second cell exists
          income = cells[1].text.trim();
        } else {
          income = ""; // Default if structure is not as expected
        }
      } else {
        income = ""; // Default if structure is not as expected
      }
    }

    // Extract bonus.
    // The bonus information is typically located in the third row (index 2) and second cell (index 1) of the sponsor table.
    String bonus = "";
    final rows = sponsorTable.querySelectorAll("tr"); // Re-fetch rows or use existing if appropriate for clarity
    if (rows.length > 2) { // Check if the third row exists
      final cells = rows[2].querySelectorAll("td");
      if (cells.length > 1) { // Check if the second cell exists in that row
        bonus = cells[1].text.trim();
      }
    }
    
    // Extract contract duration.
    // The contract duration is typically found in the fourth row (index 3) and second cell (index 1).
    String contractDuration = "";
    // No need to re-fetch rows if 'rows' variable from bonus extraction is still in scope and valid.
    if (rows.length > 3) { // Check if the fourth row exists
      final cells = rows[3].querySelectorAll("td");
      if (cells.length > 1) { // Check if the second cell exists in that row
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

// Parses data for picking sponsors from a JSON object.
// This function handles slightly different HTML structures for primary vs. secondary sponsor choices.
Map<String, List<String>> parsePickSponsorData(Map<String, dynamic> jsonData, int number) {
  // Determine the correct HTML element tag to parse for income based on sponsor type.
  // For primary sponsors (`number == 1`), income data might be within <span> tags due to specific styling or structure.
  // For secondary sponsors, it's typically within <td> (table cell) tags as part of a standard table row.
  final String parser = number == 1 ? 'span' : 'td';

  // The JSON contains HTML fragments (e.g., for rows of a table like 'vars.row2').
  // These fragments are wrapped in `<table><tr>...</tr></table>` to create a valid, parsable HTML document structure.
  // This allows `html_parser` to correctly interpret and query these snippets as if they were part of a full table.
  final incomeFragment = jsonData['vars']['row2'];
  final wrappedIncomeHtml = html_parser.parse('<table><tr>$incomeFragment</tr></table>');
  final incomeSoup = wrappedIncomeHtml.querySelectorAll(parser); // Use the determined parser ('span' or 'td')

  // Parse bonus data (typically in <td> elements for both types)
  final bonusFragment = jsonData['vars']['row3'];
  final wrappedBonusHtml = html_parser.parse('<table><tr>$bonusFragment</tr></table>');
  final bonusSoup = wrappedBonusHtml.querySelectorAll('td');

  // Parse sponsor IDs, likely from <img> tags' src attributes
  final idFragment = jsonData['vars']['row1'];
  final wrappedIdHtml = html_parser.parse('<table><tr>$idFragment</tr></table>');
  final idSoup = wrappedIdHtml.querySelectorAll('img');

  final incomeList = incomeSoup.map((element) => element.text.trim()).toList();
  final bonusList = bonusSoup.map((element) => element.text.trim()).toList();
  // Extract sponsor IDs from the 'src' attribute of image tags, then clean them up to get just the filename/ID.
  final idList = idSoup.map((e) {
    final src = e.attributes['src'] ?? '';
    final filename = src.split('/').last; // Get 'sponsor_123.png'
    final nameOnly = filename.split('.').first; // Get 'sponsor_123'
    return nameOnly;
  }).toList();

  return {
    'incomeList': incomeList,
    'bonusList': bonusList,
    'idList': idList,
  };
}

// Parses a "best" value, likely a percentage, from an HTML string containing an SVG element.
// The `tierFactor` is a multiplier applied to the extracted percentage, possibly to scale it
// based on some category or tier (e.g., different racing tiers might have different base values).
int parseBest(String htmlString, int tierFactor) {
  final document = html_parser.parse(htmlString);
  final svg = document.querySelector('svg');

  if (svg != null) {
    String? style = svg.attributes['style'];
    // The percentage is often found within a 'style' attribute of an SVG element,
    // typically as part of a 'calc()' CSS function (e.g., "width: calc(75% - 10px);").
    // This function extracts the numerical part of that percentage.
    if (style != null && style.contains('calc(')) {
      // Example: style="... calc(25% ...)" -> extracts "25"
      String percentagePart = style.split('calc(')[1].split('%')[0];
      int value = int.tryParse(percentagePart) ?? 0;
      return value * tierFactor; // Apply the tierFactor multiplier.
    }
  }

  return 0; // Return 0 if parsing fails or SVG/style is not as expected.
}

// Extracts a date from a string, after cleaning HTML tags.
String extractDate(String text) {
  // Removes HTML tags (e.g., <span>, <a>) from the input text using a regular expression.
  // This is done because dates might be wrapped in such tags, or there might be hidden elements (like <span style="display:none">)
  // that could interfere with direct text extraction of the date. RegExp(r'<[^>]*>') matches any HTML tag.
  final strippedText = text.replaceAll(RegExp(r'<[^>]*>'), '');

  // The regular expression `r'(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})'` is designed to find dates
  // in formats like "DD MMM YYYY" (e.g., "1 Jan 2023" or "15 Jul 2024").
  // - `\d{1,2}`: Matches one or two digits (for the day).
  // - `\s+`: Matches one or more whitespace characters.
  // - `[A-Za-z]{3}`: Matches exactly three alphabetic characters (for the month abbreviation, case-insensitive).
  // - `\s+`: Matches one or more whitespace characters.
  // - `\d{4}`: Matches exactly four digits (for the year).
  // The parentheses `()` create a capturing group for the entire date string.
  final dateRegex = RegExp(r'(\d{1,2}\s+[A-Za-z]{3}\s+\d{4})');
  final match = dateRegex.firstMatch(strippedText);

  // Returns the captured date string (group 1) if a match is found, otherwise returns the trimmed original (stripped) text as a fallback.
  return match?.group(1) ?? strippedText.trim();
}

// Parses a list of races from an HTML string.
// Each race's details (ID, date, track, league, text) are extracted from table rows.
List<Map<String, dynamic>> parseRaces(String htmlString) {
  // The input `htmlString` is expected to be a series of <tr> elements.
  // Wrapping it in `<table>...</table>` makes it a valid HTML document for the parser.
  final wrappedHtml = '<table>$htmlString</table>';

  // Parse the HTML
  final document = html_parser.parse(wrappedHtml);

  // Get all table rows (each row represents a race).
  final rows = document.querySelectorAll('tr');

  List<Map<String, dynamic>> races = [];

  for (var row in rows) {
    try {
      // Extract the race ID.
      // The ID is found in the 'href' attribute of an anchor tag (<a>) that contains "id=".
      // Example: <a href="race.php?id=123">Race Name</a> -> extracts "123".
      final anchor = row.querySelector('a[href*="id="]'); // Selects <a> tags with 'href' containing 'id='.
      final href = anchor?.attributes['href'] ?? '';
      final idMatch = RegExp(r'id=(\d+)').firstMatch(href); // Regex to capture digits after 'id='.
      final id = idMatch?.group(1) ?? '';

      // Extract the date (from the first <td>, then processed by extractDate).
      final firstTd = row.querySelector('td');
      final dateText = firstTd?.text ?? '';
      final date = dateText; // This will be passed to extractDate for proper formatting.

      // Extract the track code.
      // The track code (e.g., "au" for Australia) is derived from a CSS class on an <img> tag (often a flag icon).
      // Example: <img class="f-gb" ...> -> extracts "gb".
      // 'img[class*="f-"]' selects <img> tags where the 'class' attribute contains "f-".
      final img = row.querySelector('img[class*="f-"]');
      final classAttr = img?.attributes['class'];
      // RegExp(r'f-([a-z]{2})') captures the two lowercase letters following "f-".
      final track = RegExp(r'f-([a-z]{2})').firstMatch(classAttr ?? '')?.group(1);

      // Extract league and race text/name.
      // The race name/text is in the first <td> (td:nth-child(1)).
      // League information is often within a <span class="grey"> inside this td.
      final textNode = row.querySelector('td:nth-child(1)');
      final leagueSpan = row.querySelector('span.grey'); // Selects <span class="grey">
      final league = leagueSpan?.text ?? '';
      // Remove league from the main text and trim whitespace to get the clean race name.
      final text = textNode?.text.trim().replaceAll(league, "").trim();


      final raceInfo = {
        'id': id,
        'date': extractDate(date), // Clean and format the extracted date string.
        'track': track,
        'league': league,
        'text': text
      };
      races.add(raceInfo);
    } catch (e) {
      debugPrint('Error parsing race row: $e');
    }
  }

  return races;
}

// Parses a comprehensive race report from JSON data.
// This includes the race name, and results for race, qualifying, and practice sessions
// by calling other specialized parsing functions.
Map<dynamic,dynamic> parseRaceReport(Map jsonData) {
  // HTML content for different sections (race, qualifying, practice) is provided in the JSON.
  // Each HTML string (e.g., jsonData['rResult']) is wrapped in a `<table>`
  // to ensure it's a parsable HTML document fragment for html_parser.
  final wrappedHtmlRace = '<table>${jsonData['rResult']}</table>';
  final wrappedHtmlQualifying = '<table>${jsonData['qResult']}</table>';
  final wrappedHtmlPractice = '<table>${jsonData['pResult']}</table>';


  final raceName = jsonData['raceName'] ?? ''; // Extract race name.
  // final raceRules = jsonData['rRules'] ?? ''; // Race rules, currently not used but parsed for potential future use.

  // Parse each section using dedicated functions.
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
      debugPrint('Error constructing race report: $e');
    }

return {}; // Return an empty map in case of error.
}

// Parses race results from an HTML string (expected to be table rows).
// For each driver, it extracts name, team, race time, best lap, top speed, pit stops, points,
// and a flag if the driver is in 'myTeam'. Also extracts a driver-specific report ID.
List<dynamic> parseRaceResults(String html) {
  final document = html_parser.parse(html); // Assumes html is already wrapped if necessary (e.g., in <table>).
  final rows = document.querySelectorAll('tr'); // Each <tr> is a driver's result line.
  final List results = [];
  Map<String,dynamic> driverRow;
  // RegExp to extract numeric ID from hrefs like "somepage.php?id=12345".
  final RegExp idRegExp = RegExp(r'id=(\d+)');

  for (final row in rows) {
     // Check if the row has the class 'myTeam', indicating the player's team.
     final myTeam = row.className.contains('myTeam');
     final tds = row.querySelectorAll('td'); // Get all cells (<td>) in the row.

     // Team name is usually within a span with class '.teamName' in the second cell (tds[1]).
     final team = tds[1].querySelector('.teamName')?.text.trim() ?? '';
     // Driver name is the text of the second cell, with the team name removed and then trimmed.
     final driverName =  tds[1].text.trim().replaceAll(team, "").trim();
     final raceTime = tds[2].text.trim(); // Race time/status from the third cell.
     // Driver report ID is extracted from a link usually found in the race time cell (tds[2]).
     final driverReportId = idRegExp.firstMatch(tds[2].querySelector('a')?.attributes['href']??'')?.group(1)??'';
     final bestLap = tds[3].text.trim(); // Best lap time from the fourth cell.
     final topSpeed = tds[4].text.trim(); // Top speed from the fifth cell.
     final pits = tds[5].text.trim(); // Number of pit stops from the sixth cell.
     final points = tds[6].text.trim(); // Points awarded from the seventh cell.

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

// Parses Practice or Qualifying (PQ) results from an HTML string (expected to be table rows).
// For each driver, it extracts name, team, lap time, gap to leader, and tyre compound used.
List<dynamic> parsePQResults(String html) {
  final document = html_parser.parse(html); // Assumes html is already wrapped.
  final rows = document.querySelectorAll('tr'); // Each <tr> represents a driver's PQ result.
  final List results = [];
  Map<String,dynamic> driverRow;

  if(rows.length > 1){ // Check if there are any data rows (e.g., beyond a potential header row).
    for (final row in rows) {
     // Identifies if the row relates to 'myTeam' by checking for the 'myTeam' class.
     final myTeam = row.className.contains('myTeam');
     final tds = row.querySelectorAll('td'); // Get all cells in the row.

     // Team name from a span with class '.teamName' in the second cell (tds[1]).
     final team = tds[1].querySelector('.teamName')?.text.trim() ?? '';
     // Driver name from the second cell (tds[1]), with team name removed and trimmed.
     final driverName =  tds[1].text.trim().replaceAll(team, "").trim();
     final lapTime = tds[2].text.trim(); // Lap time from the third cell.
     final gap = tds[3].text.trim(); // Gap to the leader/fastest from the fourth cell.
     // Tyre code is extracted from the CSS class of the fifth cell (tds[4]).
     // Classes are usually like 'ts-S', 'ts-M', so 'ts-' is removed to get the code (e.g., 'S', 'M').
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
  // Return a list with a default empty structure if no results are parsed (e.g., empty or header-only HTML).
  return [{
      'driver':'',
      'team':'',
      'lapTime':'',
      'tyre': '',
      'myTeam':'', // Should ideally be a boolean, but original was string.
      'gap':''
     }];
}

// Parses detailed results for a single driver from an HTML string, typically lap-by-lap data or pit stop information.
// It distinguishes between normal lap data rows and pitstop event rows based on CSS class.
List<dynamic> parseDriverResult(String html) {
  final document = html_parser.parse(html); // Assumes html is already wrapped.
  // Selects all <tr> elements within the first <tbody>. If no <tbody>, selects all <tr> from the parsed fragment.
  // This targets the rows containing lap data or pitstop info.
  final rows = document.querySelector('tbody')?.querySelectorAll('tr') ?? [];
  final List results = [];

    for (final row in rows) {
     // A row with class 'pit' indicates a pitstop event.
     final pitstop = row.className.contains('pit');
     Map info;
     final tds = row.querySelectorAll('td'); // Get all cells for the current row.

     if(pitstop){
      // For pitstop rows, extract tyre type and pitstop duration.
      // Data is usually within <span> elements in the second cell (tds[1]).
      final span = tds[1].querySelectorAll('span');
      String duration = '';
      String tyre;
      if(span.length >= 2){ // Expected structure: one span for duration, one for tyre name/code.
           duration = span[0].text; // First span is duration.
           tyre = span[1].text; // Second span is tyre.
      }else{
         // Fallback: if only one span, assume it's the tyre name and convert it to a standardized code.
         tyre = getTyreCode(span[0].text);
      }

       info = {
        'tyre': tyre, // Tyre used after pitstop or tyre info during pitstop.
        'duration': duration // Duration of the pitstop.
      };
     }else{
      // For regular lap data rows.
      final lap = tds[0].text;        // Lap number.
      final time = tds[1].text;       // Lap time.
      final gap = tds[2].text;        // Gap to leader or interval.
      final average = tds[3].text;    // Average speed or other metric.
      final pos = tds[4].text;        // Position at the end of the lap.
      final tyreWear = tds[5].text;   // Tyre wear percentage.
      final fuel = tds[6].text;       // Fuel remaining or used.

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

// Converts a full tyre name (potentially in various languages) to its corresponding short code.
// This mapping is essential for standardizing tyre data across different parts of the application
// and handling internationalized tyre names from the source HTML.
String getTyreCode(String tyreName) {
  // `tyreMap` stores translations of tyre names to a single character code (e.g., 'S' for Soft).
  // This allows the application to handle tyre information consistently, regardless of the source language.
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
    'Pneus super macios': 'SS', // Portuguese for Super Soft

    // Russian
    'Дождевые шины': 'W', // Russian for Full Wet
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
    'Pneus super tendres': 'SS', // French for Super Soft
  };

  // Looks up the tyreName in the map. If not found, defaults to 'M' (Medium).
  // This default is important for gracefully handling unrecognized or new tyre names.
  return tyreMap[tyreName] ?? 'M';
}

// Generates the asset path for a given tyre code.
// This function is used to dynamically load tyre images in the UI based on the tyre code.
String getTyreAssetPath(String tyreCode) {
  // Assumes tyre images are stored in 'assets/tyres/' and named with a prefix (e.g., '_')
  // followed by the tyre code and extension (e.g., '_S.png').
  // `tyreCode` is expected to be a standardized single or double letter code (S, M, H, I, W, SS).
  final validTyreCodes = ['S', 'M', 'H', 'I', 'W', 'SS'];
  if (validTyreCodes.contains(tyreCode)) {
    return 'assets/tyres/_$tyreCode.png'; // Constructs the path like 'assets/tyres/_S.png'.
  }
  // If the tyreCode is not recognized or invalid, it returns a path to a default tyre image (Medium tyre).
  // This prevents errors if an unexpected tyre code is encountered and ensures some image is always shown.
  return 'assets/tyres/_M.png';
}

// Parses staff information from an HTML string.
// Extracts details for Chief Designer (cd), Technical Director (td), Driver (dr), and Reserve staff.
Map<String, dynamic> parseStaffFromHtml(Map<String, dynamic> staffData) {
  final Map<String, dynamic> parsedStaff = {
    'cd': {},
    'td': {},
    'dr': {},
    'reserve': []
  };

  // Helper function to parse individual staff member HTML
  Map<String, dynamic> _parseIndividualStaff(String? htmlString) {
    if (htmlString == null || htmlString.isEmpty) {
      return {};
    }
    final document = html_parser.parse(htmlString);
    final nameElement = document.querySelector('.driverName');
    final nameText = nameElement?.text.trim() ?? '';
    final nameSpan = nameElement?.querySelector('.medium');

    String firstName, lastName;
    if (nameSpan != null) {
      lastName = nameSpan.text.trim();
      firstName = nameText.replaceAll(lastName, '').trim().replaceAll('\n', '').trim();
    } else {
      final parts = nameText.split('\n');
      firstName = parts.isNotEmpty ? parts[0].trim() : '';
      lastName = parts.length > 1 ? parts[1].trim() : '';
    }
    final fullName = '$firstName $lastName'.trim();

    final contractElement = document.querySelector('[id^="nStaffC"], [id^="nDriverC"]');
    final contract = RegExp(r'\d+').firstMatch(contractElement?.text.trim() ?? '')?.group(0) ?? '';

    final idElement = document.querySelector('a[href*="&id="]');
    final href = idElement?.attributes['href'] ?? '';
    final idMatch = RegExp(r'id=(\d+)').firstMatch(href);
    final id = idMatch?.group(1) ?? '';

    return {
      'name': fullName,
      'contract': contract,
      'id': id,
    };
  }

  // Parse main staff members
  parsedStaff['cd'] = _parseIndividualStaff(staffData['designInfo']);
  parsedStaff['td'] = _parseIndividualStaff(staffData['engineerInfo']);
  parsedStaff['dr'] = _parseIndividualStaff(staffData['trainInfo']);

  // Parse reserve staff
  final reserveStaffHtml = staffData['reserveStaff'] ?? '';
  final reserveDriverHtml = staffData['reserveDrivers'] ?? '';
  Map<String, dynamic> reserveStaff = {};
   if (reserveDriverHtml.isNotEmpty) {
    final document = html_parser.parse('<table><tbody>$reserveDriverHtml</tbody></table>');
    final rows = document.querySelectorAll('tr');

    for (final row in rows) {
      final tds = row.querySelectorAll('td');
      if (tds.isEmpty) continue;

      {
        // Parse Driver reserve staff
        // Driver info is in the last few tds
        final driverNameElement = row.querySelector('th');
        final driverNameText = driverNameElement?.text.trim() ?? '';
         final driverIdElement = driverNameElement?.querySelector('a[href*="&id="]');
        final driverHref = driverIdElement?.attributes['href'] ?? '';
        final driverIdMatch = RegExp(r'id=(\d+)').firstMatch(driverHref);
        final driverId = driverIdMatch?.group(1) ?? '';

        final driverContractElement = row.querySelector('[id^="nDriverC"]');
        final driverContract =  RegExp(r'\d+').allMatches(driverContractElement?.text.trim() ?? '').map((m) => m.group(0)).lastWhere((e) => true, orElse: () => '');
        reserveStaff = {
          'type': 'Driver',
          'name': driverNameText.replaceAll(RegExp(r'<[^>]*>'), '').trim(), // Remove potential HTML tags in name
          'contract': driverContract,
          'id': driverId,
        };
      }
       if (reserveStaff.isNotEmpty) {
         parsedStaff['reserve'].add(reserveStaff);
       }
    }
  }
  
  if (reserveStaffHtml.isNotEmpty) {
    final document = html_parser.parse('<table><tbody>$reserveStaffHtml</tbody></table>');
    final rows = document.querySelectorAll('tr');

    for (final row in rows) {
      final tds = row.querySelectorAll('td');
      if (tds.isEmpty) continue;

      String staffType = tds[0].text.trim();
    

      if (true) {
        // Parse CD, TD, DR reserve staff
        final nameElement = row.querySelector('th');
        final nameText = nameElement?.text.trim() ?? '';
        final idElement = nameElement?.querySelector('a[href*="&id="]');
        final href = idElement?.attributes['href'] ?? '';
        final idMatch = RegExp(r'id=(\d+)').firstMatch(href);
        final id = idMatch?.group(1) ?? '';

        final contractElement = row.querySelector('[id^="nStaffC"]');
        final contract = contractElement?.text.trim() ?? '';

        reserveStaff = {
          'type': staffType,
          'name': nameText.replaceAll(RegExp(r'<[^>]*>'), '').trim(), // Remove potential HTML tags in name
          'contract': contract,
          'id': id,
        };
      } 
    }
  }

  return parsedStaff;
}
      
