import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart'; // May be needed for file path resolution if relative path fails

import '../igp_client.dart'; // Import Account
import '../utils/helpers.dart' as helpers; // Import helpers for hashCode
import '../utils/math_utils.dart'; // Import Track for track info
import 'dart:developer' as developer; // For logging

class StrategySaveLoadPopup extends StatefulWidget {
  final Account account;
  final int carIndex;

  const StrategySaveLoadPopup({
    super.key,
    required this.account,
    required this.carIndex,
  });

  @override
  _StrategySaveLoadPopupState createState() => _StrategySaveLoadPopupState();
}

class _StrategySaveLoadPopupState extends State<StrategySaveLoadPopup> {
  Map<String, dynamic> _savedStrategies = {};
  bool _isLoading = true;
  String? _error;
  late String _trackCode;
  late String _saveFilePath;

  @override
  void initState() {
    super.initState();
    _trackCode = widget.account.raceData?['vars']?['trackId']?.toString() ?? 'unknown';
    // Define the path relative to the Flutter project root
    // Assuming the Flutter project is in 'igp_app' and save.json is one level up in 'iGPeasy'
    _saveFilePath = '../save.json'; // Relative path
    _loadSavedStrategies();
  }

  Future<void> _loadSavedStrategies() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final file = File(_saveFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        // Handle potential empty file or invalid JSON
        if (content.trim().isEmpty) {
           _savedStrategies = {};
        } else {
          final decoded = jsonDecode(content) as Map<String, dynamic>?; // Make nullable
          if (decoded != null && decoded.containsKey('save') && decoded['save'] is Map && decoded['save'][_trackCode] != null) {
             // Ensure the track data is also a map
             if (decoded['save'][_trackCode] is Map) {
                _savedStrategies = Map<String, dynamic>.from(decoded['save'][_trackCode]);
             } else {
                developer.log('Track data for $_trackCode is not a Map: ${decoded['save'][_trackCode]}', name: 'StrategySaveLoadPopup');
                _savedStrategies = {}; // Treat invalid track data as empty
             }
          } else {
            _savedStrategies = {}; // No 'save' key or no strategies for this track yet
          }
        }
      } else {
        _savedStrategies = {}; // File doesn't exist
      }
    } catch (e, stackTrace) {
      developer.log('Error loading strategies: $e\n$stackTrace', name: 'StrategySaveLoadPopup');
      _error = 'Error loading strategies: $e';
      _savedStrategies = {};
    } finally {
      // Ensure widget is still mounted before calling setState
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _saveCurrentStrategy() async {
     if (!mounted) return; // Check if widget is still in the tree
    setState(() { _isLoading = true; _error = null; }); // Show loading indicator

    try {
      // 1. Get current strategy data
      List<dynamic> currentParsedStrategy = widget.account.raceData?['parsedStrategy']?[widget.carIndex] ?? [];
      int numberOfPits = widget.account.raceData?['vars']?['d${widget.carIndex + 1}Pits'] ?? 0;
      int numberOfSegments = numberOfPits + 1;
      int raceLaps = int.tryParse(widget.account.raceData?['vars']?['raceLaps']?.toString() ?? '0') ?? 0;
      String trackCode = widget.account.raceData?['vars']?['trackId']?.toString() ?? 'unknown';
      String raceLength = "100"; // Defaulting to 100%

      // 2. Construct JSON to save
      Map<String, dynamic> stintsToSave = {};
      int currentTotalLaps = 0;
      for (int i = 0; i < numberOfSegments; i++) {
        if (i < currentParsedStrategy.length && currentParsedStrategy[i] is List && currentParsedStrategy[i].length >= 4) {
          String tyre = currentParsedStrategy[i][0]?.toString() ?? 'ts-M';
          String lapsStr = currentParsedStrategy[i][1]?.toString() ?? '0';
          int laps = int.tryParse(lapsStr) ?? 0;
          String push = currentParsedStrategy[i][3]?.toString() ?? '60';

          stintsToSave[i.toString()] = {
            'tyre': tyre,
            'laps': lapsStr,
            'push': push,
          };
          currentTotalLaps += laps;
        }
      }

       // Prevent saving if there are no valid stints
      if (stintsToSave.isEmpty) {
        if (mounted) {
          setState(() {
            _error = "Cannot save empty or invalid strategy.";
            _isLoading = false;
          });
        }
        return;
      }


      Map<String, dynamic> strategyJson = {
        'stints': stintsToSave,
        'length': raceLength,
        'track': trackCode,
        'laps': {
          'total': raceLaps,
          'doing': currentTotalLaps,
        }
      };

      // 3. Calculate hash
      String strategyString = jsonEncode(strategyJson);
      String hash = helpers.hashCode(strategyString).toString();

      // 4. Read save.json
      final file = File(_saveFilePath);
      Map<String, dynamic> allSaves;
       try {
         if (await file.exists()) {
           final content = await file.readAsString();
           if (content.trim().isEmpty) {
             allSaves = {'save': {}}; // Handle empty file
           } else {
             allSaves = jsonDecode(content) as Map<String, dynamic>? ?? {'save': {}};
           }
         } else {
           allSaves = {'save': {}};
         }
       } catch (e) {
          developer.log('Error reading or decoding save.json: $e', name: 'StrategySaveLoadPopup');
          allSaves = {'save': {}}; // Start fresh if file is corrupt
       }


      // 5. Update save.json data (with safety checks)
      if (allSaves['save'] == null || allSaves['save'] is! Map) {
        allSaves['save'] = {};
      }
      if (allSaves['save'][trackCode] == null || allSaves['save'][trackCode] is! Map) {
        allSaves['save'][trackCode] = {};
      }
      // Ensure the inner map is mutable if it came from JSON decode
      allSaves['save'][trackCode] = Map<String, dynamic>.from(allSaves['save'][trackCode]);
      allSaves['save'][trackCode][hash] = strategyJson;


      // 6. Write save.json
      final encoder = JsonEncoder.withIndent('    ');
      await file.writeAsString(encoder.convert(allSaves));

      developer.log('Strategy saved with hash: $hash', name: 'StrategySaveLoadPopup');

      // 7. Reload strategies in UI
      await _loadSavedStrategies(); // This already calls setState if mounted

    } catch (e, stackTrace) {
      developer.log('Error saving strategy: $e\n$stackTrace', name: 'StrategySaveLoadPopup');
       if (mounted) {
         setState(() {
           _error = 'Error saving strategy: $e';
         });
       }
    } finally {
       if (mounted) {
         setState(() {
           _isLoading = false;
         });
       }
    }
  }

 void _loadStrategy(String hash) {
    developer.log('Load button pressed for hash: $hash', name: 'StrategySaveLoadPopup');
    try {
      // 1. Get strategy data for hash from _savedStrategies
      if (!_savedStrategies.containsKey(hash)) {
        throw Exception('Selected strategy hash not found.');
      }
      Map<String, dynamic> loadedStrategyData = Map<String, dynamic>.from(_savedStrategies[hash]);
      Map<String, dynamic> loadedStints = Map<String, dynamic>.from(loadedStrategyData['stints'] ?? {});

      if (loadedStints.isEmpty) {
        throw Exception('Selected strategy has no stints defined.');
      }

      // 2. Determine the number of pits
      int numberOfPits = loadedStints.length - 1;
      if (numberOfPits < 0) numberOfPits = 0;

      // 3. Update widget.account.raceData['vars']['d${widget.carIndex + 1}Pits']
      String pitKey = 'd${widget.carIndex + 1}Pits';
      // Ensure nested maps exist before assigning
      widget.account.raceData ??= {};
      widget.account.raceData!['vars'] ??= {};
      widget.account.raceData!['vars']![pitKey] = numberOfPits;


      // 4. Reconstruct the parsedStrategy list
      List<dynamic> newParsedStrategy = [];
      List<String> sortedKeys = loadedStints.keys.toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

      for (String key in sortedKeys) {
        Map<String, dynamic> stint = loadedStints[key];
        String tyre = stint['tyre']?.toString() ?? 'ts-M';
        String laps = stint['laps']?.toString() ?? '0';
        String push = stint['push']?.toString() ?? '60';

        // Reconstruct the list: [tyre, laps, placeholder1, push, placeholder2]
        newParsedStrategy.add([tyre, laps, null, push, null]);
      }

      // Ensure parsedStrategy list exists and has the correct index
       widget.account.raceData!['parsedStrategy'] ??= [];
       while (widget.account.raceData!['parsedStrategy'].length <= widget.carIndex) {
         widget.account.raceData!['parsedStrategy'].add([]);
       }

      widget.account.raceData!['parsedStrategy'][widget.carIndex] = newParsedStrategy;

      developer.log('Strategy loaded successfully for hash: $hash', name: 'StrategySaveLoadPopup');

      // 5. Close popup and indicate success
      if (mounted) { // Check if mounted before interacting with context
        Navigator.of(context).pop(true); // Indicate success
      }

    } catch (e, stackTrace) {
      developer.log('Error loading strategy: $e\n$stackTrace', name: 'StrategySaveLoadPopup');
       if (mounted) { // Check if mounted before showing SnackBar
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error loading strategy: $e'), backgroundColor: Colors.red),
         );
       }
    }
  }


  Widget _buildCurrentStrategyPreview() {
    List<dynamic> currentStrategy = widget.account.raceData?['parsedStrategy']?[widget.carIndex] ?? [];
    final pitValue = widget.account.raceData?['vars']?['d${widget.carIndex + 1}Pits'];
    int numberOfPits = pitValue is int ? pitValue : (pitValue is String ? int.tryParse(pitValue) ?? 0 : 0);
    
    int numberOfSegments = numberOfPits + 1;

    List<Widget> stintWidgets = [];
    for (int i = 0; i < numberOfSegments; i++) {
       if (i < currentStrategy.length && currentStrategy[i] is List && currentStrategy[i].length >= 2) {
         String tyreAsset = currentStrategy[i][0]?.toString() ?? 'unknown';
         String laps = currentStrategy[i][1]?.toString() ?? '?';
         stintWidgets.add(_buildStintPreview(tyreAsset, laps));
       }
    }
     if (stintWidgets.isEmpty) {
      return Center(child: Text('No strategy data', style: TextStyle(fontSize: 10, color: Colors.grey)));
    }

    // Use a Row directly inside Expanded in the build method, or constrain width here if needed
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: stintWidgets,
      ),
    );
  }

  Widget _buildSavedStrategyPreview(Map<String, dynamic> strategyData) {
    Map<String, dynamic> stints = strategyData['stints'] ?? {};
    List<Widget> stintWidgets = [];
    if (stints.isEmpty) {
       return Center(child: Text('No stint data', style: TextStyle(fontSize: 10, color: Colors.grey)));
    }
    List<String> sortedKeys = stints.keys.toList()..sort((a, b) => int.parse(a).compareTo(int.parse(b)));

    for (String key in sortedKeys) {
      Map<String, dynamic> stint = Map<String, dynamic>.from(stints[key]); // Ensure it's a map
      String tyreAsset = stint['tyre']?.toString() ?? 'unknown';
      String laps = stint['laps']?.toString() ?? '?';
      stintWidgets.add(_buildStintPreview(tyreAsset, laps));
    }
     if (stintWidgets.isEmpty) {
      return Center(child: Text('No stints', style: TextStyle(fontSize: 10, color: Colors.grey)));
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: stintWidgets,
      ),
    );
   }

   Widget _buildStintPreview(String tyreAsset, String laps) {
     final validTyreAsset = RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(tyreAsset);
     final imageName = tyreAsset.startsWith('ts-') ? tyreAsset.substring(3) : tyreAsset;
     final imagePath = 'assets/tyres/$imageName.png';
     final displayLaps = int.tryParse(laps) != null ? laps : '?';

     return Padding(
       padding: const EdgeInsets.symmetric(horizontal: 1.0),
       child: Tooltip( // Add tooltip to show full details on hover
         message: 'Tyre: $tyreAsset\nLaps: $laps',
         child: Stack(
           alignment: Alignment.center,
           children: [
             if (validTyreAsset && imageName.isNotEmpty)
               Image.asset(
                 imagePath,
                 width: 28,
                 height: 28,
                 errorBuilder: (context, error, stackTrace) {
                   return Container(
                     width: 28, height: 28,
                     child: Icon(Icons.help_outline, size: 14, color: Colors.grey[600]),
                   );
                 },
               )
             else
               Container(
                 width: 28, height: 28,
                 child: Icon(Icons.help_outline, size: 14, color: Colors.grey[600]),
               ),
             Text(
               displayLaps,
               style: TextStyle(
                 color: Colors.white,
                 fontWeight: FontWeight.bold,
                 fontSize: 10,
                 shadows: [
                   Shadow(blurRadius: 1.0, color: Colors.black.withOpacity(0.7)),
                 ],
               ),
             ),
           ],
         ),
       ),
     );
   }


  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Save/Load Strategy - Track: $_trackCode'),
      content: SizedBox(
        width: double.maxFinite,
        // Use a fixed height or constrain dynamically if needed
        // height: MediaQuery.of(context).size.height * 0.6, // Example: 60% of screen height
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // --- Header Row ---
            Padding(
              padding: const EdgeInsets.only(bottom: 15.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically
                children: [
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveCurrentStrategy, // Disable button when loading
                    icon: Icon(Icons.save, size: 16),
                    label: Text('Save Current'),
                    style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                  ),
                  SizedBox(width: 8), // Add spacing
                  Expanded(
                    child: Container( // Container to constrain preview height
                      height: 35, // Adjust height as needed
                      alignment: Alignment.center,
                      child: _buildCurrentStrategyPreview(),
                    ),
                  ),
                   SizedBox(width: 8), // Add spacing
                  IconButton(
                    icon: Icon(Icons.close),
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            Divider(),
            // --- Saved Strategies List ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: Text('Available Strategies:', style: Theme.of(context).textTheme.titleMedium),
            ),
            // Conditional content based on loading/error state
            _buildSavedStrategiesList(),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('Close'),
        ),
      ],
    );
  }

  // Helper widget to build the list section
  Widget _buildSavedStrategiesList() {
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Expanded(child: Center(child: Text(_error!, style: TextStyle(color: Colors.red))));
    }
    if (_savedStrategies.isEmpty) {
      return const Expanded(child: Center(child: Text('No saved strategies for this track.')));
    }

    // Use Expanded + ListView for scrollable content
    return Expanded(
      child: ListView.builder(
        shrinkWrap: true, // Important within Column
        itemCount: _savedStrategies.length,
        itemBuilder: (context, index) {
          String hash = _savedStrategies.keys.elementAt(index);
          Map<String, dynamic> strategyData = _savedStrategies[hash];
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 2.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                   child: Container( // Container to constrain preview height
                      height: 35, // Match header preview height
                      alignment: Alignment.centerLeft, // Align preview left
                      child: _buildSavedStrategyPreview(strategyData),
                    ),
                ),
                 SizedBox(width: 8), // Add spacing
                ElevatedButton(
                  onPressed: () => _loadStrategy(hash),
                  child: Text('Load'),
                   style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}