import 'package:flutter/material.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart'; // Assuming MdiIcons is used for placeholders

class ResearchDialogContent extends StatefulWidget {
  final Map<String, dynamic> researchData;

  const ResearchDialogContent({Key? key, required this.researchData}) : super(key: key);

  @override
  _ResearchDialogContentState createState() => _ResearchDialogContentState();
}

class _ResearchDialogContentState extends State<ResearchDialogContent> {
  // State to hold the current myCar values (mutable)
  late List<int> myCarValues;
  // State to hold the checked status for each row
  late List<bool> checkedStatus;
  // State to hold the remaining design points
  late int remainingDesignPoints;

  @override
  void initState() {
    super.initState();
    // Initialize myCarValues from researchData['myCar']
    myCarValues = List<int>.from(widget.researchData['myCar']);
    // Initialize checkedStatus to all false
    checkedStatus = List<bool>.filled(myCarValues.length, false);
    // Initialize remainingDesignPoints from researchData['points']
    remainingDesignPoints = widget.researchData['points'] as int;
  }

  // Function to calculate the total points
  double calculateTotalPoints() {
    final maxResearch = widget.researchData['maxResearch'] as double;
    final bestCarAttributes = widget.researchData['best'] as List<dynamic>;

    double totalPoints = 0.0;
    int selectedCheckboxes = 0;

    for (int i = 0; i < checkedStatus.length; i++) {
      if (checkedStatus[i]) {
        selectedCheckboxes++;
        // Calculate the gap for the selected row
        final bestValue = bestCarAttributes[i] as int;
        final myValue = myCarValues[i];
        final gap = bestValue - myValue;

        // Add gap to total points for selected rows
        totalPoints += gap.toDouble();
      }
    }

    // Apply the maxResearch factor based on the number of selected checkboxes
    if (selectedCheckboxes > 0) {
       totalPoints = totalPoints * (maxResearch / selectedCheckboxes);
    } else {
      totalPoints = 0.0; // If no checkboxes are selected, total points is 0
    }

    return totalPoints;
  }


  @override
  Widget build(BuildContext context) {
    final myCarAttributes = widget.researchData['myCar'] as List<dynamic>;
    final bonusCarAttributes = widget.researchData['bonus'] as List<dynamic>;
    final bestCarAttributes = widget.researchData['best'] as List<dynamic>;
    final checkedDesign = widget.researchData['checks'] as List<dynamic>;
    final maxResearch = widget.researchData['maxResearch'] as double;

    // Placeholder icons - replace with actual attribute icons later
    final List<IconData> attributeIcons = List.generate(myCarAttributes.length, (index) => MdiIcons.car);

    return Container(
      width: double.maxFinite, // Allow the dialog to take more width
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row with remaining points and maxResearch labels
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Remaining Points: $remainingDesignPoints'),
                Text('Max Research: ${maxResearch.toStringAsFixed(2)}'),
              ],
            ),
          ),
          Divider(),
          // Header Row
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              children: [
                SizedBox(width: 24), // Space for icon
                SizedBox(width: 40, child: Center(child: Text('Check'))),
                SizedBox(width: 40, child: Center(child: Text('MyCar'))),
                SizedBox(width: 40, child: Center(child: Text('Bonus'))),
                SizedBox(width: 40, child: Center(child: Text('Best'))),
                SizedBox(width: 40, child: Center(child: Text('Gap'))),
                SizedBox(width: 80, child: Center(child: Text('Adjust'))),
                SizedBox(width: 60, child: Center(child: Text('Total'))),
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
                final checkValue = checkedDesign[index] as bool; // Assuming checkedDesign is a list of booleans
                final gap = bestValue - myValue;

                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                  child: Row(
                    children: [
                      // Attribute Icon
                      SizedBox(width: 24, child: Icon(attributeIcons[index], size: 18)),
                      // Checkbox
                      SizedBox(
                        width: 40,
                        child: Center(
                          child: Checkbox(
                            value: checkedStatus[index],
                            onChanged: (bool? newValue) {
                              setState(() {
                                checkedStatus[index] = newValue ?? false;
                              });
                            },
                          ),
                        ),
                      ),
                      // MyCar Value
                      SizedBox(width: 40, child: Center(child: Text(myValue.toString()))),
                      // Bonus Value
                      SizedBox(width: 40, child: Center(child: Text(bonusValue.toString()))),
                      // Best Value
                      SizedBox(width: 40, child: Center(child: Text(bestValue.toString()))),
                      // Gap
                      SizedBox(width: 40, child: Center(child: Text(gap.toString()))),
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
                      // Total (Placeholder - calculation needs refinement)
                       SizedBox(width: 60, child: Center(child: Text('Calc'))), // Placeholder for calculated total per row if needed
                    ],
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
                Text('Overall Total Points: ${calculateTotalPoints().toStringAsFixed(2)}'),
              ],
            ),
          ),
        ],
      ),
    );
  }
}