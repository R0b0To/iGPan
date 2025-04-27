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

    // Row 1: Spinbox/Text for pit stops
    Widget pitStopRow = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Placeholder for Spinbox - using Text for now
        Text('$numberOfPits pit stop(s)'),
      ],
    );

    // Headers (Start, Pit 1, ...) - Let's assume up to 5 segments for headers as requested
    List<String> headers = ['Start', 'Pit 1', 'Pit 2', 'Pit 3', 'Pit 4'];

    // Strategy items, wear labels, and dropdowns arranged in columns per segment
    List<Widget> segmentWidgets = []; // Renamed to segmentWidgets
    List<dynamic> carStrategy = (numberOfSegments > 0 &&
        widget.account.raceData != null &&
        widget.account.raceData!['parsedStrategy'] != null &&
        widget.account.raceData!['parsedStrategy'] is List &&
        widget.carIndex < widget.account.raceData!['parsedStrategy'].length &&
        widget.account.raceData!['parsedStrategy'][widget.carIndex] is List)
        ? widget.account.raceData!['parsedStrategy'][widget.carIndex]
        : [];

    // Ensure we have enough segments to match headers, adding placeholders if needed
    int displaySegments = headers.length; // Display up to the number of headers
    for (int i = 0; i < displaySegments; i++) {
      Widget headerWidget;
      Widget strategyItemWidget;
      Widget wearLabelWidget;
      Widget dropdownWidget;

      // Header for this segment
      headerWidget = Center(child: Text(headers[i]));

      // Check if data exists for this segment
      if (i < numberOfSegments && i < carStrategy.length &&
          carStrategy[i] is List && carStrategy[i].length >= 2 &&
          carStrategy[i][0] is String && carStrategy[i][1] is String) {

        String tyreAsset = carStrategy[i][0];
        String labelText = carStrategy[i][1];
        totalLaps += int.tryParse(labelText) ?? 0; // Safely parse laps

        final validTyreAsset = RegExp(r'^[a-zA-Z0-9_-]+$').hasMatch(tyreAsset);

        if (validTyreAsset && tyreAsset.isNotEmpty) {
          strategyItemWidget = Padding(
            padding: const EdgeInsets.symmetric(horizontal: 2.0),
            child: Tooltip(
              message: '',
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
          );
        } else {
          strategyItemWidget = _buildInvalidSegment(i, 'Invalid tyre');
        }

        // Wear label (Placeholder)
        wearLabelWidget = Text('Wear ${i+1}'); // Placeholder text

        // Dropdown (Placeholder)
        dropdownWidget = DropdownButton<String>(
          value: 'neutral', // Default value
          items: <String>['very low', 'low', 'neutral', 'high', 'very high'].map((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
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
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            headerWidget, // Header at the top of the column
            SizedBox(height: 4), // Spacing
            strategyItemWidget,
            SizedBox(height: 4), // Spacing
            wearLabelWidget,
            SizedBox(height: 4), // Spacing
            dropdownWidget,
          ],
        ),
      );
    }


    // Get raceLaps safely
    final raceLaps = widget.account.raceData?['vars']?['raceLaps']?.toString() ?? '0';

    // Combine everything in a Column
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        pitStopRow,
        SizedBox(height: 8), // Spacing
        SingleChildScrollView( // Allow horizontal scrolling for segments
          scrollDirection: Axis.horizontal,
          child: Row( // Row of segment columns
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.start, // Align items at the top
            children: segmentWidgets, // Use segmentWidgets
          ),
        ),
        SizedBox(height: 8), // Spacing
        // The existing laps display needs to be integrated.
        // It was previously next to the strategyDisplay.
        // Now it should probably be below the main segment display.
        // Let's put it in a separate row below the segment display.
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
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