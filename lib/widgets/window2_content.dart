import 'package:igpan/widgets/research_dialog_content.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import '../utils/helpers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart'; // Import for input formatters
import 'package:carousel_slider/carousel_slider.dart';
import '../igp_client.dart'; // Import Account and other necessary definitions
import 'strategy_content.dart';


class Window2Content extends StatefulWidget {
  final double minWindowHeight;
  final Account account; // Use the specific Account type

  const Window2Content({super.key, required this.minWindowHeight, required this.account});

  @override
  _Window2ContentState createState() => _Window2ContentState();
}

class _Window2ContentState extends State<Window2Content> with TickerProviderStateMixin {
  final CarService _carService = CarService(); // Instantiate CarService
  final RaceService _raceService = RaceService(); // Instantiate RaceService

  late TabController _tabController;
  final CarouselSliderController _carouselController = CarouselSliderController();
  int _currentCarouselIndex = 0; // Renamed for clarity
  bool _hasChanges = false; // Added state variable to track changes

  // Callback function to update _hasChanges
  void _setHasChanges(bool value) {
    setState(() {
      _hasChanges = value;
    });
  }

  // Define the tabs as a class member
  final List<Tab> tabs = const [
    Tab(    
      child: Text('Setup', style: TextStyle(fontSize: 12))),
    Tab(      
      child: Text('Practice', style: TextStyle(fontSize: 12))),
    Tab(      
      child: Text('Strategy', style: TextStyle(fontSize: 12))),
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
          TabBar(
            
            controller: _tabController, // Use the shared controller
            tabs: tabs,
          ),
          // TabBarView for the current car's content, using the shared _tabController
          Expanded(

            child: TabBarView(

              controller: _tabController, // Use the shared controller
              children: [
               
                SetupContent(account: widget.account, carIndex: carIndex, onAccountChanged: _setHasChanges),
                Center(child: Text('Practice Content Placeholder')),
                StrategyContent(account: widget.account, carIndex: carIndex, onAccountChanged: _setHasChanges),

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
            IconButton(
              
              onPressed: () async {
                final researchData = await _carService.requestResearch(widget.account); // Use service instance
                if (researchData != null) {
                  final GlobalKey<ResearchDialogContentState> researchDialogKey = GlobalKey<ResearchDialogContentState>();

                  showDialog(
                    context: context,
                    builder: (BuildContext context) {
                      return AlertDialog(
                         insetPadding: EdgeInsets.symmetric(horizontal: 10), // margin from screen edges, vertical padding removed to allow auto-sizing
                         contentPadding: EdgeInsets.fromLTRB(1, 1, 1, 1), // left, top, right, bottom
                        content: ResearchDialogContent(key: researchDialogKey, researchData: researchData),
                        actions: <Widget>[
                          TextButton(
                            child: Text('Close'),
                            onPressed: () {
                              Navigator.of(context).pop();
                            },
                          ),
                          TextButton( // Add the Save button
                            child: Text('Save'),
                            onPressed: () async { // Make async if saveDesign is async
                              // Access the state via the key
                              final currentState = researchDialogKey.currentState;
                              if (currentState != null) {
                                // Assume methods exist to get the data (will verify/add in ResearchDialogContent)
                                final Map<String, dynamic> research = currentState.getResearchMap();
                                final List<String> designList = currentState.getDesignList(); // Renamed for clarity

                           
                               // Call the save function from igp_client.dart with the correct types
                               await _carService.saveDesign(widget.account, research, designList); // Use service instance

                               // Close the dialog after saving
                                Navigator.of(context).pop();
                              } else {
                                // Handle error: couldn't access dialog state
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Error accessing dialog data.')),
                                );
                              }
                            },
                          ),
                        ],
                      );
                    },
                  );
                } else {
                  // Handle case where research data is null (e.g., show an error message)
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Failed to fetch research data.'),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
              
               ),
              icon:  Icon(MdiIcons.flaskEmptyPlus,size: 30,color:Colors.blueAccent,), // Use icon instead of text for repair action
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
                       IconButton(
              onPressed: () async { // Make async to await saveStrategy
                await _raceService.saveStrategy(widget.account); // Use service instance
                _setHasChanges(false); // Reset changes flag after saving
              }, 
              style: ElevatedButton.styleFrom(
                
                 backgroundColor: _hasChanges ?  const Color.fromARGB(255, 172, 47, 38) : const Color.fromARGB(255, 23, 109, 23), // Highlight if changes exist
               ),
              icon: const Icon(Icons.save,size: 30,), // Use icon instead of text for save action
            ),
          ],
        ),
       
       
        
          CarouselSlider.builder(
            carouselController: _carouselController,
            itemCount: carouselItems.length, // Number of items is number of cars
            options: CarouselOptions(
              viewportFraction: 1, // Show one full item at a time
              height: widget.minWindowHeight + 50, // Adjust height based on available space
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
          
            if (numCars > 1)
          Column(
            children: [
              SizedBox(
                
              ),
              Align(
            alignment: Alignment.bottomCenter,
           
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(numCars, (index) { // Generate labels based on number of cars
                return GestureDetector( // Make the label clickable
                  onTap: () {
                    _carouselController.animateToPage(index); // Animate to the tapped page
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4.0), // Add some padding
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
          ),

            ],
          ),
    
      ],
    );
  }
}


// --- SetupContent Widget ---

class SetupContent extends StatefulWidget {
  final Account account; // Use specific Account type
  final int carIndex;
  final ValueChanged<bool> onAccountChanged; // Added callback

  const SetupContent({super.key, required this.account, required this.carIndex, required this.onAccountChanged});

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
    _rideOffsetController = TextEditingController(text: ''); // Initialize offset controllers
    _aeroOffsetController = TextEditingController(text: '');

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
      padding: const EdgeInsets.symmetric(vertical: 0, horizontal: 4.0),
      child: Column(
        

        children: [
          // Driver Info Row
          SizedBox(height: 30,    
          child:      
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildInfoButton(context, driver?.name, () { /* TODO: Driver action */ }),
              _buildInfoButton(context, '${driver.attributes?[12]?.toStringAsFixed(0) ?? 'N/A'}', () { /* TODO: Stamina action */ }), // Added null check
              _buildInfoButton(context, '${driver.contract ?? 'N/A'}', () { /* TODO: Contract action */ }), // Added null check
            ],
          ),
          ),
          SizedBox(height: 8),
          // Suspension Row
          _buildSetupRow(
            context,
            label: 'Suspension',
            control: DropdownButton<String>(
              value: initialSuspension,
              icon: SizedBox.shrink(),
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
                    widget.onAccountChanged(true); // Notify parent of change
                  });
                }
              },
              isDense: true,
            ),
            control2: ElevatedButton(
              onPressed: () {
                final fireUpData = widget.account.fireUpData;
                if (fireUpData != null) {
                  final drivers = fireUpData['drivers'];
                  final team = fireUpData['team'];
                  final raceData = widget.account.raceData;

                  if (drivers != null && widget.carIndex < drivers.length && team != null && raceData != null) {
                    final driverAttributes = drivers[widget.carIndex]?.attributes;
                    final tier = team['_tier'];
                    final raceNameHtml = raceData['vars']['raceName'];

                    if (driverAttributes != null && driverAttributes.length > 13 && tier != null && raceNameHtml != null) {
                      final double height = driverAttributes[13];
                      final int tierValue = int.tryParse(tier) ?? 1;

                      final CarSetup carSetup = CarSetup(widget.account.raceData?['vars']['trackId'], height, tierValue);
                      final int suggestedRide = carSetup.ride;
                      final int suggestedWing = carSetup.wing;
                      final int suggestedSuspension = carSetup.suspension+1; // Adjusted to match the dropdown values

                      // Use suggestedRide, suggestedWing, and suggestedSuspension for dropdown, aero, and ride
                      setState(() {
                        initialSuspension = suspensionMap[suggestedSuspension.toString()] ?? 'neutral';
                        _rideController.text = suggestedRide.toString();
                        _aeroController.text = suggestedWing.toString();
                        // Update the underlying raceData as well
                        String skey = 'd${widget.carIndex + 1}Suspension';
                        String rkey = 'd${widget.carIndex + 1}Ride';
                        String akey = 'd${widget.carIndex + 1}Aerodynamics';
                        widget.account.raceData?['vars']?[skey] = suggestedSuspension.toString(); // Store as string '1', '2', '3'
                        widget.account.raceData?['vars']?[rkey] = suggestedRide;
                        widget.account.raceData?['vars']?[akey] = suggestedWing;
                      });
                    }
                  }
                }
              },
              style: ElevatedButton.styleFrom(
              
                 padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Adjust padding
                 textStyle: Theme.of(context).textTheme.bodyLarge, // Use smaller text

               ),
              child: Icon(MdiIcons.headLightbulbOutline, size: 30,color: Colors.yellowAccent,), // Or MdiIcons.thumbUpOutline
            ),
          ),
          SizedBox(height: 8),
          // Ride Height Row
          _buildSetupRow(
            context,
            label: 'Ride',
            control: _buildTextField(
              _rideController,
              TextInputType.number,
              inputFormatters: [ // Limit to numbers up to 100
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3), // Max 3 digits for 100
                NumericalRangeFormatter(min: 0, max: 100),
              ],
              onChanged: (newValue) {
                String rkey = 'd${widget.carIndex + 1}Ride';
                widget.account.raceData?['vars']?[rkey] = int.tryParse(newValue) ?? 0;
                 widget.onAccountChanged(true);
              },
            ),
            control2: _buildTextField(
              _rideOffsetController,
              TextInputType.numberWithOptions(signed: true), // Allow negative numbers
              hintText: 'offset', // Placeholder text
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')), // Allow optional minus and digits
              ],
            ), // Offset field
          ),

          // Wing Row
          _buildSetupRow(
            context,
            label: 'Wing',
            control: _buildTextField(_aeroController,
            TextInputType.number,
              inputFormatters: [ // Limit to numbers up to 100
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(3), // Max 3 digits for 100
                NumericalRangeFormatter(min: 1, max: 100),
              ],
              onChanged: (newValue) {
                String akey = 'd${widget.carIndex + 1}Aerodynamics';
                widget.account.raceData?['vars']?[akey] = int.tryParse(newValue) ?? 0;
                 widget.onAccountChanged(true);
              },
            ),
            control2: _buildTextField(
              _aeroOffsetController,
              TextInputType.numberWithOptions(signed: true), // Allow negative numbers
              hintText: 'offset', // Placeholder text
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')), // Allow optional minus and digits
              ],
            ), // Offset field
          ),
        ],
      ),
    );
    
    
    
    
  }

  // Helper to build info buttons
  Widget _buildInfoButton(BuildContext context, String text, VoidCallback onPressed) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 0, vertical: 4), // Adjust padding
        textStyle: Theme.of(context).textTheme.bodyMedium, // Use smaller text
        minimumSize: Size(60, 30), // Ensure minimum size
      ),
      onPressed: onPressed,
      child: Text(text, textAlign: TextAlign.center),
    );
  }

  // Helper to build setup rows consistently
  Widget _buildSetupRow(BuildContext context, {required String label, required Widget control, Widget? control2}) {


   return  Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Space out elements
        children: [
          Expanded(flex: 1, child: Text(label, style: Theme.of(context).textTheme.bodyMedium)),
          Expanded(flex: 1, child: control),
          if (control2 != null) Expanded(flex: 1, child: Padding(padding: const EdgeInsets.only(left: 8.0), child: control2)),
          if (control2 == null) Spacer(flex: 1), // Add spacer if no second control
        ],
      );
  
  }


  // Helper to build text fields consistently
  Widget _buildTextField(TextEditingController controller, TextInputType keyboardType, {String? hintText, List<TextInputFormatter>? inputFormatters, ValueChanged<String>? onChanged}) {
    return SizedBox(
      height: 35, // Constrain height
      child: TextField(
        controller: controller,
        keyboardType: keyboardType,
        textAlign: TextAlign.center,
        inputFormatters: inputFormatters, // Added input formatters
        onChanged: onChanged, // Added onChanged callback
        decoration: InputDecoration(
          border: OutlineInputBorder(),
          isDense: true,
          contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          hintText: hintText, // Added hint text
        ),
        style: Theme.of(context).textTheme.bodyMedium, // Adjust style
        // TODO: Add onChanged or onSubmitted to save value
      ),
    );
  }
}

// Custom InputFormatter to limit numerical range
class NumericalRangeFormatter extends TextInputFormatter {
  final double min;
  final double max;

  NumericalRangeFormatter({required this.min, required this.max});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.isEmpty) {
      return newValue;
    }

    final double? value = double.tryParse(newValue.text);

    if (value == null) {
      // If not a valid number, keep the old value
      return oldValue;
    }

    if (value < min) {
      // If the value is less than the minimum, set it to the minimum
      return TextEditingValue(
        text: min.toString(),
        selection: TextSelection.collapsed(offset: min.toString().length),
      );
    } else if (value > max) {
      // If the value is greater than the maximum, set it to the maximum
      return TextEditingValue(
        text: max.toString(),
        selection: TextSelection.collapsed(offset: max.toString().length),
      );
    }

    // If the value is within the range, return the new value
    return newValue;
  }
}


