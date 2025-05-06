import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'dart:math' as math;
import 'dart:async';

class ResearchDialogContent extends StatefulWidget {
  final Map<String, dynamic> researchData;

  const ResearchDialogContent({super.key, required this.researchData});

  @override
  // Make state class public
  ResearchDialogContentState createState() => ResearchDialogContentState();
}

// Make state class public
class ResearchDialogContentState extends State<ResearchDialogContent> {
  // State to hold the current myCar values (mutable)
  late List<int> myCarValues;
  // State to hold the checked status for each row
  late List<bool> checkedStatus;
  // State to hold the remaining design points
  late int remainingDesignPoints;
  // State to hold the recalculated maxResearch value
  late double recalculatedMaxResearch;
  // Store the original maxResearch value
  late double originalMaxResearch;

  // Timers for continuous press
  Timer? _addTimer;
  Timer? _removeTimer;

  late int researchLimit;

  @override
  void initState() {
    super.initState();

    myCarValues = List<int>.from(widget.researchData['myCar']);
    checkedStatus = List<bool>.from(widget.researchData['checks']);
    remainingDesignPoints = widget.researchData['points'] as int;
    originalMaxResearch = widget.researchData['maxResearch'] as double;

    researchLimit = widget.researchData['maxDp'] as int;
    int selectedCount = checkedStatus.where((status) => status).length;
    if (selectedCount > 0) {
      recalculatedMaxResearch = originalMaxResearch / selectedCount;
    } else {
      recalculatedMaxResearch = originalMaxResearch;
    }
  }

  // Function to calculate the total points by summing row calculations
  int calculateTotalPoints() {
    double totalPoints = 0.0;
    final bestCarAttributes = widget.researchData['best'] as List<dynamic>;
    final myCarAttributes = myCarValues;

    for (int i = 0; i < checkedStatus.length; i++) {
      if (checkedStatus[i]) {
        final bestValue = bestCarAttributes[i] as int;
        final myValue = myCarAttributes[i];
        final gap = bestValue - myValue;
        totalPoints += (math.max(0, gap) * recalculatedMaxResearch / 100).ceil();
      }
    }
    return totalPoints.toInt();


  }
    Map<String, dynamic> getResearchMap() {
    final Map<String, dynamic> research = {
      'maxDp': originalMaxResearch.toInt(),
      'attributes': <String>[],
    };

      List<String> attributeNames = [
    'acceleration',
    'braking',
    'cooling',
    'downforce',
    'fuel_economy',
    'handling',
    'reliability',
    'tyre_economy'
  ];

    for (int i = 0; i < checkedStatus.length; i++) {
      if (checkedStatus[i]) {
        (research['attributes'] as List<String>).add(attributeNames[i]);
      }
    }
    return research;
  }

  // Method to get the design list (myCarValues) for saving
  List<String> getDesignList() {
    List<String> attributeNames = [
    'acceleration',
    'braking',
    'cooling',
    'downforce',
    'fuel_economy',
    'handling',
    'reliability',
    'tyre_economy'
  ];
  List<String> pointsSpent = [];
    for (int i = 0; i < attributeNames.length; i++) {
    pointsSpent.add('&${attributeNames[i]}=${myCarValues[i]}');
    }
    return pointsSpent;
  }

  // --- Timer and continuous press logic ---
  void _incrementValue(int index) {
    if (remainingDesignPoints > 0 && myCarValues[index] < researchLimit) {
      setState(() {
        myCarValues[index]++;
        remainingDesignPoints--;
      });
    } else {
      _stopAddTimer(); // Stop if cannot increment
    }
  }

  void _decrementValue(int index) {
    final initialTotalPoints = widget.researchData['points'] as int;
    if (myCarValues[index] > 0 && remainingDesignPoints < initialTotalPoints) {
      setState(() {
        myCarValues[index]--;
        remainingDesignPoints++;
      });
    } else {
      _stopRemoveTimer(); // Stop if cannot decrement
    }
  }

