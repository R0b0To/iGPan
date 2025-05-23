import 'package:country_flags/country_flags.dart';
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
                PracticeContent(account: widget.account, carIndex: carIndex), // Added PracticeContent
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
                final researchData = await widget.account.requestResearch(); // Use service instance
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
                               await widget.account.saveDesign(research, designList); // Use service instance

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
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Builder(
                      builder: (BuildContext context) {
                        final countryCode = widget.account.raceData?['trackCode'];
                        if (countryCode.isNotEmpty) {
                          return Padding(
                            padding: const EdgeInsets.only(right: 8.0),
                            child: CountryFlag.fromCountryCode(
                              shape: const RoundedRectangle(6),
                              countryCode,
                              height: 20, // Adjust size as needed
                              width: 25, // Adjust size as needed
                            ),
                          );
                        } else {
                          return const SizedBox.shrink(); // No flag if code not found
                        }
                      },
                    ),
                    Text(
                      // Extract the race name by removing the img tag
                      (widget.account.raceData?['vars']?['raceName'] as String?)
                          ?.replaceAll(RegExp(r'<img[^>]*>'), '')
                          .trim() ?? 'No Race Data',
                      style: Theme.of(context).textTheme.bodyMedium, // Adjust style as needed
                    )
                    
                  ],
                ),
                SizedBox(height: 4), // Add some spacing
                Row(
                  children: [
Text(
                  widget.account.raceData?['vars']?['raceTime'] ?? 'No Race Time',
                   style: Theme.of(context).textTheme.bodySmall, // Adjust style as needed
                ),
                if (widget.account.raceData?['vars']?['pWeather'] != null)
                      _buildWeatherWeatherWidget(context, widget.account.raceData!['vars']!['pWeather'] as String),

                  ],
                ),
                
              ],
            ),
                       IconButton(
              onPressed: () async { // Make async to await saveStrategy
                await widget.account.saveStrategy(); // Use service instance
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

Widget _buildWeatherWeatherWidget(BuildContext context, String pWeather) {
  // Regex to extract water level text
  final waterLevelRegex = RegExp(r'<span class="waterLevelText weatherTemp">(.*?)<\/span>');
  final waterLevelMatch = waterLevelRegex.firstMatch(pWeather);
  final waterLevelText = waterLevelMatch?.group(1) ?? 'N/A';

  // Regex to extract weather icon name
  final iconRegex = RegExp(r'<icon size="32">(.*?)<\/icon>');
  final iconMatch = iconRegex.firstMatch(pWeather);
  final iconName = iconMatch?.group(1) ?? 'unknown';

  // Regex to extract temperature (text after icon tag)
  final tempRegex = RegExp(r'<\/icon>\s*(.*)');
  final tempMatch = tempRegex.firstMatch(pWeather);
  final temperature = tempMatch?.group(1)?.trim() ?? 'N/A';

  // Map icon name to MdiIcons
  IconData weatherIcon;
  switch (iconName.toLowerCase()) {
    case 'sun':
      weatherIcon = MdiIcons.weatherSunny;
      break;
    case 'cloudy':
      weatherIcon = MdiIcons.weatherCloudy;
      break;
    case 'cloudy1':
      weatherIcon = MdiIcons.weatherPartlyCloudy;
      break;
    case 'rainy1':
      weatherIcon = MdiIcons.weatherPouring;
      break;
    case 'storm':
      weatherIcon = MdiIcons.weatherLightningRainy;
      break;
    // Add more cases as needed
    default:
      weatherIcon = MdiIcons.helpCircleOutline; // Default icon for unknown weather
  }

  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(MdiIcons.thermometerWater, size: 16), // Water level icon
      SizedBox(width: 2),
      Text(waterLevelText, style: Theme.of(context).textTheme.bodySmall), // Water level text
      SizedBox(width: 8),
      Icon(weatherIcon, size: 16), // Weather icon
      SizedBox(width: 2),
      Text(temperature, style: Theme.of(context).textTheme.bodySmall), // Temperature text
    ],
  );
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

    initialSuspension = suspensionMap[widget.account.raceData?['vars']?['d${widget.carIndex + 1}Suspension']] ?? 'neutral'; // Default to neutral
    _rideController = TextEditingController(text: widget.account.raceData?['vars']?['d${widget.carIndex + 1}Ride']?.toString() ?? '0');
    _aeroController = TextEditingController(text: widget.account.raceData?['vars']?['d${widget.carIndex + 1}Aerodynamics']?.toString() ?? '0');
    _rideOffsetController = TextEditingController(text: ''); // Initialize offset controllers
    _aeroOffsetController = TextEditingController(text: '');
    
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
                    String suspensionKey = 'd${widget.carIndex + 1}Suspension';
                    widget.account.raceData?['vars']?[suspensionKey] = suspensionMapRev[newValue];
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
                        String suspensionKey = 'd${widget.carIndex + 1}Suspension';
                        String rideHeightKey = 'd${widget.carIndex + 1}Ride';
                        String aerodynamicsKey = 'd${widget.carIndex + 1}Aerodynamics';
                        widget.account.raceData?['vars']?[suspensionKey] = suggestedSuspension.toString(); // Store as string '1', '2', '3'
                        widget.account.raceData?['vars']?[rideHeightKey] = suggestedRide;
                        widget.account.raceData?['vars']?[aerodynamicsKey] = suggestedWing;
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
                String rideHeightKey = 'd${widget.carIndex + 1}Ride';
                widget.account.raceData?['vars']?[rideHeightKey] = int.tryParse(newValue) ?? 0;
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
                String aerodynamicsKey = 'd${widget.carIndex + 1}Aerodynamics';
                widget.account.raceData?['vars']?[aerodynamicsKey] = int.tryParse(newValue) ?? 0;
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

  // Helper function to build info buttons
  Widget _buildInfoButton(BuildContext context, String? text, VoidCallback onPressed) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4), // Adjust padding
        textStyle: Theme.of(context).textTheme.bodySmall, // Use smaller text
      ),
      child: Text(text ?? 'N/A'),
    );
  }

  // Helper function to build setup rows
  Widget _buildSetupRow(BuildContext context, {required String label, required Widget control, Widget? control2}) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Expanded(
          flex: 2, // Give label more space
          child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
        ),
        Expanded(
          flex: 3, // Give control more space
          child: control,
        ),
        if (control2 != null) // Conditionally add the second control
          Expanded(
            flex: 2, // Give control2 less space
            child: control2,
          ),
      ],
    );
  }

  // Helper function to build text fields
  Widget _buildTextField(
    TextEditingController controller,
    TextInputType keyboardType, {
    String? hintText,
    List<TextInputFormatter>? inputFormatters,
    ValueChanged<String>? onChanged,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      decoration: InputDecoration(
        hintText: hintText,
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 12), // Adjust padding
      ),
      style: Theme.of(context).textTheme.bodySmall, // Smaller text
    );
  }
}

