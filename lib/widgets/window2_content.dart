import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import '../igp_client.dart'; // Import Account and other necessary definitions

class Window2Content extends StatefulWidget {
  final double minWindowHeight;
  final Account account; // Use the specific Account type

  const Window2Content({Key? key, required this.minWindowHeight, required this.account}) : super(key: key);

  @override
  _Window2ContentState createState() => _Window2ContentState();
}

class _Window2ContentState extends State<Window2Content> with TickerProviderStateMixin {
  late TabController _tabController;
  final CarouselSliderController _carouselController = CarouselSliderController();
  int _currentCarouselIndex = 0; // Renamed for clarity

  // Define the tabs as a class member
  final List<Tab> tabs = const [
    Tab(text: 'Setup'),
    Tab(text: 'Practice'),
    Tab(text: 'Strategy'),
  ];

  @override
  void initState() {
    super.initState();
    // Initialize tab controller with the number of tabs
    _tabController = TabController(length: tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose(); // Dispose the tab controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the number of cars, default to 1 if not available or invalid
    final numCarsString = widget.account.fireUpData?['team']?['_numCars'];
    final numCars = int.tryParse(numCarsString ?? '1') ?? 1;



    // Create a list of widgets for the carousel, one for each car
    // Each item is a DefaultTabController with its own TabBar and TabBarView
    final List<Widget> carouselItems = List.generate(numCars, (carIndex) {
      // Ensure raceData and necessary nested structures exist before building content
      if (widget.account.raceData == null || widget.account.raceData!['vars'] == null) {
        return Center(child: Text('Race data not available for Car ${carIndex + 1}'));
      }
      // Ensure driver data exists for this car index
      if (widget.account.fireUpData == null ||
          widget.account.fireUpData!['drivers'] == null ||
          carIndex >= widget.account.fireUpData!['drivers'].length) {
         return Center(child: Text('Driver data not available for Car ${carIndex + 1}'));
      }


      return Column(
        children: [
          // TabBar for the current car, using the shared _tabController
          TabBar(
            controller: _tabController, // Use the shared controller
            tabs: tabs,
          ),
          // TabBarView for the current car's content, using the shared _tabController
          SizedBox(
            // Use Flexible/Expanded instead of fixed height if possible,
            // but for now, keep the calculation based on minWindowHeight.
            height: widget.minWindowHeight * 0.8,
            child: TabBarView(
              controller: _tabController, // Use the shared controller
              children: [
                // Setup Content (Car-specific)
                SetupContent(account: widget.account, carIndex: carIndex),
                // Practice Content (Placeholder)
                // TODO: Implement Practice Content
                Center(child: Text('Practice Content Placeholder')),
                // Strategy Content (Car-specific)
                StrategyContent(account: widget.account, carIndex: carIndex),
              ],
            ),
          ),
        ],
      );
    });


    return Column(
      children: [
        Row( // First row with buttons and label
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () {}, // TODO: Implement Repair button action
              style: ElevatedButton.styleFrom(
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Square corners
               ),
              child: const Text('R'),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  // Extract the race name by removing the img tag
                  (widget.account.raceData?['vars']?['raceName'] as String?)
                      ?.replaceAll(RegExp(r'<img[^>]*>'), '')
                      .trim() ?? 'No Race Data',
                  style: Theme.of(context).textTheme.bodyMedium, // Adjust style as needed
                ),
                SizedBox(height: 4), // Add some spacing
                Text(
                  widget.account.raceData?['vars']?['raceTime'] ?? 'No Race Time',
                   style: Theme.of(context).textTheme.bodySmall, // Adjust style as needed
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () {}, // TODO: Implement Save Setup button action
              style: ElevatedButton.styleFrom(
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Square corners
               ),
              child: const Text('S'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        // CarouselSlider for the tab bars and their content (one item per car)
        SizedBox(
          // Calculate height: TabBar height (approx 48-50) + TabBarView height
          height: widget.minWindowHeight * 0.8 + 50, // Adjust 50 if needed (for TabBar)
          child: CarouselSlider.builder(
            carouselController: _carouselController,
            itemCount: carouselItems.length, // Number of items is number of cars
            options: CarouselOptions(
              height: widget.minWindowHeight * 0.8 + 50, // Match SizedBox height
              viewportFraction: 1.0, // Show one full item at a time
              enableInfiniteScroll: false,
              onPageChanged: (index, reason) {
                setState(() {
                  // Update the current carousel page index for the indicator dots
                  _currentCarouselIndex = index;
                });
              },
            ),
            itemBuilder: (context, index, realIdx) {
              return carouselItems[index];
            },
          ),
        ),
        // Indicator dots (only show if numCars is 2 or more, adjusted logic)
        if (numCars > 1)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(numCars, (index) { // Generate labels based on number of cars
              return GestureDetector( // Make the label clickable
                onTap: () {
                  _carouselController.animateToPage(index); // Animate to the tapped page
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 4.0), // Add some padding
                  child: Text(
                    'Car ${index + 1}', // Generate label text
                    style: TextStyle(
                      fontWeight: _currentCarouselIndex == index ? FontWeight.bold : FontWeight.normal, // Bold if selected
                      color: _currentCarouselIndex == index
                          ? Theme.of(context).colorScheme.primary
                          : Theme.of(context).colorScheme.secondary.withOpacity(0.6), // Adjust opacity/color as needed
                    ),
                  ),
                ),
              );
            }),
          ),
      ],
    );
  }
}


// --- SetupContent Widget ---

class SetupContent extends StatefulWidget {
  final Account account; // Use specific Account type
  final int carIndex;

  const SetupContent({Key? key, required this.account, required this.carIndex}) : super(key: key);

