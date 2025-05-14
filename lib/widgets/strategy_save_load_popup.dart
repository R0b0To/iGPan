import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart'; // May be needed for file path resolution if relative path fails
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart'; // For exporting files
import 'dart:typed_data'; // For Uint8List

import 'dart:math';
import '../igp_client.dart'; // Import Account
import '../utils/helpers.dart' as helpers; // Import helpers for hashCode
import 'dart:developer' as developer; // For logging

enum _PopupMenuOptions { importSave, exportSave }

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
    _trackCode = widget.account.raceData?['track'].info['trackCode'] ?? 'unknown';
    _getSaveFilePath().then((path) {
      _saveFilePath = path;
      _loadSavedStrategies();
    });
  }

  Future<String> _getSaveFilePath() async {
    final directory = await getApplicationDocumentsDirectory();
    
    return '${directory.path}/save.json';
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
        if (content.trim().isEmpty) {
           _savedStrategies = {};
        } else {
          final decoded = jsonDecode(content) as Map<String, dynamic>?; 
          if (decoded != null && decoded.containsKey('save') && decoded['save'] is Map && decoded['save'][_trackCode] != null) {
             if (decoded['save'][_trackCode] is Map) {
                _savedStrategies = Map<String, dynamic>.from(decoded['save'][_trackCode]);
             } else {
                developer.log('Track data for $_trackCode is not a Map: ${decoded['save'][_trackCode]}', name: 'StrategySaveLoadPopup');
                _savedStrategies = {}; 
             }
          } else {
            _savedStrategies = {}; 
          }
        }
      } else {
        _savedStrategies = {}; 
      }
    } catch (e, stackTrace) {
      developer.log('Error loading strategies: $e\n$stackTrace', name: 'StrategySaveLoadPopup');
      _error = 'Error loading strategies: $e';
      _savedStrategies = {};
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

 Future<void> _deleteStrategy(String hash) async {
   if (!mounted) return;

   final confirmed = await showDialog<bool>(
     context: context,
     builder: (BuildContext context) {
       return AlertDialog(
         title: Text('Confirm Deletion'),
         content: Text('Are you sure you want to delete this saved strategy?'),
         actions: <Widget>[
           TextButton(
             onPressed: () => Navigator.of(context).pop(false), 
             child: Text('Cancel'),
           ),
           TextButton(
             onPressed: () => Navigator.of(context).pop(true), 
             child: Text('Delete', style: TextStyle(color: Colors.red)),
           ),
         ],
       );
     },
   );

   if (confirmed != true) {
     return; 
   }

   setState(() { _isLoading = true; _error = null; });

   try {
     final file = File(_saveFilePath);
     Map<String, dynamic> allSaves;
     try {
       if (await file.exists()) {
         final content = await file.readAsString();
         if (content.trim().isEmpty) {
           allSaves = {'save': {}};
         } else {
           allSaves = jsonDecode(content) as Map<String, dynamic>? ?? {'save': {}};
         }
       } else {
         allSaves = {'save': {}};
         throw Exception("Save file not found during delete operation.");
       }
     } catch (e) {
       developer.log('Error reading or decoding save.json during delete: $e', name: 'StrategySaveLoadPopup');
       throw Exception("Failed to read save file for deletion."); 
     }

     bool deleted = false;
     if (allSaves['save'] != null &&
         allSaves['save'] is Map &&
         allSaves['save'][_trackCode] != null &&
         allSaves['save'][_trackCode] is Map)
     {
        Map<String, dynamic> trackSaves = Map<String, dynamic>.from(allSaves['save'][_trackCode]);
        if (trackSaves.containsKey(hash)) {
          trackSaves.remove(hash);
          allSaves['save'][_trackCode] = trackSaves; 
          deleted = true;
        }
     }

     if (!deleted) {
       throw Exception("Strategy hash not found for deletion.");
     }

     final encoder = JsonEncoder.withIndent('    ');
     await file.writeAsString(encoder.convert(allSaves));

     developer.log('Strategy deleted with hash: $hash', name: 'StrategySaveLoadPopup');

     await _loadSavedStrategies(); 

   } catch (e, stackTrace) {
     developer.log('Error deleting strategy: $e\n$stackTrace', name: 'StrategySaveLoadPopup');
     if (mounted) {
       setState(() {
         _error = 'Error deleting strategy: $e';
         _isLoading = false; 
       });
     }
   }
 }


  Future<void> _saveCurrentStrategy() async {
     if (!mounted) return; 
    setState(() { _isLoading = true; _error = null; }); 

    try {
      List<dynamic> currentParsedStrategy = widget.account.raceData?['parsedStrategy']?[widget.carIndex] ?? [];
      final pitValue = widget.account.raceData?['vars']?['d${widget.carIndex + 1}Pits'];
      int numberOfPits = pitValue is int ? pitValue : (pitValue is String ? int.tryParse(pitValue) ?? 0 : 0);
      int numberOfSegments = numberOfPits + 1;
      int raceLaps = int.tryParse(widget.account.raceData?['vars']?['raceLaps']?.toString() ?? '0') ?? 0;
      String trackCode = widget.account.raceData?['track'].info['trackCode'] ?? 'unknown';
      String? raceLength = widget.account.raceData?['track']?.info[widget.account.raceData?['vars']?['raceLaps']?.toString()]?.toString();

      Map<String, dynamic> stintsToSave = {};
      int currentTotalLaps = 0;
      for (int i = 0; i < numberOfSegments; i++) {
        if (i < currentParsedStrategy.length && currentParsedStrategy[i] is List && currentParsedStrategy[i].length >= 4) {
          String tyre = currentParsedStrategy[i][0]?.toString() ?? 'ts-M';
          String lapsStr = currentParsedStrategy[i][1]?.toString() ?? '0';
          int laps = int.tryParse(lapsStr) ?? 0;
          String push = currentParsedStrategy[i][3]?.toString() ?? '60';

          stintsToSave[i.toString()] = {
            'tyre': 'ts-${tyre}',
            'laps': lapsStr,
            'push': push,
          };
          currentTotalLaps += laps;
        }
      }

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

      String strategyString = jsonEncode(strategyJson);
      String hash = helpers.hashCode(strategyString).toString();

      final file = File(_saveFilePath);
      Map<String, dynamic> allSaves;
       try {
         if (await file.exists()) {
           final content = await file.readAsString();
           if (content.trim().isEmpty) {
             allSaves = {'save': {}}; 
           } else {
             allSaves = jsonDecode(content) as Map<String, dynamic>? ?? {'save': {}};
           }
         } else {
           allSaves = {'save': {}};
         }
       } catch (e) {
          developer.log('Error reading or decoding save.json: $e', name: 'StrategySaveLoadPopup');
          allSaves = {'save': {}}; 
       }


      if (allSaves['save'] == null || allSaves['save'] is! Map) {
        allSaves['save'] = {};
      }
      if (allSaves['save'][trackCode] == null || allSaves['save'][trackCode] is! Map) {
        allSaves['save'][trackCode] = {};
      }
      allSaves['save'][trackCode] = Map<String, dynamic>.from(allSaves['save'][trackCode]);
      allSaves['save'][trackCode][hash] = strategyJson;


      final encoder = JsonEncoder.withIndent('    ');
      await file.writeAsString(encoder.convert(allSaves));

      developer.log('Strategy saved with hash: $hash', name: 'StrategySaveLoadPopup');

      await _loadSavedStrategies(); 

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
      if (!_savedStrategies.containsKey(hash)) {
        throw Exception('Selected strategy hash not found.');
      }
      Map<String, dynamic> loadedStrategyData = Map<String, dynamic>.from(_savedStrategies[hash]);
      Map<String, dynamic> loadedStints = Map<String, dynamic>.from(loadedStrategyData['stints'] ?? {});

      if (loadedStints.isEmpty) {
        throw Exception('Selected strategy has no stints defined.');
      }

      int numberOfPits = loadedStints.length - 1;
      if (numberOfPits < 0) numberOfPits = 0;

      String pitKey = 'd${widget.carIndex + 1}Pits';
      widget.account.raceData ??= {};
      widget.account.raceData!['vars'] ??= {};
      widget.account.raceData!['vars']![pitKey] = min(numberOfPits,4);


      List<dynamic> newParsedStrategy = [];
      List<String> sortedKeys = loadedStints.keys.toList()
        ..sort((a, b) => int.parse(a).compareTo(int.parse(b)));
          final pushLevelFactorMap = {
      '100': 0.02,
      '80': 0.01,
      '60': 0.0,
      '40': -0.004,
      '20': -0.007,
    };
      for (String key in sortedKeys) {
        Map<String, dynamic> stint = loadedStints[key];
        String? tyre = stint['tyre']?.toString().replaceFirst('ts-', '');
        String laps = stint['laps']?.toString() ?? '0';
        dynamic pushValue = stint['push'];
        String push;
        if (pushValue is int) {
          Map<int, String> pushMap = {
            1: '20',
            2: '40',
            3: '60',
            4: '80',
            5: '100',
          };
          push = pushMap[pushValue] ?? '60';
        } else {
          push = pushValue?.toString() ?? '60';
        }


        final pushFactor = pushLevelFactorMap[push] ?? 0.0;
        final fuelPerLap = (widget.account.raceData?['kmPerLiter'] + pushFactor) * widget.account.raceData?['track'].info['length'];
        double fuelEstimation = (fuelPerLap * int.tryParse(laps)) ?? 1;
         
        
        newParsedStrategy.add([tyre, laps, fuelEstimation, push]);
      }
     
      double totalFuel = 0.0;
      for (int i = 0; i < min(newParsedStrategy.length, 5); i++) {
      totalFuel += newParsedStrategy[i][2];
      
      if(widget.account.raceData?['vars']?['rulesJson']?['refuelling'] == '0'){
        newParsedStrategy[i][2] = 0;
      }else{
        newParsedStrategy[i][2] = newParsedStrategy[i][2].ceil(); 
      }
      widget.account.raceData!['parsedStrategy'][widget.carIndex][i]  = newParsedStrategy[i];
    }
      if(widget.account.raceData?['vars']?['rulesJson']?['refuelling'] == '0'){
        widget.account.raceData!['parsedStrategy'][widget.carIndex][0][2] = totalFuel.ceil();
        widget.account.raceData?['vars']['d${widget.carIndex + 1}AdvancedFuel'] = totalFuel.ceil(); 
      }
      
      developer.log('Strategy loaded successfully for hash: $hash', name: 'StrategySaveLoadPopup');

      if (mounted) { 
        Navigator.of(context).pop(true); 
      }

    } catch (e, stackTrace) {
      developer.log('Error loading strategy: $e\n$stackTrace', name: 'StrategySaveLoadPopup');
       if (mounted) { 
         ScaffoldMessenger.of(context).showSnackBar(
           SnackBar(content: Text('Error loading strategy: $e'), backgroundColor: Colors.red),
         );
       }
    }
  }

  Future<void> _importSave() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        File pickedFile = File(result.files.single.path!);
        String content = await pickedFile.readAsString();
        
        try {
          jsonDecode(content); 
        } catch (e) {
          throw Exception("Invalid JSON file selected.");
        }

        final confirmed = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Confirm Import'),
              content: Text('This will replace your current save data with the content of the selected file. Are you sure?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: Text('Cancel'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: Text('Replace', style: TextStyle(color: Colors.orange)),
                ),
              ],
            );
          },
        );

        if (confirmed == true) {
          final targetFile = File(_saveFilePath);
          await targetFile.writeAsString(content);
          developer.log('Save file imported from: ${pickedFile.path}', name: 'StrategySaveLoadPopup');
          await _loadSavedStrategies(); 
           if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Strategies imported successfully!'), backgroundColor: Colors.green),
            );
          }
        } else {
           if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Import cancelled.'), backgroundColor: Colors.grey),
            );
          }
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('No file selected for import.'), backgroundColor: Colors.orange),
          );
        }
      }
    } catch (e, stackTrace) {
      developer.log('Error importing save: $e\n$stackTrace', name: 'StrategySaveLoadPopup');
      if (mounted) {
        setState(() { _error = 'Error importing save: $e'; });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error importing save: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _exportSave() async {
    if (!mounted) return;
    setState(() { _isLoading = true; _error = null; });

    try {
      final file = File(_saveFilePath);
      if (await file.exists()) {
        final content = await file.readAsString();
        final fileName = "iGP_strategies_save_${DateTime.now().toIso8601String().split('T').first}";
        
        String? savedPath = await FileSaver.instance.saveAs(
            name: fileName, // Corrected parameter to 'name'
            bytes: Uint8List.fromList(utf8.encode(content)),
            ext: "json",
            mimeType: MimeType.json // Corrected to MimeType.json (lowercase j)
        );

        // saveAs might return null or an empty string if cancelled, or the path if successful.
        // The check for savedPath != null and savedPath.isNotEmpty is still valid.
        if (savedPath != null && savedPath.isNotEmpty) {
          developer.log('Save file exported to: $savedPath', name: 'StrategySaveLoadPopup');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Strategies exported successfully to $savedPath!'), backgroundColor: Colors.green),
            );
          }
        } else {
           if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Export cancelled or file not saved.'), backgroundColor: Colors.orange),
            );
          }
        }
      } else {
        throw Exception("Save file (save.json) not found for export.");
      }
    } catch (e, stackTrace) {
      developer.log('Error exporting save: $e\n$stackTrace', name: 'StrategySaveLoadPopup');
      if (mounted) {
        setState(() { _error = 'Error exporting save: $e'; });
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error exporting save: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() { _isLoading = false; });
      }
    }
  }

  Future<void> _handleMenuSelection(_PopupMenuOptions option) async {
    switch (option) {
      case _PopupMenuOptions.importSave:
        await _importSave();
        break;
      case _PopupMenuOptions.exportSave:
        await _exportSave();
        break;
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
      Map<String, dynamic> stint = Map<String, dynamic>.from(stints[key]); 
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
       child: SizedBox( 
         child: Stack(
           alignment: Alignment.center,
           children: [
             if (validTyreAsset && imageName.isNotEmpty)
               Image.asset(
                 imagePath,
                 width: 28,
                 height: 28,
                 scale: 1,
                 errorBuilder: (context, error, stackTrace) {
                   return Container(
                     width: 28, height: 28,
                     child: Icon(Icons.help_outline, size: 14, color: Colors.grey[600]),
                   );
                 },
               )
             else
               SizedBox(
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
  

      content: SizedBox(
        width: double.maxFinite, 

        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 6.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center, 
                children: [
                  ElevatedButton(
                    onPressed: _isLoading ? null : _saveCurrentStrategy, 
                    style: ElevatedButton.styleFrom(padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4)),
                    child: Icon(Icons.save, size: 16),
                  ),
                  
                  Expanded(
                    child: Container( 
                      height: 35, 
                      alignment: Alignment.center,
                      child: _buildCurrentStrategyPreview(),
                    ),
                  ),
                  PopupMenuButton<_PopupMenuOptions>(
                    icon: Icon(Icons.more_vert),
                    onSelected: _handleMenuSelection,
                    itemBuilder: (BuildContext context) => <PopupMenuEntry<_PopupMenuOptions>>[
                      const PopupMenuItem<_PopupMenuOptions>(
                        value: _PopupMenuOptions.importSave,
                        child: ListTile(leading: Icon(Icons.file_download), title: Text('Import Saves')),
                      ),
                      const PopupMenuItem<_PopupMenuOptions>(
                        value: _PopupMenuOptions.exportSave,
                        child: ListTile(leading: Icon(Icons.file_upload), title: Text('Export Saves')),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Divider(),
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 1.0),
              child: Text('Available Strategies:', style: Theme.of(context).textTheme.titleMedium),
            ),
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

  Widget _buildSavedStrategiesList() {
    if (_isLoading) {
      return const Expanded(child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) {
      return Expanded(child: Center(child: Text(_error!, style: TextStyle(color: Colors.red))));
    }
    if (_savedStrategies.isEmpty) {
      return const SizedBox(child: Center(child: Text('No saved strategies for this track.')));
    }

    return SizedBox(
      child: ListView.builder(
        
        shrinkWrap: true, 
        itemCount: _savedStrategies.length,
        itemBuilder: (context, index) {
          String hash = _savedStrategies.keys.elementAt(index);
          Map<String, dynamic> strategyData = _savedStrategies[hash];
          return Padding(
            
            padding: const EdgeInsets.symmetric(vertical: 4.0, horizontal: 0.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                   child: InkWell(
                      onTap: _isLoading ? null : () => _loadStrategy(hash),
                      child: Container(
                         height: 35,
                         alignment: Alignment.center,
                         child: _buildSavedStrategyPreview(strategyData),
                       ),
                   ),
                ),
                  IconButton(
                  icon: Icon(Icons.delete_outline, color: Colors.redAccent),
                  iconSize: 20,
                  constraints: BoxConstraints(),
                  padding: EdgeInsets.all(4),
                  onPressed: _isLoading ? null : () => _deleteStrategy(hash),
                ),
            
                
                
             
              ],
            ),
          );
        },
      ),
    );
  }
}