// --- PracticeContent Widget ---

class PracticeContent extends StatefulWidget {
  final Account account;
  final int carIndex;

  const PracticeContent({super.key, required this.account, required this.carIndex});

  @override
  _PracticeContentState createState() => _PracticeContentState();
}

class _PracticeContentState extends State<PracticeContent> {
  String? _selectedTyre;
  List<String> _practiceResults = [];

  final List<String> availableTyres = ['SS', 'S', 'M', 'H', 'I', 'W'];

  void _generatePracticeResults() async { // Make the method async
    if (_selectedTyre == null) {
      // Handle case where no tyre is selected
      debugPrint('No tyre selected for practice.');
      return;
    }

    setState(() {
      _practiceResults = ['Simulating practice lap...']; // Provide feedback to the user
    });

    try {
      final lapData = await widget.account.simulatePracticeLap(widget.carIndex, _selectedTyre!);

      // Format the results and update the list
      final lapTyre = lapData['lapTyre'];
      final lapFuel = lapData['lapFuel'];
      final lapTime = lapData['lapTime'];
      final comments = lapData['comments']; // Assuming 'comments' is the suggestion text

      setState(() {
        _practiceResults = [
          'Wear: $lapTyre',
          'Fuel: $lapFuel',
          'Time: $lapTime',
          'Suggestions: $comments',
        ];
      });
    } catch (e) {
      debugPrint('Error during practice simulation: $e');
      setState(() {
        _practiceResults = ['Error simulating practice lap: ${e.toString()}'];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Row(
            children: [
            DropdownButton<String>(
  icon: const SizedBox.shrink(),
  underline: const SizedBox.shrink(),
  isDense: true,
  value: _selectedTyre,
  hint: const Text('Select Tyre'),
  selectedItemBuilder: (BuildContext context) {
    return availableTyres.map((String tyre) {
      return SizedBox(
        width: 85, // Match the total width you want the dropdown button to take
        height: 50,
        child: Align(
          alignment: Alignment.center,
          child: Image.asset(
            'assets/tyres/_$tyre.png',
            width: 40,
            height: 40,
            errorBuilder: (c, e, s) => Container(
              width: 40,
              height: 40,
              color: Colors.grey[300],
              child: Icon(Icons.tire_repair, size: 12, color: Colors.grey[600]),
            ),
          ),
        ),
      );
    }).toList();
  },
  items: availableTyres.map((String tyre) {
    return DropdownMenuItem<String>(
      value: tyre,
      child: Center(
        child: Image.asset(
          'assets/tyres/_$tyre.png',
          width: 40,
          height: 40,
          errorBuilder: (c, e, s) => Container(
            width: 40,
            height: 40,
            color: Colors.grey[300],
            child: Icon(Icons.tire_repair, size: 12, color: Colors.grey[600]),
          ),
        ),
      ),
    );
  }).toList(),
  onChanged: (String? newValue) {
    setState(() {
      _selectedTyre = newValue;
    });
  },
),
      
              SizedBox(width: 16), // Space between dropdown and button
              ElevatedButton(
                onPressed: _selectedTyre != null ? _generatePracticeResults : null,
                child: Text('Generate Practice'),
              ),
            ],
          ),
          SizedBox(height: 16), // Space between row and list
          Expanded(
            child: ListView.builder(
              itemCount: _practiceResults.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(_practiceResults[index]),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Helper class for numerical range formatting
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
      return TextEditingValue();
    }
    final double? value = double.tryParse(newValue.text);
    if (value != null) {
      if (value < min) {
        return TextEditingValue(text: min.toStringAsFixed(0));
      } else if (value > max) {
        return TextEditingValue(text: max.toStringAsFixed(0));
      }
    }
    return newValue;
  }
}