  @override
  _SetupContentState createState() => _SetupContentState();
}

class _SetupContentState extends State<SetupContent> with AutomaticKeepAliveClientMixin {
  @override
  bool get wantKeepAlive => true;

  // Map suspension values
  final Map<String, String> suspensionMap = {
    '1': 'soft',
    '2': 'neutral',
    '3': 'firm',
  };
  final Map<String, String> suspensionMapRev = {
    'soft': '1',
    'neutral': '2',
    'firm': '3',
  };

  // Get initial suspension value
  late String initialSuspension;
  late TextEditingController _rideController;
  late TextEditingController _aeroController;
  // Add controllers for the other two text fields if needed
  late TextEditingController _rideOffsetController;
  late TextEditingController _aeroOffsetController;


  @override
  void initState() {
    super.initState();
    String skey = 'd${widget.carIndex + 1}Suspension';
    String rkey = 'd${widget.carIndex + 1}Ride';
    String akey = 'd${widget.carIndex + 1}Aerodynamics';

    initialSuspension = suspensionMap[widget.account.raceData?['vars']?[skey]] ?? 'neutral'; // Default to neutral
    _rideController = TextEditingController(text: widget.account.raceData?['vars']?[rkey]?.toString() ?? '0');
    _aeroController = TextEditingController(text: widget.account.raceData?['vars']?[akey]?.toString() ?? '0');
    _rideOffsetController = TextEditingController(text: '0'); // Initialize offset controllers
    _aeroOffsetController = TextEditingController(text: '0');

    // TODO: Add listeners to controllers if needed to save changes
  }

   @override
  void dispose() {
    _rideController.dispose();
    _aeroController.dispose();
    _rideOffsetController.dispose();
    _aeroOffsetController.dispose();
    super.dispose();
  }


  @override
  Widget build(BuildContext context) {
    // Ensure driver data exists before accessing it
    final driver = (widget.account.fireUpData != null &&
                    widget.account.fireUpData!['drivers'] != null &&
                    widget.carIndex < widget.account.fireUpData!['drivers'].length)
                   ? widget.account.fireUpData!['drivers'][widget.carIndex]
                   : null; // Provide a null fallback

    if (driver == null) {
      return Center(child: Text('Driver data not available.'));
    }

    return Padding( // Add padding around the content
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Distribute space
        children: [
          // Driver Info Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoButton(context, driver.name, () { /* TODO: Driver action */ }),
              _buildInfoButton(context, 'St: ${driver.attributes?[12]?.toString() ?? 'N/A'}', () { /* TODO: Stamina action */ }), // Added null check
              _buildInfoButton(context, 'C: ${driver.contract ?? 'N/A'}', () { /* TODO: Contract action */ }), // Added null check
            ],
          ),

          // Suspension Row
          _buildSetupRow(
            context,
            label: 'Suspension',
            control: DropdownButton<String>(
              value: initialSuspension,
              items: suspensionMap.values.map((String value) {
                return DropdownMenuItem<String>(
                  value: value,
                  child: Text(value, style: Theme.of(context).textTheme.bodySmall), // Smaller text
                );
              }).toList(),
              onChanged: (String? newValue) {
                if (newValue != null) {
                  setState(() {
                    initialSuspension = newValue;
                    String skey = 'd${widget.carIndex + 1}Suspension';
                    widget.account.raceData?['vars']?[skey] = suspensionMapRev[newValue];
                  });
                  // TODO: Save suspension change
                  debugPrint('Suspension changed to: $newValue');
                }
              },
              isDense: true,
            ),
            // Optional second control/button if needed
          ),

          // Ride Height Row
          _buildSetupRow(
            context,
            label: 'Ride',
            control: _buildTextField(_rideController, TextInputType.number),
            control2: _buildTextField(_rideOffsetController, TextInputType.number), // Offset field
          ),

          // Wing Row
          _buildSetupRow(
            context,
            label: 'Wing',
            control: _buildTextField(_aeroController, TextInputType.number),
            control2: _buildTextField(_aeroOffsetController, TextInputType.number), // Offset field
          ),
        ],
      ),
    );
  }

  // Helper to build info buttons
  Widget _buildInfoButton(BuildContext context, String text, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Adjust padding
        textStyle: Theme.of(context).textTheme.bodySmall, // Use smaller text
        minimumSize: Size(60, 30), // Ensure minimum size
      ),
      onPressed: onPressed,
      child: Text(text, textAlign: TextAlign.center),
    );
  }

  // Helper to build setup rows consistently
  Widget _buildSetupRow(BuildContext context, {required String label, required Widget control, Widget? control2}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween, // Space out elements
        children: [
          Expanded(flex: 2, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(flex: 1, child: control),
          if (control2 != null) Expanded(flex: 1, child: Padding(padding: const EdgeInsets.only(left: 8.0), child: control2)),
          if (control2 == null) Spacer(flex: 1), // Add spacer if no second control
        ],
      ),
    );
  }


  // Helper to build text fields consistently
  Widget _buildTextField(TextEditingController controller, TextInputType keyboardType) {
    return SizedBox(
      height: 35, // Constrain height
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textAlign: TextAlign.center,
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        ),
        style: Theme.of(context).textTheme.bodyMedium, // Adjust style
        // TODO: Add onChanged or onSubmitted to save value
      ),
    );
  }
}


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
    if (widget.account.raceData != null && // Use widget.account
        widget.account.raceData!['vars'] != null &&
        widget.account.raceData!['vars'][pitKey] is String) {
      numberOfPits = int.tryParse(widget.account.raceData!['vars'][pitKey]) ?? 0; // Use widget.account
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