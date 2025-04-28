import 'package:flutter_spinbox/flutter_spinbox.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for input formatters
import '../igp_client.dart'; // Import Account and other necessary definitions
import '../utils/math_utils.dart'; // Import math_utils for wearCalc and Track
import 'dart:developer' as developer; // For logging

// --- StrategyContent Widget ---

class StrategyContent extends StatefulWidget { // Changed to StatefulWidget
  final Account account; // Use specific Account type
  final int carIndex;

  const StrategyContent({Key? key, required this.account, required this.carIndex}) : super(key: key);

  @override
  _StrategyContentState createState() => _StrategyContentState();
}

class _StrategyContentState extends State<StrategyContent> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  int _numberOfPits = 1; // State variable for number of pits
  List<String> availableTyres = ['SS', 'S', 'M', 'H', 'I', 'W']; // Available tyre types

  @override
  void initState() {
    super.initState();
    // Initialize _numberOfPits from account data
    String pitKey = 'd${widget.carIndex + 1}Pits';
    if (widget.account.raceData != null ) {
      var pitValue = widget.account.raceData!['vars']?[pitKey];
      _numberOfPits = pitValue is int ? pitValue : (pitValue is String ? int.tryParse(pitValue) ?? 0 : 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    super.build(context); // Important for AutomaticKeepAliveClientMixin

    // Get raceLaps safely
    final raceLaps = int.tryParse(widget.account.raceData?['vars']?['raceLaps']?.toString() ?? '0') ?? 0;
    final trackId = widget.account.raceData?['vars']?['trackId']?.toString() ?? '1'; // Assuming '1' as a default if trackId is null
    final track = Track(trackId, raceLaps); // Create Track instance
    final calculatedWear = wearCalc(widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['carAttributes']?['tyre_economy']?.toDouble() ?? 0.0, track);

    // Calculate number of segments based on state variable
    final numberOfSegments = _numberOfPits + 1; // Segments = Pits + 1

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

    // Row 1: Spinbox/Text for pit stops and Laps Display
    Widget pitStopRow = Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Align items to the ends
      children: [
        // Button to the left of the Spinbox
        Padding(
          padding: const EdgeInsets.only(right: 8.0), // Add some spacing to the right
          child: SizedBox(
            height: 30, // Match the height of the SpinBox
            child: ElevatedButton(
              onPressed: () {
                // TODO: Implement button action (e.g., add a pit stop)
              },
              child: Text('S/L'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 8.0), // Adjust padding
                textStyle: TextStyle(fontSize: 12), // Adjust text size
              ),
            ),
          ),
        ),
        // Spinbox for pits
        SizedBox(
          width: 100.0, // Provide a fixed width
          height: 30,
          
          child: SpinBox(
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

    // Headers (Start, Pit 1, ...) - Let's assume up to 5 segments for headers as requested
    List<String> headers = ['Start', 'Pit 1', 'Pit 2', 'Pit 3', 'Pit 4'];

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
        // totalLaps calculation moved above

        final validTyreAsset = RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(tyreAsset);

        if (validTyreAsset && tyreAsset.isNotEmpty) {
          // Wrap the Padding with GestureDetector
          strategyItemWidget = GestureDetector(
            onTap: () {
              _showEditStrategyDialog(i, tyreAsset, labelText);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 2.0),
              child: Tooltip(
                message: 'Tap to edit', // Updated tooltip
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
        
        final tyreWear = double.tryParse(calculatedWear['${tyreAsset}'] ?? '0.0') ?? 0.0;
        final segmentLaps = int.tryParse(labelText) ?? 0;
        final stintWear = stintWearCalc(tyreWear, segmentLaps, track);
        wearLabelWidget = Text(stintWear);

        // Dropdown (Placeholder)
        dropdownWidget = DropdownButton<String>(
          value: 'neutral', // Default value
          icon: SizedBox.shrink(), // Remove the default arrow icon
          underline: SizedBox.shrink(),
          items: <String>['very high', 'high', 'neutral', 'low', 'very low'].map((String value) {
            IconData iconData;
            Color iconColor;
           

            switch (value) {
              case 'very low':
                iconData = Icons.keyboard_double_arrow_down; // Double down arrow
                iconColor = Colors.green; // Green for low wear
                break;
              case 'low':
                iconData = Icons.keyboard_arrow_down; // Single down arrow
                iconColor = Colors.lightGreen; // Light green for slightly more wear
                break;
              case 'neutral':
                iconData = Icons.horizontal_rule; // White line icon
                iconColor = Colors.white; // White color
                break;
              case 'high':
                iconData = Icons.keyboard_arrow_up; // Single up arrow
                iconColor = Colors.orange; // Orange for higher wear
                break;
              case 'very high':
                iconData = Icons.keyboard_double_arrow_up; // Double up arrow
                iconColor = Colors.red; // Red for very high wear
                break;
              default:
                iconData = Icons.help_outline;
                iconColor = Colors.grey;
            }

            return DropdownMenuItem<String>(
              value: value,
              child: Center( // Center the icon
                child: Icon(iconData, color: iconColor, size: 20), // Adjusted size, removed Opacity
              ),
            );
          }).toList(),
          onChanged: (String? newValue) {
            // TODO: Implement dropdown logic
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
        SingleChildScrollView( // Allow horizontal scrolling for segments
          scrollDirection: Axis.horizontal,
          child: Row( // Row of segment columns
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start, // Align items at the top
            children: segmentWidgets, // Use segmentWidgets
          ),
        ),
                Align( // Align the button to the left
          alignment: Alignment.centerLeft,
          child: ElevatedButton( // TODO: Replace with actual button logic and text
            onPressed: () {
              // TODO: Implement button action
              print('Button Pressed!'); // Placeholder action
            },
            child: Text('Adv'), // Placeholder text
          ),
        ),
      ],
    );
  }

  // --- Edit Strategy Dialog ---
  Future<void> _showEditStrategyDialog(int segmentIndex, String currentTyre, String currentLaps) async {
    String selectedTyre = currentTyre;
    // TextEditingController lapsController = TextEditingController(text: currentLaps); // Removed
    double currentLapsDouble = double.tryParse(currentLaps) ?? 1.0; // Initial laps for SpinBox
    double selectedLaps = currentLapsDouble; // State variable for SpinBox value
    final formKey = GlobalKey<FormState>(); // Key for validation (might not be needed for SpinBox alone, but keep if other fields are added)

    // Get total race laps for SpinBox max value
    final totalRaceLaps = int.tryParse(widget.account.raceData?['vars']?['raceLaps']?.toString() ?? '100') ?? 100;


    return showDialog<void>(
      context: context,

      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Pit ${segmentIndex}'),
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
                                'assets/tyres/_${tyre}.png',
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
                      Text('Laps:', style: Theme.of(context).textTheme.titleSmall),
                      SizedBox(height: 8),
                      SpinBox(
                        min: 1,
                        max: totalRaceLaps.toDouble(), // Use total race laps as max
                        value: selectedLaps, // Use state variable
                        decimals: 0,
                        step: 1,
                        decoration: InputDecoration(
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                        ),
                        onChanged: (value) {
                          // No need for setDialogState here if SpinBox updates itself visually
                          // Just update the variable holding the value
                          selectedLaps = value;
                        },
                        // No validator needed as SpinBox handles range
                      ),
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
                // if (formKey.currentState!.validate()) { // Validation might not be needed if only SpinBox is used
                  // final newLaps = lapsController.text; // Removed
                  final newLapsString = selectedLaps.toInt().toString(); // Get laps from SpinBox state
                  // Update the strategy data
                  try {
                     if (widget.account.raceData != null &&
                        widget.account.raceData!['parsedStrategy'] != null &&
                        widget.account.raceData!['parsedStrategy'] is List &&
                        widget.carIndex < widget.account.raceData!['parsedStrategy'].length &&
                        widget.account.raceData!['parsedStrategy'][widget.carIndex] is List &&
                        segmentIndex < widget.account.raceData!['parsedStrategy'][widget.carIndex].length)
                      {
                        // Ensure the segment exists before updating
                        setState(() {
                          widget.account.raceData!['parsedStrategy'][widget.carIndex][segmentIndex] = [selectedTyre, newLapsString];
                          // Log the update
                          developer.log('Updated strategy for car ${widget.carIndex}, segment $segmentIndex: [$selectedTyre, $newLapsString]');
                          developer.log('Current parsedStrategy: ${widget.account.raceData!['parsedStrategy']}');
                        });
                        Navigator.of(context).pop(); // Close the dialog
                      } else {
                         developer.log('Error: Could not update strategy - Invalid data structure or index out of bounds.');
                         // Optionally show an error message to the user
                         ScaffoldMessenger.of(context).showSnackBar(
                           SnackBar(content: Text('Error updating strategy data.')),
                         );
                      }
                  } catch (e, stacktrace) {
                     developer.log('Error updating strategy: $e\n$stacktrace');
                     ScaffoldMessenger.of(context).showSnackBar(
                       SnackBar(content: Text('An error occurred while saving.')),
                     );
                  }
               // } // End validation check
             },
           ),
          ],
        );
      },
    );
  }


  // Helper for invalid/missing segments
  Widget _buildInvalidSegment(int index, String reason) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4.0),
      child: Tooltip(
        message: 'Segment ${index + 1}: $reason',
        child: Container(
          width: 40, height: 40,
          color: Colors.red[100],
          child: Icon(Icons.warning_amber_rounded, size: 20, color: Colors.red[700]),
        ),
      ),
    );
  }
}