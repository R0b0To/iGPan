import 'package:flutter_spinbox/flutter_spinbox.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../utils/helpers.dart';
import 'package:flutter/material.dart';
import '../igp_client.dart'; // Import Account and other necessary definitions
import '../utils/math_utils.dart'; // Import math_utils for wearCalc and Track
import 'strategy_save_load_popup.dart'; // Import the new popup widget

// --- StrategyContent Widget ---

class StrategyContent extends StatefulWidget { // Changed to StatefulWidget
  final Account account; // Use specific Account type
  final int carIndex;

  const StrategyContent({super.key, required this.account, required this.carIndex});

  @override
  _StrategyContentState createState() => _StrategyContentState();
}

class _StrategyContentState extends State<StrategyContent> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _numberOfPits = 1; // State variable for number of pits
  bool _ignoreAdvanced = false; // State variable for advanced setting
  List<String> availableTyres = ['SS', 'S', 'M', 'H', 'I', 'W']; // Available tyre types

  @override
  void initState() {
    super.initState();
    // Initialize state variables from account data
    String pitKey = 'd${widget.carIndex + 1}Pits';
    String ignoreAdvancedKey = 'd${widget.carIndex + 1}IgnoreAdvanced';
    if (widget.account.raceData != null ) {
      var pitValue = widget.account.raceData!['vars']?[pitKey];
      _numberOfPits = pitValue is int ? pitValue : (pitValue is String ? int.tryParse(pitValue) ?? 0 : 0);
      _ignoreAdvanced = widget.account.raceData!['vars']?[ignoreAdvancedKey] ?? false; // Initialize _ignoreAdvanced
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Important for AutomaticKeepAliveClientMixin

    // Get raceLaps safely
    final raceLaps = int.tryParse(widget.account.raceData?['vars']?['raceLaps']?.toString() ?? '0') ?? 0;
    final trackId = widget.account.raceData?['vars']?['trackId']?.toString() ?? '1'; // Assuming '1' as a default if trackId is null
    final track = Track(trackId, raceLaps); // Create Track instance
    widget.account.raceData?['track'] = track;
    
    final calculatedWear = wearCalc(widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['carAttributes']?['tyre_economy']?.toDouble() ?? 0.0, track);

    // Calculate number of segments based on state variable
    final numberOfSegments = _numberOfPits + 1; // Segments = Pits + 1
    final fuelEconomy = widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['carAttributes']?['fuel_economy']?.toDouble() ?? 0.0;
    final trackLength = (track.info['length'] as num?)?.toDouble() ?? 0.0;
    final kmPerLiter = fuelCalc(fuelEconomy);
    widget.account.raceData?['kmPerLiter'] = kmPerLiter; // Update account data with trackId
    // Calculate total laps before building the UI
    int calculatedTotalLaps = 0;
    List<dynamic> carStrategy = (numberOfSegments > 0 &&
        widget.account.raceData != null &&
        widget.account.raceData!['parsedStrategy'] != null &&
        widget.account.raceData!['parsedStrategy'] is List &&
        widget.carIndex < widget.account.raceData!['parsedStrategy'].length &&
        widget.account.raceData!['parsedStrategy'][widget.carIndex] is List)
        ? widget.account.raceData!['parsedStrategy'][widget.carIndex]
        : [];

    for (int i = 0; i < numberOfSegments; i++) { // Iterate only up to numberOfSegments
      if (i < carStrategy.length &&
          carStrategy[i] is List && carStrategy[i].length >= 2 &&
          carStrategy[i][1] is String) {
        String labelText = carStrategy[i][1];
        calculatedTotalLaps += int.tryParse(labelText) ?? 0; // Safely parse laps
      }
    }
    int totalLaps = calculatedTotalLaps; // Assign calculated value to totalLaps
    
    // Calculate total fuel
    double totalFuel = 0.0;
    
    final pushLevelFactorMap = {
      '100': 0.02,
      '80': 0.01,
      '60': 0.0,
      '40': -0.004,
      '20': -0.007,
    };
        
        
    for (int i = 0; i < numberOfSegments; i++) {
      if (i < carStrategy.length &&
          carStrategy[i] is List && carStrategy[i].length >= 4 && // Ensure push level exists
          carStrategy[i][1] is String && carStrategy[i][3] is String) {
        final segmentLaps = int.tryParse(carStrategy[i][1]) ?? 0;
        final pushLevel = carStrategy[i][3];
        final pushFactor = pushLevelFactorMap[pushLevel] ?? 0.0;
        // Ensure track.info['length'] is treated as double
        final fuelPerLap = ( kmPerLiter + pushFactor) * trackLength;
        final stintFuel = segmentLaps * fuelPerLap;
        totalFuel += stintFuel;
      }
    }
    final formattedTotalFuel = totalFuel.toStringAsFixed(1); // Format to 1 decimal place


    // Row 1: Spinbox/Text for pit stops and Laps Display
    Widget pitStopRow = Row(
      
      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Align items to the ends
      children: [
        
        // Button to the left of the Spinbox
        Padding(
          padding: const EdgeInsets.only(right:8.0), // Add some spacing to the right
          child: SizedBox(
          height: 30, // Match the height of the SpinBox
          child: ElevatedButton(
            onPressed: () async { // Make async to await dialog result
              final result = await showDialog<bool>( // Expect a boolean result
                context: context,
                builder: (BuildContext context) {
                  return StrategySaveLoadPopup(
                    account: widget.account,
                    carIndex: widget.carIndex,
                  );
                },
              );

              // If a strategy was loaded (result is true), refresh the state
              if (result == true && mounted) {
                setState(() {
                  // Re-initialize state variables based on potentially updated account data
                  String pitKey = 'd${widget.carIndex + 1}Pits';
                  var pitValue = widget.account.raceData!['vars']?[pitKey];
                  _numberOfPits = pitValue is int ? pitValue : (pitValue is String ? int.tryParse(pitValue) ?? 0 : 0);
                  // Add any other state variables that might change after loading a strategy
                });
              }
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(horizontal: 8.0), // Adjust padding
            ),
            child: Icon(MdiIcons.contentSaveAll),
          ),
          ),
        ),
        // Spinbox for pits
        SizedBox(
          
        width: 100.0, // Provide a fixed width
        height: 30,
        
        child: SpinBox(
        readOnly: true, 
        min: 1, // Minimum 0 pits
        max: 4, // Assuming a maximum of 4 pit stops based on headers
        value: _numberOfPits.toDouble(), // Use state variable
        iconSize: 20.0, // <<< Set your + and - icon size
        spacing: 0,
        decoration: InputDecoration(
          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0), // Adjust padding
          border: OutlineInputBorder(),
          
 
        ),
        textStyle: TextStyle(fontSize: 12), // Adjust text size
        onChanged: (value) {
          setState(() {
            _numberOfPits = value.toInt(); // Update state variable
            String pitKey = 'd${widget.carIndex + 1}Pits';
            if (widget.account.raceData != null && widget.account.raceData!['vars'] != null) {
              widget.account.raceData!['vars']?[pitKey] = _numberOfPits;
            }
          });
        },
        ),
        ),
        // Laps display
        Container( // Wrap the column in a Container for the border
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), // Border color
              width: 0.8, // Border width
            ),
            borderRadius: BorderRadius.zero, // Square corners
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Add padding inside the border
          child: Row( // Changed from Column to Row
            mainAxisAlignment: MainAxisAlignment.center, // Center horizontally
            crossAxisAlignment: CrossAxisAlignment.center, // Center vertically
            mainAxisSize: MainAxisSize.min, // Make the row take minimum space
            children: [
              Text(
                '$totalLaps/$raceLaps', // Combined text
                style: Theme.of(context).textTheme.bodyMedium, // Use a suitable style
                textAlign: TextAlign.center, // Center the text
              ),
            ],
          ),
        ),
      ],
    );

    // Strategy items, wear labels, and dropdowns arranged in columns per segment
    List<Widget> segmentWidgets = []; // Renamed to segmentWidgets

    
    // Ensure we have enough segments to match headers, adding placeholders if needed
    // Iterate through segments based on the number of pits
    for (int i = 0; i <= _numberOfPits; i++) { // Loop for _numberOfPits + 1 segments
      Widget headerWidget;
      Widget strategyItemWidget;
      Widget wearLabelWidget;
      Widget dropdownWidget;
    
      // Header for this segment
      String headerText = i == 0 ? 'Start' : 'Pit $i';
      headerWidget = Center(child: Text(headerText));

      // Check if data exists for this segment (and if it's within the actual strategy data length)
      if (i < carStrategy.length &&
          carStrategy[i] is List && carStrategy[i].length >= 2 &&
          carStrategy[i][0] is String && carStrategy[i][1] is String) {
        

        String tyreAsset = carStrategy[i][0];
        String labelText = carStrategy[i][1];
        String pushLevel = carStrategy[i][3] ?? '60'; // Default to '60' if not provided
        // totalLaps calculation moved above

        final validTyreAsset = RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(tyreAsset);
      
        if (validTyreAsset && tyreAsset.isNotEmpty) {
          // Wrap the Padding with GestureDetector
          strategyItemWidget = GestureDetector(
            
            onTap: () {
              _showEditStrategyDialog(i, tyreAsset, labelText, kmPerLiter, trackLength, pushLevelFactorMap);
            },
            child: Padding(
              
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Tooltip(
                message: '', // Updated tooltip
                child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/tyres/$tyreAsset.png',
                    width: 40,
                    height: 40,
                    errorBuilder: (context, error, stackTrace) {
                      return Container(
                        width: 40, height: 40,
                        color: Colors.grey[300],
                        child: Icon(Icons.tire_repair, size: 20, color: Colors.grey[600]),
                      );
                    },
                  ),
                  Text(
                    labelText,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      shadows: [
                        Shadow(blurRadius: 1.0, color: Colors.black.withOpacity(0.7)),
                      ],
                    ),
                  ),
                ],
                ),
              ),
            ),
          );
        } else {
          strategyItemWidget = _buildInvalidSegment(i, 'Invalid tyre');
        }
      
        // Wear label (Placeholder)
        
        final tyreWear = double.tryParse(calculatedWear[tyreAsset] ?? '0.0') ?? 0.0;
        final segmentLaps = int.tryParse(labelText) ?? 0;
        final stintWear = stintWearCalc(tyreWear, segmentLaps, track);
        wearLabelWidget = Text(stintWear);

        // Dropdown (Placeholder)
        dropdownWidget = DropdownButton<String>(
          value: pushLevel, // Default value
          icon: SizedBox.shrink(), // Remove the default arrow icon
          underline: SizedBox.shrink(),
          items: buildStrategyDropdownItems(),
          onChanged: (String? newValue) {
            setState(() {
                carStrategy[i][3] = newValue ?? '60'; // Update the strategy data

            });
          
          },
        );

      } else {
        // Invisible element for missing segments
        strategyItemWidget = SizedBox(width: 40, height: 40); // Match size of image
        wearLabelWidget = SizedBox.shrink(); // Invisible wear label
        dropdownWidget = SizedBox.shrink(); // Invisible dropdown
      }

      segmentWidgets.add( // Added to segmentWidgets
        Column( // Column for each segment - Removed Expanded
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            headerWidget, // Header at the top of the column
            strategyItemWidget,
            wearLabelWidget,
            SizedBox(
              height:20,
            child:dropdownWidget,)
          ],
        ),
      );
    }

    // Combine everything in a Column
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        pitStopRow,

        SizedBox(height: 8), // Spacing between button and scroll view
        Expanded( // Allow horizontal scrolling for segments
          
          child: Row( // Row of segment columns
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            crossAxisAlignment: CrossAxisAlignment.start, // Align items at the top
            children: segmentWidgets, // Use segmentWidgets
          ),
        ),
        SizedBox(height: 6), // Spacing between scroll view and buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          
          children: [
                            Align( // Align the button to the left
          alignment: Alignment.bottomLeft,
          child: SizedBox(
            width: 60,
            height: 25,
            child:Transform.scale(
               scale: 0.8, 
              child: Switch(
              
              value: _ignoreAdvanced,
              activeColor: const Color.fromARGB(255, 64, 150, 67), // Green when active
              inactiveThumbColor: const Color.fromARGB(255, 163, 44, 35), // Red when inactive
              //inactiveTrackColor: const Color.fromARGB(255, 163, 44, 35).withOpacity(0.5), // Lighter red track
              activeTrackColor: const Color.fromARGB(255, 64, 150, 67).withOpacity(0.5), // Lighter green track
              onChanged: (bool newValue) async {
                // The switch value is automatically updated by Flutter
                // We just need to trigger the action and potentially update state if needed elsewhere
                // The dialog logic remains the same
                await showDialog(
                  context: context,
                  builder: (BuildContext context ) {
                  bool isAdvancedEnabled = widget.account.raceData?['vars']?['d${widget.carIndex+1}IgnoreAdvanced'];
                  String selectedPushLevel = widget.account.raceData?['vars']?['d${widget.carIndex+1}PushLevel'] ?? '60';


                  return StatefulBuilder(
                    builder: (context, StateSetter setState) {
                      return AlertDialog(
                        insetPadding: EdgeInsets.zero,
                        content: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Row(
                              children: [
                                Text('Advanced: '),
                                Switch(
                                  value: isAdvancedEnabled,
                                  onChanged: (bool value) {
                                    setState(() {
                                      isAdvancedEnabled = value;
                                      widget.account.raceData?['vars']?['d${widget.carIndex+1}IgnoreAdvanced'] = value;
                                      // No need to update parent state here, will be done on dialog close
                                    });
                                  },
                                ),
                              ],
                            ),
                            if (widget.account.raceData?['vars']?['rulesJson']?['refuelling'] == '0')
                              Row(children: [
                                Text('Fuel:'),
                                SizedBox(width: 10),
                                Expanded(
                                  child: SpinBox(
                                    min: 0,
                                    max: 250, // Assuming fuel is a percentage or similar, adjust max as needed
                                    value: double.tryParse(widget.account.raceData?['vars']?['d${widget.carIndex+1}AdvancedFuel']?.toString() ?? '0') ?? 0,
                                    onChanged: (value) {
                                      // Update the value in widget.account.raceData
                                      if (widget.account.raceData?['vars'] != null) {
                                        widget.account.raceData?['vars']?['d${widget.carIndex+1}AdvancedFuel'] = value.toInt().toString();
                                      }
                                    },
                                  ),
                                ),
                              ],),
                            Row(children: [
                            Text('Default Push Level:'),SizedBox(width: 10,),                            
                              DropdownButton<String>(
                              value: selectedPushLevel,
                              icon: SizedBox.shrink(),
                              items: buildStrategyDropdownItems(),
                              onChanged: (String? newValue) {
                                setState(() {
                                  if (newValue != null) {
                                    selectedPushLevel = newValue;
                                    widget.account.raceData?['vars']?['d${widget.carIndex+1}PushLevel'] = newValue;
                                }
                                });
                                
                              },
                            ),
                            
                            ],),
                            

                          // Rain Start Settings
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Use:'),
                              DropdownButton<String>(
                                       icon: SizedBox.shrink(), // Remove the default arrow icon
                                      underline: SizedBox.shrink(),
                                value: widget.account.raceData?['vars']?['d${widget.carIndex+1}RainStartTyre'] ?? availableTyres.first,
                                items: availableTyres.map((String tyre) {
                                  return DropdownMenuItem<String>(
                                    
                                    value: tyre,
                                    child: Row(
                                      children: [
                                        Image.asset(
                                          'assets/tyres/_$tyre.png',
                                          width: 40, // Adjust size as needed
                                          height: 40, // Adjust size as needed
                                          errorBuilder: (c, e, s) => Container(
                                            width: 40, height: 40,
                                            color: Colors.grey[300],
                                            child: Icon(MdiIcons.tire, size: 12, color: Colors.grey[600]),
                                          ),
                                        ),

                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      widget.account.raceData?['vars']?['d${widget.carIndex+1}RainStartTyre'] = newValue;
                                    });
                                  }
                                },
                              ),
                              Text('if above'),
                              Row( // Wrap SpinBox and Text in a Row for suffix
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  SizedBox(
                                    height: 30,
                                    width: 90, // Adjust width to accommodate suffix
                                    child: SpinBox(
                                      
                                      min: 0,
                                      max: 5,
                                      iconSize: 20.0, // <<< Set your + and - icon size
                                     spacing: 0,
            
            decoration: InputDecoration(
              suffix: Text(
                        'mm',
                        style: TextStyle(fontSize: 8, color: Colors.grey),
                          ),
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0), // Adjust padding
              border: OutlineInputBorder(),
              
 
            ),
                                      value: double.tryParse(widget.account.raceData?['vars']?['d${widget.carIndex + 1}RainStartDepth']?.toString() ?? '') ?? 0.0,

                                      decimals: 0,
                                      step: 1,
                                      onChanged: (value) {
                                        setState(() {
                                          widget.account.raceData?['vars']?['d${widget.carIndex+1}RainStartDepth'] = value.toInt();
                                        });
                                      },
                                    ),
                                  ),
                        
                                ],
                              ),
                            ],
                          ),
                          // Rain Stop Settings
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Use:'),
                              DropdownButton<String>(
                                       icon: SizedBox.shrink(), // Remove the default arrow icon
                                underline: SizedBox.shrink(),
                                value: widget.account.raceData?['vars']?['d${widget.carIndex+1}RainStopTyre'] ?? availableTyres.first,
                                items: availableTyres.map((String tyre) {
                                  return DropdownMenuItem<String>(
                                    value: tyre,
                                    child: Row(
                                      children: [
                                        Image.asset(
                                          'assets/tyres/_$tyre.png',
                                          width: 40, // Adjust size as needed
                                          height: 40, // Adjust size as needed
                                          
                                          errorBuilder: (c, e, s) => Container(
                                            
                                            width: 40, height: 40,
                                            color: Colors.grey[300],
                                            child: Icon(Icons.tire_repair, size: 12, color: Colors.grey[600]),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (String? newValue) {
                                  if (newValue != null) {
                                    setState(() {
                                      widget.account.raceData?['vars']?['d${widget.carIndex+1}RainStopTyre'] = newValue;
                                    });
                                  }
                                },
                              ),
                              Text('if stops for'),
                              SizedBox(
                                width: 80,
                                 height: 30,
                                child: SpinBox(
                                  min: 0,
                                  max: int.tryParse(widget.account.raceData?['vars']?['raceLaps']?.toString() ?? '100')?.toDouble() ?? 100.0,
                                  value: double.tryParse(widget.account.raceData?['vars']?['d${widget.carIndex + 1}RainStopLap']?.toString() ?? '') ?? 0.0,
                                  decimals: 0,
                                  step: 1,
                                  iconSize: 20.0, // <<< Set your + and - icon size
            spacing: 0,
            decoration: InputDecoration(
              contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0), // Adjust padding
              border: OutlineInputBorder(),
            ),
                                  onChanged: (value) {
                                    setState(() {
                                      widget.account.raceData?['vars']?['d${widget.carIndex+1}RainStopLap'] = value.toInt();
                                    });
                                  },
                                ),
                              ),
                            ],
                          ),
                          ], // Closing the children list for the Column
                        ), // Closing the Column
                        actions: [
                          TextButton(
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                            child: Text('Close'),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
              // Update the parent widget's state after the dialog is closed
              setState(() {
                _ignoreAdvanced = widget.account.raceData?['vars']?['d${widget.carIndex+1}IgnoreAdvanced'] ?? false;
              });
            },
            
           ),),
            ),
          
        ),
        
          widget.carIndex > 0 ? SizedBox(width: 40) : SizedBox.shrink(), // Spacing between buttons
          Align( // Align the button to the right

          child: SizedBox(
            width: 60,
            child: widget.account.raceData?['vars']?['rulesJson']?['refuelling'] == '0' ? Text('$formattedTotalFuel L') : const SizedBox.shrink(),
          ),


          ),
          widget.carIndex == 0 ? SizedBox(width: 50) : SizedBox.shrink(),
          ],
        ),
        
      ],
    );
  }

  // --- Edit Strategy Dialog ---
  Future<void> _showEditStrategyDialog(int segmentIndex, String currentTyre, String currentLaps, double kmPerLiter, double trackLength, Map<String, double> pushLevelFactorMap) async {
    String selectedTyre = currentTyre;
    // TextEditingController lapsController = TextEditingController(text: currentLaps); // Removed
    double currentLapsDouble = double.tryParse(currentLaps) ?? 1.0; // Initial laps for SpinBox
    double selectedLaps = currentLapsDouble; // State variable for SpinBox value (used for laps or fuel)
    final formKey = GlobalKey<FormState>(); // Key for validation (might not be needed for SpinBox alone, but keep if other fields are added)
    double selectedFuel = double.tryParse(widget.account.raceData!['parsedStrategy'][widget.carIndex][segmentIndex].length > 2 ? widget.account.raceData!['parsedStrategy'][widget.carIndex][segmentIndex][2].toString() : '0') ?? 0.0; // State variable for fuel value


    // Get total race laps for SpinBox max value
    final totalRaceLaps = int.tryParse(widget.account.raceData?['vars']?['raceLaps']?.toString() ?? '100') ?? 100;


    return showDialog<void>(
      context: context,

      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pit $segmentIndex'),
          contentPadding: EdgeInsets.zero,
          insetPadding: EdgeInsets.zero,
          content: StatefulBuilder( // Use StatefulBuilder for local state management
            builder: (BuildContext context, StateSetter setDialogState) {
              return Form( // Wrap content in a Form
                key: formKey,
                child: SingleChildScrollView(
                  child: ListBody(
                    children: <Widget>[
                      // Tyre Selection Row
                      Text('Tyre:', style: Theme.of(context).textTheme.titleSmall),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: availableTyres.map((tyre) {
                          bool isSelected = tyre == selectedTyre;
                          return GestureDetector(
                            onTap: () {
                              setDialogState(() {
                                selectedTyre = tyre;
                              });
                            },
                            child: Container(
                              padding: EdgeInsets.all(isSelected ? 4 : 0), // Slightly smaller padding when selected to account for border
                              decoration: BoxDecoration(
                                border: isSelected
                                    ? Border.all(color: Theme.of(context).colorScheme.primary, width:2)
                                    : Border.all(color: const Color.fromARGB(0, 248, 8, 8), width: 1), // Keep size consistent
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Image.asset(
                                'assets/tyres/_$tyre.png',
                                width: 40, height: 40,
                                errorBuilder: (c, e, s) => Container(
                                  width: 30, height: 30,
                                  color: Colors.grey[300],
                                  child: Icon(Icons.tire_repair, size: 15, color: Colors.grey[600]),
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 20), // Increased spacing after tyre selection
                      // Laps Input (SpinBox)
                      if (widget.account.raceData?['vars']?['rulesJson']?['refuelling'] == '1') ...[
                        Text('Fuel:', style: Theme.of(context).textTheme.titleSmall),
                        SizedBox(height: 8),
                        SpinBox(
                          min: 0,
                          max: 250, // Assuming a max fuel of 250 liters
                          value: selectedFuel, // Use state variable for fuel
                          decimals: 0,
                          step: 1,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onChanged: (value) {
                            setDialogState(() { // Use setDialogState to update the dialog's state
                              selectedFuel = value;
                            });
                          },
                        ),
                        SizedBox(height: 8),
                        // Estimated laps row
                        Row(
                          children: [
                            Text('Estimated laps:', style: Theme.of(context).textTheme.titleSmall),
                            SizedBox(width: 8),
                            Builder( // Use Builder to access the latest selectedFuel value
                              builder: (context) {
                                final pushLevel = widget.account.raceData!['parsedStrategy'][widget.carIndex][segmentIndex].length > 3 ? widget.account.raceData!['parsedStrategy'][widget.carIndex][segmentIndex][3].toString() : '60'; // Default to '60'
                                final pushFactor = pushLevelFactorMap[pushLevel] ?? 0.0;
                                final fuelPerLap = (kmPerLiter + pushFactor) * trackLength;
                                final fuelEstimation = fuelPerLap > 0 ? ((selectedFuel / fuelPerLap)*1000).truncate()/1000 : 0; // Calculate and round down
                                return Text('$fuelEstimation');
                              },
                            ),
                          ],
                        ),
                      ] else ...[
                        Text('Laps:', style: Theme.of(context).textTheme.titleSmall),
                        SizedBox(height: 8),
                        SpinBox(
                          min: 1,
                          max: totalRaceLaps.toDouble(), // Use total race laps as max
                          value: selectedLaps, // Use state variable for laps
                          decimals: 0,
                          step: 1,
                          decoration: InputDecoration(
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                          ),
                          onChanged: (value) {
                            setDialogState(() { // Use setDialogState to update the dialog's state
                              selectedLaps = value;
                            });
                          },
                          // No validator needed as SpinBox handles range
                        ),
                      ],
                      // TODO: Add Fuel input if needed later
                    ],
                  ),
                ),
              );
            },
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              child: Text('Save'),
              onPressed: () {
                if (segmentIndex >= 0 && segmentIndex < widget.account.raceData!['parsedStrategy'][widget.carIndex].length) {
                  widget.account.raceData!['parsedStrategy'][widget.carIndex][segmentIndex][0] = selectedTyre;

                  if (widget.account.raceData?['vars']?['rulesJson']?['refuelling'] == '1') {
                    // Calculate fuel estimation for saving
                    final pushLevel = widget.account.raceData!['parsedStrategy'][widget.carIndex][segmentIndex].length > 3 ? widget.account.raceData!['parsedStrategy'][widget.carIndex][segmentIndex][3].toString() : '60'; // Default to '60'
                    final pushFactor = pushLevelFactorMap[pushLevel] ?? 0.0;
                    final fuelPerLap = (kmPerLiter + pushFactor) * trackLength;
                    final fuelEstimation = fuelPerLap > 0 ? (selectedFuel / fuelPerLap).floor() : 1; // Calculate and round down

                    widget.account.raceData!['parsedStrategy'][widget.carIndex][segmentIndex][1] = fuelEstimation.toString(); // Save estimated laps as String

                    widget.account.raceData!['parsedStrategy'][widget.carIndex][segmentIndex][2] = selectedFuel.toInt().toString(); // Save fuel as String
                  } else {
                    widget.account.raceData!['parsedStrategy'][widget.carIndex][segmentIndex][1] = selectedLaps.toInt().toString(); // Save laps as String
                  }
                }
                // Trigger a rebuild of the parent widget to reflect changes
                setState(() {});
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  // --- Helper to build invalid segment placeholder ---
  Widget _buildInvalidSegment(int segmentIndex, String message) {
    return GestureDetector(
      onTap: () {
        // Optionally show a message or dialog for invalid segments
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Invalid segment data: $message'),
            duration: Duration(seconds: 2),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2.0),
        child: Tooltip(
          message: 'Invalid data. Tap for info.',
          child: Container(
            width: 40, height: 40,
            color: Colors.red[200], // Indicate invalid data
            child: Center(
              child: Icon(Icons.error_outline, size: 20, color: Colors.red[800]),
            ),
          ),
        ),
      ),
    );
  }
}