  void _startAddTimer(int index) {
    _addTimer?.cancel();
    _incrementValue(index); // Execute once on long press start
    _addTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      _incrementValue(index);
    });
  }

  void _stopAddTimer() {
    _addTimer?.cancel();
    _addTimer = null;
  }

  void _startRemoveTimer(int index) {
    _removeTimer?.cancel();
    _decrementValue(index); // Execute once on long press start
    _removeTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      _decrementValue(index);
    });
  }

  void _stopRemoveTimer() {
    _removeTimer?.cancel();
    _removeTimer = null;
  }

  @override
  void dispose() {
    _addTimer?.cancel();
    _removeTimer?.cancel();
    super.dispose();
  }
  // --- End Timer logic ---


  @override
  Widget build(BuildContext context) {

    final bonusCarAttributes = widget.researchData['bonus'] as List<dynamic>;
    final bestCarAttributes = widget.researchData['best'] as List<dynamic>;
    
    final List<IconData> attributeIcons = [
      MdiIcons.gauge,
      MdiIcons.carBrakeLowPressure,
      MdiIcons.thermometer,
      MdiIcons.arrowDown,
      MdiIcons.gasStation,
      MdiIcons.steering,
      MdiIcons.wrench,
      MdiIcons.tire,
      ];

    // --- Calculate Max Theoretical Gain ---
    int maxGainIndex = -1;
    double maxGain = -1.0;

    for (int i = 0; i < myCarValues.length; i++) {
      // Skip 3rd (index 2) and 7th (index 6) attributes
      if (i == 2 || i == 6) continue;

      final bestValue = bestCarAttributes[i] as int;
      final myValue = myCarValues[i]; // Use current mutable value
      final gap = bestValue - myValue;
      // Use recalculatedMaxResearch for dynamic highlighting based on current selections
      final potentialGain = (math.max(0, gap) * recalculatedMaxResearch / 100).ceilToDouble();

      if (potentialGain > maxGain) {
        maxGain = potentialGain;
        maxGainIndex = i;
      }
    }
    // --- End Calculate Max Theoretical Gain --

    return SizedBox(
      width: double.maxFinite, // Allow the dialog to take more width
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with remaining points and maxResearch labels
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text('Points: $remainingDesignPoints'),
                Text('Research Power: ${recalculatedMaxResearch.toStringAsFixed(2)}'),
              ],
            ),
          ),
          Divider(),
          // Header Row
          Padding(
            
            padding: const EdgeInsets.symmetric(horizontal:0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                SizedBox(width: 24), // Space for icon
                SizedBox(width: 30, child: Center(child: Icon(Icons.check, size: 20))),
                SizedBox(width: 30, child: Center(child: Icon(Icons.person, size: 20))),
                SizedBox(width: 30),
                SizedBox(width: 30, child: Center(child: Icon(Icons.people, size: 20))),
                SizedBox(width: 30, child: Center(child: Icon(Icons.compare_arrows, size: 20))),

                SizedBox(width: 80),
              ],
            ),
          ),
          Divider(),
          // Data Rows
          SizedBox( // Use Expanded to allow the ListView to take available space
            child: ListView.builder(
              
              shrinkWrap: true, // Use shrinkWrap with Expanded
              itemCount: myCarValues.length,
              itemBuilder: (context, index) {
                final myValue = myCarValues[index];
                final bonusValue = bonusCarAttributes[index] as String;
                final bestValue = bestCarAttributes[index] as int;
                final gap = bestValue - myValue;
                final isMaxGainRow = index == maxGainIndex;

                return Container( // Wrap with Container for potential highlighting
                  color: isMaxGainRow ? const Color.fromARGB(255, 79, 128, 121).withOpacity(0.3) : null, // Highlight if it's the max gain row
                  child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 0, vertical: 4.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      // Attribute Icon
                      SizedBox(width: 24, child: Icon(attributeIcons[index], size: 18)),
                      // Checkbox
                      SizedBox(
                        width: 30,
                        child: Center(
                          child: Checkbox(
                            value: checkedStatus[index],
                            onChanged: (bool? newValue) {
                              setState(() {
                                checkedStatus[index] = newValue ?? false;
                                // Recalculate maxResearch based on selected checkboxes
                                int selectedCount = checkedStatus.where((status) => status).length;
                                if (selectedCount > 0) {
                                  recalculatedMaxResearch = originalMaxResearch / selectedCount;
                                } else {
                                  recalculatedMaxResearch = originalMaxResearch; // Or 0.0 depending on desired behavior when none are selected
                                }
                              });
                            },
                          ),
                        ),
                      ),
                      // MyCar Value
                      SizedBox(width: 30, child: Center(child: Text(myValue.toString()))),
                      // Bonus Value
                      SizedBox(width: 30, child: Center(child: Text(bonusValue.toString(), style: TextStyle(fontSize: 10, color: (double.tryParse(bonusValue.toString().replaceAll('(', '').replaceAll(')', '')) ?? 0) >= 0 ? Colors.green : Colors.red)))),
                      // Best Value
                      SizedBox(width: 30, child: Center(child: Text(bestValue.toString()))),
                      // Gap
                      SizedBox(width: 30, child: Center(child: Text(gap.toString()))),

                      
                      // Adjust Buttons
                      SizedBox(
                        width: 80,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            GestureDetector(
                              onLongPressStart: (_) {
                                _startRemoveTimer(index);
                              },
                              onLongPressEnd: (_) {
                                _stopRemoveTimer();
                              },
                              onLongPressCancel: () { // Handle interruption
                                _stopRemoveTimer();
                              },
                              child: IconButton(
                                icon: Icon(Icons.remove, size: 25),
                                onPressed: () {
                                  _decrementValue(index);
                                },
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                            ),

                            GestureDetector(
                              onLongPressStart: (_) {
                                _startAddTimer(index);
                              },
                              onLongPressEnd: (_) {
                                _stopAddTimer();
                              },
                              onLongPressCancel: () { // Handle interruption
                                _stopAddTimer();
                              },
                              child: IconButton(
                                icon: Icon(Icons.add, size: 26),
                                onPressed: () {
                                  _incrementValue(index);
                                },
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                            ),
                          ],
                        ),
                      ),
                     ],
                   ),
                  ),
                );
              },
            ),
          ),
          Divider(),
          // Total Points Row
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                Text('Overall Total Points: ${calculateTotalPoints()}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
