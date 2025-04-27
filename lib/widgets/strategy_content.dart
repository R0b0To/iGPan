import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for input formatters
import '../igp_client.dart'; // Import Account and other necessary definitions

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

  @override
  Widget build(BuildContext context) {
    super.build(context); // Important for AutomaticKeepAliveClientMixin

    int totalLaps = 0; // Initialize total laps at the beginning of the build method

    // Calculate pitKey and number of segments
    String pitKey = 'd${widget.carIndex + 1}Pits'; // Use widget.carIndex
    int numberOfPits = 0;
    // Safely parse the number of pits
    if (widget.account.raceData != null ) {
      var pitValue = widget.account.raceData!['vars']?[pitKey];
      numberOfPits = pitValue is int ? pitValue : (pitValue is String ? int.tryParse(pitValue) ?? 0 : 0);
    }
    final numberOfSegments = numberOfPits + 1; // Segments = Pits + 1

    // Build the strategy display
    Widget strategyDisplay;
    // Check if parsedStrategy exists and has data for the current carIndex
    if (numberOfSegments > 0 &&
        widget.account.raceData != null && // Use widget.account
        widget.account.raceData!['parsedStrategy'] != null &&
        widget.account.raceData!['parsedStrategy'] is List &&
        widget.carIndex < widget.account.raceData!['parsedStrategy'].length && // Use widget.carIndex and widget.account
        widget.account.raceData!['parsedStrategy'][widget.carIndex] is List) { // Use widget.account and widget.carIndex

      List<Widget> strategyItems = [];
      List<dynamic> carStrategy = widget.account.raceData!['parsedStrategy'][widget.carIndex]; // Use widget.account and widget.carIndex
      // Iterate up to numberOfSegments, ensuring we don't go out of bounds of carStrategy
      for (int i = 0; i < numberOfSegments && i < carStrategy.length; i++) {
        // Add checks for the format of each segment data
        if (carStrategy[i] is List && carStrategy[i].length >= 2 &&
            carStrategy[i][0] is String && carStrategy[i][1] is String) {

          String tyreAsset = carStrategy[i][0];
          // Use the second element (laps) as the label text
          String labelText = carStrategy[i][1];
          totalLaps += int.tryParse(labelText) ?? 0; // Safely parse laps
          // Optional: Use third element (fuel) if needed later
          // String fuelValue = (carStrategy[i].length >= 3 && carStrategy[i][2] is String) ? carStrategy[i][2] : '';

          // Basic validation for tyre asset name (alphanumeric, underscore, hyphen)
          final validTyreAsset = RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(tyreAsset);

          if (validTyreAsset && tyreAsset.isNotEmpty) {
             strategyItems.add(
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2.0), // Reduced padding
                child: Tooltip( // Add tooltip for tyre name
                  message: tyreAsset, // Show the asset name on hover
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      Image.asset(
                        'assets/tyres/$tyreAsset.png',
                        width: 40, // Adjusted size
                        height: 40, // Adjusted size
                        errorBuilder: (context, error, stackTrace) {
                          // Display placeholder if image fails to load
                          return Container(
                            width: 40, height: 40,
                            color: Colors.grey[300],
                            child: Icon(Icons.tire_repair, size: 20, color: Colors.grey[600]),
                          );
                        },
                      ),
                      Text(
                        labelText, // Display laps
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 12, // Adjusted size
                          shadows: [ // Add shadow for better readability
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
             // Handle invalid tyre asset name
             strategyItems.add(_buildInvalidSegment(i, 'Invalid tyre'));
          }
        } else {
          // Handle unexpected data format for a segment
          strategyItems.add(_buildInvalidSegment(i, 'Invalid data'));
        }
      }

      // Add placeholders if numberOfSegments is greater than the available parsed data
      if (numberOfSegments > carStrategy.length) {
        for (int i = carStrategy.length; i < numberOfSegments; i++) {
           strategyItems.add(_buildInvalidSegment(i, 'Missing data'));
        }
      }


      strategyDisplay = Container(
        padding: const EdgeInsets.symmetric(vertical: 8.0), // Add padding
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: strategyItems,
          ),
        ),
      );
    } else {
      // Handle cases where there's no strategy data or it's invalid
      strategyDisplay = Center(child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Text('No strategy data available.', style: Theme.of(context).textTheme.bodySmall),
      ));
    }

    // Get raceLaps safely
    final raceLaps = widget.account.raceData?['vars']?['raceLaps']?.toString() ?? '0';

    return Row(
      mainAxisAlignment: MainAxisAlignment.center, // Center the row content
      crossAxisAlignment: CrossAxisAlignment.center, // Align items vertically in the center
      children: [
        strategyDisplay, // Removed Expanded widget
        const SizedBox(width: 8), // Add some spacing between strategy and laps
        Container( // Wrap the column in a Container for the border
          decoration: BoxDecoration(
            border: Border.all(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), // Border color
              width: 0.8, // Border width
            ),
            borderRadius: BorderRadius.zero, // Square corners
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Add padding inside the border
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Center the laps vertically
            crossAxisAlignment: CrossAxisAlignment.center, // Center the text horizontally within the column
            mainAxisSize: MainAxisSize.min, // Make the column take minimum space
            children: [
              Container( // Wrap raceLaps in a Container for the bottom border
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5), // Border color
                      width: 1, // Border width
                    ),
                  ),
                ),
                child: Text(
                  raceLaps, // Display raceLaps
                  style: Theme.of(context).textTheme.bodyMedium, // Adjust style as needed
                  textAlign: TextAlign.center, // Center the text horizontally
                ),
              ),
              Text(
                totalLaps.toString(), // Display totalLaps
                style: Theme.of(context).textTheme.bodySmall, // Adjust style as needed
              ),
            ],
          ),
        ),
      ],
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