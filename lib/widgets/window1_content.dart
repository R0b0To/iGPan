import '../screens/race_report_screen.dart';
import 'package:flutter/material.dart';
import '../igp_client.dart'; // Import Account and other necessary definitions
import '../utils/helpers.dart'; // Import abbreviateNumber
import '../screens/sponsor_list_screen.dart'; // Import the new sponsor list screen
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';
import 'package:country_flags/country_flags.dart'; // Import the country_flags package

class Window1Content extends StatefulWidget {
  final double minWindowHeight;
  final Account account; // Use the specific Account type

  const Window1Content({super.key, required this.minWindowHeight, required this.account});

  @override
  State<Window1Content> createState() => _Window1ContentState();
}

class _Window1ContentState extends State<Window1Content>
    with SingleTickerProviderStateMixin { // Add mixin for TabController

  // Define the fuel and tyres maps
  final Map<String, Map<String, int>> _fuelMap = {
    '11': {'fuel_economy':5,'acceleration':-3},
    '7': {'fuel_economy':3,'acceleration':-1},
    '8': {'fuel_economy':-1,'acceleration':3},
    '9': {'fuel_economy':-2,'acceleration':4},
    '10': {'fuel_economy':2},
  };

  final Map<String, Map<String, int>> _tyreMap = {
    '12': {'handling':5,'tyre_economy':-3},
    '13': {'braking':5,'tyre_economy':-3},
    '14': {'tyre_economy':5,'handling':-1},
    '15': {'acceleration':3,'tyre_economy':-3},
    '16': {'tyre_economy':3},
  };

    final Map<String, Map<String, int>> _engineMap = {
    '3': {'fuel_economy':-6,'acceleration':10},
    '1': {'tyre_economy':5},
    '2': {'braking':10,'fuel_economy':-6},
    '4': {'fuel_economy':-6,'handling':10},
    '5': {'downforce':10,'acceleration':-5},
    '6': {'fuel_economy':10,'acceleration':-4},
  };

  String _totalEnginesText = 'N/A'; // State variable to hold the text for total engines
  String _totalPartsText = 'N/A'; // State variable to hold the text for total parts
  String _totalTokens = 'N/A';
  bool _rewardStatus = false; // State variable for reward status
  TabController? _tabController; // Controller for the tabs

  final List<IconData> attributeIcons = [
    MdiIcons.gauge, // acceleration
    MdiIcons.carBrakeLowPressure, // braking
    MdiIcons.thermometer, // cooling
    MdiIcons.arrowDown, // downforce
    MdiIcons.gasStation, // fuel_economy
    MdiIcons.steering, // handling
    MdiIcons.wrench, // reliability
    MdiIcons.tire, // tyre_economy
  ];

  IconData _getIconForAttribute(String attribute) {
    switch (attribute) {
      case 'acceleration':
        return attributeIcons[0];
      case 'braking':
        return attributeIcons[1];
      case 'cooling':
        return attributeIcons[2];
      case 'downforce':
        return attributeIcons[3];
      case 'fuel_economy':
        return attributeIcons[4];
      case 'handling':
        return attributeIcons[5];
      case 'reliability':
        return attributeIcons[6];
      case 'tyre_economy':
        return attributeIcons[7];
      default:
        return Icons.help_outline; // Default icon for unknown attributes
    }
  }

  // Reports tab state
  final ScrollController _scrollController = ScrollController();
  List<Map<String, dynamic>> _reports = [];
  int _start = 0;
  final int _numResults = 10;
  bool _isLoading = false;
  bool _hasMoreReports = true;
  bool _reportsFetched = false; // Flag to track if reports have been fetched initially

  @override
  void initState() {
    super.initState();
    // Initialize the state variables with the current values from the widget
    _totalEnginesText = widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['totalEngines'] ?? 'N/A';
    _totalPartsText = widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['totalParts'] ?? 'N/A';
    _totalTokens = widget.account.fireUpData?['manager']?['tokens'] ?? 'N/A';
    _rewardStatus = widget.account.fireUpData != null &&
        widget.account.fireUpData!.containsKey('notify') && // Added null check
        widget.account.fireUpData!['notify'] != null &&
        widget.account.fireUpData!['notify'] is Map &&
        widget.account.fireUpData!['notify']!['page'] != null &&
        widget.account.fireUpData!['notify']['page'].containsKey('nDailyReward') &&
        widget.account.fireUpData!['notify']['page']['nDailyReward'] == '0'; // Assuming '0' means available

    // Add listener to scroll controller for infinite scrolling
    _scrollController.addListener(_onScroll);

    // Initialize TabController
    _tabController = TabController(length: 3, vsync: this);
    _tabController!.addListener(_handleTabSelection);

  }

  void _handleTabSelection() {
    if (_tabController!.indexIsChanging) {
      // Check if the Reports tab (index 2) is selected and reports haven't been fetched yet
      if (_tabController!.index == 2 && !_reportsFetched) {
        _fetchReports();
        _reportsFetched = true; // Set flag to true after first fetch
      }
    }
  }

  @override
  void dispose() {
    _tabController?.dispose(); // Dispose the TabController
    _scrollController.dispose();
    super.dispose();
  }

  bool _hasExpiringContracts() {

    final int minContractLength = 3; // Minimum contract length to consider
    // Check Main Staff
    if (widget.account.fireUpData?['staff']?['cd']?['contract'] != null &&
        (int.tryParse(widget.account.fireUpData!['staff']!['cd']!['contract'].toString()) ?? 0) < minContractLength) {
      return true;
    }
    if (widget.account.fireUpData?['staff']?['td']?['contract'] != null &&
        (int.tryParse(widget.account.fireUpData!['staff']!['td']!['contract'].toString()) ?? 0) < minContractLength) {
      return true;
    }
    if (widget.account.fireUpData?['staff']?['dr']?['contract'] != null &&
        (int.tryParse(widget.account.fireUpData!['staff']!['dr']!['contract'].toString()) ?? 0) < minContractLength) {
      return true;
    }

    // Check Drivers
    if (widget.account.fireUpData?['drivers'] != null) {
      for (var driver in widget.account.fireUpData!['drivers']) {
        if (driver.contract != null && (int.tryParse(driver.contract.toString()) ?? 0) < minContractLength) {
          return true;
        }
      }
    }

    // Check Reserve Staff
    if (widget.account.fireUpData?['staff']?['reserve'] != null) {
      for (var reserveStaff in widget.account.fireUpData!['staff']!['reserve']) {
        if (reserveStaff['contract'] != null && (int.tryParse(reserveStaff['contract'].toString()) ?? 0) < minContractLength) {
          return true;
        }
      }
    }
    return false;
  }

  // Function to fetch reports
  Future<void> _fetchReports() async {
    if (_isLoading || !_hasMoreReports) return;


    debugPrint('loading reports');
    setState(() {
      _isLoading = true;
    });

    try {
      final newReports = await widget.account.requestHistoryReports(start: _start, numResults: _numResults); // Use service instance
      setState(() {
        _reports.addAll(newReports);
        _start += newReports.length; // Increment start by the number of reports received, explicitly cast to int
        _hasMoreReports = newReports.length == _numResults; // Assume more reports if we got the full batch
      });
    } catch (e) {
      // Handle error, maybe show a SnackBar
      print('Error fetching reports: $e');
      setState(() {
        _hasMoreReports = false; // Stop trying to load more on error
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  // Scroll listener
  void _onScroll() {
    if (_scrollController.position.pixels == _scrollController.position.maxScrollExtent) {
      _fetchReports(); // Fetch more reports when scrolled to the bottom
    }
  }

  @override
  Widget build(BuildContext context) {
    final numCarsString = widget.account.fireUpData?['team']?['_numCars'];
  final numCars = switch (numCarsString) {  int i => i,  String s => int.tryParse(s) ?? 1,  _ => 1,};
    
    return Column(
     mainAxisAlignment: MainAxisAlignment.start, // Align children to the top
     children: [
       Row( // First row with buttons and label - Compacted
         mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Align start
         children: [
           SizedBox( // Wrap button for size control
             child: ElevatedButton(
               onPressed: () {},
               child: Row(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   Image.asset(
                     'assets/cash.webp',
                     width: 20, // Adjust size as needed
                     height: 20, // Adjust size as needed
                   ),
                   SizedBox(width: 4), // Add some spacing between image and text
                   Text(
                     abbreviateNumber(widget.account.fireUpData?['team']?['_balance'] ?? '0'), // Added null check and default
                     style: TextStyle(fontSize: 16),
              
                   ), // Shorter text
                 ],
               ),
             ),
           ),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/token.png',
                  width: 18, // Adjust size as needed
                  height: 18, // Adjust size as needed
                ),
                SizedBox(width: 4), // Add some spacing between image and text
                Text(_totalTokens,style: TextStyle(fontSize: 16),), // Added null check and default
              ],
            ),

             Builder(
                 builder: (BuildContext context) {
                  return SizedBox(
                 
                   child: IconButton(
                     onPressed: _rewardStatus // Use the state variable
                        ? () async { // Make async
                             await widget.account.claimDailyReward(); // Use service instance
                              setState(() {
                                _rewardStatus = false; // Update the state variable to false after claiming
                               });
                           }
                         : null, // Disable button if reward not available
                       style: ElevatedButton.styleFrom(
                     ),
                     icon: _rewardStatus ? Icon(MdiIcons.gift, size: 26,color: Colors.red,) : Icon(MdiIcons.giftOpen, size: 26,color: Colors.green,), // Gift icon
                   ));
                 },
               ),

           Column( // Keep sponsor buttons in a column
             children: [
               SizedBox(
                height: 20, 
                 child: ElevatedButton(
                   onPressed: (widget.account.fireUpData?['sponsor']?['s1']?['status'] ?? false) ? null : () async { // Make async
                     final result = await Navigator.push( // Await the navigation result
                       context,
                       MaterialPageRoute(
                         builder: (context) => SponsorListScreen(account: widget.account, sponsorNumber: 1), // Pass sponsorNumber 1
                       ),
                     );
                     if (result == true) { // Check if the result is true
                       setState(() {
                         
                       });
                     }
                   },
                   style: ElevatedButton.styleFrom(
                     padding: EdgeInsets.zero,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(topLeft: Radius.circular(8.0), topRight: Radius.circular(8.0))),
                     backgroundColor: (widget.account.fireUpData?['sponsor']?['s1']?['status'] ?? false) ? const Color.fromARGB(255, 57, 117, 59) : const Color.fromARGB(255, 161, 48, 40),
                     disabledBackgroundColor: (widget.account.fireUpData?['sponsor']?['s1']?['status'] ?? false) ? const Color.fromARGB(255, 36, 85, 37) : null,
                     
                   ),
                   child: const Text('S1', style: TextStyle(fontSize: 11)), // Shorter text
                 ),
               ),

               SizedBox(
                 height: 20, 
                 child: ElevatedButton(
                   onPressed: (widget.account.fireUpData?['sponsor']?['s2']?['status'] ?? false) ? null : () async { // Make async
                      final result = await Navigator.push( // Await the navigation result
                       context,
                       MaterialPageRoute(
                         builder: (context) => SponsorListScreen(account: widget.account, sponsorNumber: 2), // Pass sponsorNumber 2
                       ),
                     );
                     if (result == true) { // Check if the result is true
                       setState(() {
                         
                       });
                     }
                   },
                   style: ElevatedButton.styleFrom(
                     padding: EdgeInsets.zero,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.only(bottomLeft: Radius.circular(8.0), bottomRight: Radius.circular(8.0))),
                     backgroundColor: (widget.account.fireUpData?['sponsor']?['s2']?['status'] ?? false) ? const Color.fromARGB(255, 63, 104, 64) : const Color.fromARGB(255, 161, 48, 40),
                     disabledBackgroundColor: (widget.account.fireUpData?['sponsor']?['s2']?['status'] ?? false) ? const Color.fromARGB(255, 36, 85, 37) : null,
                     
                   ),
                   child: const Text('S2', style: TextStyle(fontSize: 11)), // Shorter text
                 ),
               ),
             ],
           ),
         ],
       ),
       Column( // Use Column directly instead of DefaultTabController
         children: [
           TabBar( // Pass the controller
             controller: _tabController,
             tabs: [
               Tab(
                 child: Text('Car', style: TextStyle(fontSize: 12)),
               ),
               Tab(
                 child: Container(
                   decoration: BoxDecoration(
                     color: _hasExpiringContracts() ? Colors.red.withOpacity(0.7) : null, // Highlight the whole tab with a red background
                     borderRadius: BorderRadius.circular(8.0), // Rounded corners
                   ),
                   padding: EdgeInsets.symmetric(horizontal: 8.0, vertical: 8), // Add some padding for better visual
                   child: Text('Team', style: TextStyle(fontSize: 12)),
                 ),
               ),
               Tab(
                 child: Text('Reports', style: TextStyle(fontSize: 12))),
             ],
           ),
           SizedBox(
             height: widget.minWindowHeight * 0.8, // 80% of minWindowHeight
             child: TabBarView(
               controller: _tabController, // Pass the controller
               children: [
                 Column(
                   crossAxisAlignment: CrossAxisAlignment.stretch,
                     children: [
                       // First row: totalparts, totalengine buttons and restock races label
                       Row(
                         mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                         children: [
                           Expanded(
                             child: ElevatedButton(
                               onPressed: () {}, // Add functionality later
                               style: ElevatedButton.styleFrom(
                                
                              
                               ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(MdiIcons.carWrench, size: 16), // Engine icon
                                    SizedBox(width: 2), // Space between icon and text
                                    Text(_totalPartsText), // Use the state variable
                                  ],
                                ),
                                
                              ),
                            ),
                           Expanded(
                             child: ElevatedButton(
                               onPressed: _showBuyEnginesDialog,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(MdiIcons.engine, size: 16, color: _totalEnginesText == '0' ? Colors.red : null),
                                    SizedBox(width: 2), // Space between icon and text
                                    Text(_totalEnginesText, style: TextStyle(color: _totalEnginesText == '0' ? Colors.red : null)), 
                                  ],
                                ),
                              ),
                            ),

                            Expanded(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.refresh, size: 16.0), // Icon for restocking
                                  SizedBox(width: 2), // Add some spacing between icon and text
                                  Text('${widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['restockRaces'] ?? 'N/A'}'),
                                ],
                              ),
                            ),
                          ],
                        ),

                        // Second row: engine, fuel, tyres buttons
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            Expanded(
                              child: ElevatedButton(
                               onPressed: () {}, // Add functionality later
                               
                               child: Column(
                                 mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    widget
                                        .account
                                        .fireUpData?['preCache']?['p=cars']?['vars']?['engineSupply'],
                                  ),
                                  if (widget
                                          .account
                                          .fireUpData?['preCache']?['p=cars']?['vars']?['engineId'] !=
                                      null && _engineMap[widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['engineId']]?.entries!=null)
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children:
                                          _engineMap[widget
                                                  .account
                                                  .fireUpData!['preCache']!['p=cars']!['vars']!['engineId']]!
                                              .entries
                                              .map((entry) {
                                                return Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      _getIconForAttribute(
                                                        entry.key,
                                                      ),
                                                      size: 16,
                                                    ),
                                                    SizedBox(width: 2),
                                                    Text('${entry.value}'),
                                                    SizedBox(
                                                      width: 8,
                                                    ), // space between attributes
                                                  ],
                                                );
                                              })
                                              .toList(),
                                    ),
                                ],
                              ),
                             ),
                           ),
                           Expanded(
                             child: ElevatedButton(
                               onPressed: () {}, // Add functionality later
                            
                               child: Column(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                   Text(widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['fuelSupply']),
                                 if (widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['fuelId'] != null)
  Row(
    mainAxisSize: MainAxisSize.min,
    children: _fuelMap[widget.account.fireUpData!['preCache']!['p=cars']!['vars']!['fuelId']]!
        .entries
        .map((entry) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForAttribute(entry.key), size: 16),
              SizedBox(width: 2),
              Text('${entry.value}'),
              SizedBox(width: 8), // space between attributes
            ],
          );
        }).toList(),
  ),

                                 ],
                               ),
                             ),
                           ),
                           Expanded(
                             child: ElevatedButton(
                               onPressed: () {}, // Add functionality later

                               child: Column(
                                 mainAxisSize: MainAxisSize.min,
                                 children: [
                                  Text(widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['tyreSupply']),
                                   if (widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['tyreId'] != null)
  Row(
    mainAxisSize: MainAxisSize.min,
    children: _tyreMap[widget.account.fireUpData!['preCache']!['p=cars']!['vars']!['tyreId']]!
        .entries
        .map((entry) {
          return Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(_getIconForAttribute(entry.key), size: 16),
              SizedBox(width: 2),
              Text('${entry.value}'),
              SizedBox(width: 8), // spacing between entry widgets
            ],
          );
        }).toList(),
  ),
                                 ],
                               ),
                             ),
                           ),
                         ],
                       ),
                       // Third row(s): CircularProgressButton for each car
                       // Assuming a fixed number of cars for now (e.g., 3)
                       Column(
                         children: [
                          
                           for (int i = 1; i <= numCars; i++) // Loop for each car based on account.carIndex
                             Padding(
                               padding: const EdgeInsets.symmetric(vertical: 4.0),
                               child: Row(
                                 mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                 children: [
                                   Text('Car $i:'),
                                     CircularProgressButton(
                                     label: widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['c${i}CarBtn'] ?? '',
                                     progress: double.tryParse(widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['c${i}Condition'] ?? '0') ?? 0.0,
                                     onPressed: () async { // Make the callback async
                                       final result = await widget.account.repairCar(i,'parts'); // Use service instance
                                       if (result != -1) {
                                         setState(() {
                                           _totalPartsText = result.toString(); // Update the state variable
                                         });
                                       }
                                     },
                                   ),
                                   CircularProgressButton(
                                     label: 'Engine',
                                     progress: double.tryParse(widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['c${i}Engine'] ?? '0') ?? 0.0,
                                     onPressed: () async { // Make the callback async
                                       final result = await widget.account.repairCar(i,'engine'); // Use service instance
                                       if (result != -1) {
                                         setState(() {
                                           _totalEnginesText = result.toString(); // Update the state variable
                                          
                                         });
                                       }
                                     },
                                   ),

                                 ],
                               ),
                             ),
                         ],
                       ),
                     ],
                   ),
                  // Team Tab Content
                  Padding( // Add padding for better visual spacing
                    padding: const EdgeInsets.all(8.0),
                    child: SingleChildScrollView( // Use SingleChildScrollView in case content overflows
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Main Staff (CD, TD, DR)
                          Text('Main Staff', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          if (widget.account.fireUpData?['staff']?['cd'] != null)
                            Row(
                              children: [
                                Icon(MdiIcons.accountHardHat, size: 26), // Use doctor icon for DR
                                Text(' ${widget.account.fireUpData!['staff']!['cd']!['name']}'),
                                SizedBox(width: 8),
                                Text(
                                  'Contract: ${widget.account.fireUpData!['staff']!['cd']!['contract']}',
                                  style: (int.tryParse(widget.account.fireUpData!['staff']!['cd']!['contract'].toString()) ?? 0) < 3
                                      ? TextStyle(color: Colors.red)
                                      : null,
                                ),
                              ],
                            ),
                          if (widget.account.fireUpData?['staff']?['td'] != null)
                            Row(
                              children: [
                                Icon(MdiIcons.accountTie, size: 26), // Use doctor icon for DR
                                Text(' ${widget.account.fireUpData!['staff']!['td']!['name']}'),
                                SizedBox(width: 8),
                                Text(
                                  'Contract: ${widget.account.fireUpData!['staff']!['td']!['contract']}',
                                  style: (int.tryParse(widget.account.fireUpData!['staff']!['td']!['contract'].toString()) ?? 0) < 3
                                      ? TextStyle(color: Colors.red)
                                      : null,
                                ),
                              ],
                            ),
                          if (widget.account.fireUpData?['staff']?['dr'] != null)
                            Row(
                              children: [
                                Icon(MdiIcons.doctor, size: 26), // Use doctor icon for DR
                                SizedBox(width: 4), // Add some spacing between icon and text
                                Text('${widget.account.fireUpData!['staff']!['dr']!['name']}'),
                                SizedBox(width: 8),
                                Text(
                                  'Contract: ${widget.account.fireUpData!['staff']!['dr']!['contract']}',
                                  style: (int.tryParse(widget.account.fireUpData!['staff']!['dr']!['contract'].toString()) ?? 0) < 3
                                      ? TextStyle(color: Colors.red)
                                      : null,
                                ),
                              ],
                            ),
                          SizedBox(height: 16), // Space before drivers
                          Text('Drivers', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          // Drivers
                          if (widget.account.fireUpData?['drivers'] != null)
                            for (var driver in widget.account.fireUpData!['drivers'])
                              Row(
                                children: [
                                  Text('${driver.name}'),
                                  SizedBox(width: 8),
                                  Text(
                                    'Contract: ${driver.contract}',
                                    style: (int.tryParse(driver.contract.toString()) ?? 0) < 3
                                        ? TextStyle(color: Colors.red)
                                        : null,
                                  ),
                                ],
                              ),
                          SizedBox(height: 16), // Space before separation
                          Divider(), // Separation line
                          SizedBox(height: 16), // Space after separation
                          // Reserve Staff
                          Text('Reserve Staff', style: TextStyle(fontWeight: FontWeight.bold)),
                          SizedBox(height: 8),
                          if (widget.account.fireUpData?['staff']?['reserve'] != null)
                            for (var reserveStaff in widget.account.fireUpData!['staff']!['reserve'])
                              Row(
                                children: [
                                  Text('${reserveStaff['name']}'),
                                  SizedBox(width: 8),
                                  Text(
                                    'Contract: ${reserveStaff['contract']}',
                                    style: (int.tryParse(reserveStaff['contract'].toString()) ?? 0) < 3
                                        ? TextStyle(color: Colors.red)
                                        : null,
                                  ),
                                ],
                              ),
                        ],
                      ),
                    ),
                  ),

                  // Reports Tab Content
                  ListView.builder(
                    controller: _scrollController,
                    itemCount: _reports.length + (_isLoading ? 1 : 0), // Add 1 for loading indicator
                    itemBuilder: (context, index) {
                      if (index < _reports.length) {
                        final report = _reports[index];
                        return ListTile(
                          leading: CountryFlag.fromCountryCode(
                            report['track'] ?? '', // Use report['track'] for country code, handle null
                            shape: const RoundedRectangle(6),
                            width: 30, // Adjust size as needed
                            height: 20, // Adjust size as needed
                          ),
                          title: Text('${report['text']}'),
                          subtitle: Text('${report['date']}'),
                          trailing: ConstrainedBox(
                          constraints: BoxConstraints(maxWidth: 100),
                          child: Text(report['league'] ?? ''),
                            ),
                          // You can add more details or customize the ListTile appearance
                          onTap: () {
                            // Navigate to a new screen and pass the report id
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => RaceReportScreen(report: report, account: widget.account),
                              ),
                            );
                          },
                        );
                      } else {
                        // Show loading indicator at the end
                        return const Padding(
                          padding: EdgeInsets.all(8.0),
                          child: Center(child: CircularProgressIndicator()),
                        );
                      }
                    },
                  ),


                ],
              ),
            ),
          ],
        ),
    ],
  );
}
  // Function to show the buy engines dialog
  Future<void> _showBuyEnginesDialog() async {
    // Show the initial options dialog
    await showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Buy Engines with Tokens'),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context); // Close the options dialog
                    _confirmPurchase(3, 1); // Confirm purchase: 3 tokens for 1 engine
                  },
                  child: const Text('1 Engine for 3 Tokens'),
                ),
                SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context); // Close the options dialog
                    _confirmPurchase(4, 3); // Confirm purchase: 4 tokens for 3 engines
                  },
                  child: const Text('3 Engines for 4 Tokens'),
                ),
                SimpleDialogOption(
                  onPressed: () {
                    Navigator.pop(context); // Close the options dialog
                    _confirmPurchase(5, 5); // Confirm purchase: 5 tokens for 5 engines
                  },
                  child: const Text('5 Engines for 5 Tokens'),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(); // Close the options dialog
              },
            ),
          ],
        );
      },
    );
  }

  // Function to show the confirmation dialog and handle purchase
  Future<void> _confirmPurchase(int tokenCost, int engineAmount) async {
    bool? confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // User must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Are you sure?'),
          content: Text('Buy $engineAmount engine(s) for $tokenCost tokens?'),
          actions: <Widget>[
            TextButton(
              child: const Text('Cancel'),
              onPressed: () {
                Navigator.of(context).pop(false); // Return false (not confirmed)
              },
            ),
            TextButton(
              child: const Text('Accept'),
              onPressed: () {
                Navigator.of(context).pop(true); // Return true (confirmed)
              },
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      try {

        var result = await widget.account.buyEnginesWithTokens(tokenCost); // Use service instance
        setState(() {
          _totalEnginesText = result['engines'] ?? 'N/A'; // Handle potential null
          _totalTokens = result['tokens'] ?? 'N/A'; // Handle potential null
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase successful! New engine total: $_totalEnginesText')),
        );
      } catch (e) {
        // Handle potential errors during purchase
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Purchase failed: $e')),
        );
      }
    }
  }
}