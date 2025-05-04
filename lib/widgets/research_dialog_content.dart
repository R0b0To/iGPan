import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart'; // Assuming MdiIcons is used for placeholders
import 'dart:math' as math;

class ResearchDialogContent extends StatefulWidget {
  final Map<String, dynamic> researchData;

  const ResearchDialogContent({Key? key, required this.researchData}) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    // Initialize myCarValues from researchData['myCar']
    myCarValues = List<int>.from(widget.researchData['myCar']);
    // Initialize checkedStatus from researchData['checks']
    checkedStatus = List<bool>.from(widget.researchData['checks']);
    // Initialize remainingDesignPoints from researchData['points']
    remainingDesignPoints = widget.researchData['points'] as int;
    // Initialize originalMaxResearch from researchData['maxResearch']
    originalMaxResearch = widget.researchData['maxResearch'] as double;
    // Initialize recalculatedMaxResearch
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
    final myCarAttributes = myCarValues; // Use the mutable state value

    for (int i = 0; i < checkedStatus.length; i++) {
      if (checkedStatus[i]) {
        final bestValue = bestCarAttributes[i] as int;
        final myValue = myCarAttributes[i]; // Use the mutable state value
        final gap = bestValue - myValue;
        totalPoints += (math.max(0, gap) * recalculatedMaxResearch / 100).ceil();
      }
    }
    return totalPoints.toInt();


  }
    Map<String, dynamic> getResearchMap() {
    final Map<String, dynamic> research = {
      'maxDp': originalMaxResearch.toInt(), // Use the original value
      'attributes': <String>[], // Initialize empty list for attribute names
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
                Text('Remaining Points: $remainingDesignPoints'),
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
          Expanded( // Use Expanded to allow the ListView to take available space
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
                            IconButton(
                              icon: Icon(Icons.remove, size: 18),
                              onPressed: () {
                                setState(() {
                                  if (myCarValues[index] > 0 && remainingDesignPoints < (widget.researchData['points'] as int)) { // Prevent negative values and don't exceed initial points
                                    myCarValues[index]--;
                                    remainingDesignPoints++;
                                  }
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
                            ),

                            IconButton(
                              icon: Icon(Icons.add, size: 18),
                              onPressed: () {
                                setState(() {
                                  if (remainingDesignPoints > 0) { // Only increment if points are available
                                    myCarValues[index]++;
                                    remainingDesignPoints--;
                                  }
                                });
                              },
                              padding: EdgeInsets.zero,
                              constraints: BoxConstraints(),
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
              mainAxisAlignment: MainAxisAlignment.end,
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
