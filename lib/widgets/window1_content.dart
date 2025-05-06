import '../screens/race_report_screen.dart';
import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse; // Import the parse function
import '../igp_client.dart'; // Import Account and other necessary definitions
import '../utils/helpers.dart'; // Import abbreviateNumber
import '../screens/sponsor_list_screen.dart'; // Import the new sponsor list screen
import '../services/history_service.dart'; // Import HistoryService
import '../services/account_actions_service.dart'; // Import AccountActionsService
import '../services/car_service.dart'; // Import CarService
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

  final HistoryService _historyService = HistoryService(); // Instantiate HistoryService
  final AccountActionsService _accountActionsService = AccountActionsService(); // Instantiate AccountActionsService
  final CarService _carService = CarService(); // Instantiate CarService

  String _totalEnginesText = 'N/A'; // State variable to hold the text for total engines
  String _totalPartsText = 'N/A'; // State variable to hold the text for total parts
  String _totalTokens = 'N/A';
  bool _rewardStatus = false; // State variable for reward status
  TabController? _tabController; // Controller for the tabs

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

  // Function to fetch reports
  Future<void> _fetchReports() async {
    if (_isLoading || !_hasMoreReports) return;


    debugPrint('loading reports');
    setState(() {
      _isLoading = true;
    });

    try {
      final newReports = await _historyService.requestHistoryReports(widget.account, start: _start, numResults: _numResults); // Use service instance
      setState(() {
        _reports.addAll(newReports);
        _start += newReports.length as int; // Increment start by the number of reports received, explicitly cast to int
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
    final numCars = int.tryParse(numCarsString ?? '1') ?? 1;
    
    return Column(
     mainAxisAlignment: MainAxisAlignment.start, // Align children to the top
     children: [
       Row( // First row with buttons and label - Compacted
         mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Align start
         children: [
           SizedBox( // Wrap button for size control
             child: ElevatedButton(
               onPressed: () {},
               style: ElevatedButton.styleFrom(
                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Square corners
               ),
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
                             await _accountActionsService.claimDailyReward(widget.account); // Use service instance
                              setState(() {
                                _rewardStatus = false; // Update the state variable to false after claiming
                               });
                           }
                         : null, // Disable button if reward not available
                       style: ElevatedButton.styleFrom(
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                     
                     ),
                     icon: _rewardStatus ? Icon(MdiIcons.gift, size: 26,color: Colors.red,) : Icon(MdiIcons.giftOpen, size: 26,color: Colors.green,), // Gift icon
                   ));
                 },
               ),

           Column( // Keep sponsor buttons in a column, but make them square
             children: [
               SizedBox(
                height: 15, 
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
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Square corners
                     backgroundColor: (widget.account.fireUpData?['sponsor']?['s1']?['status'] ?? false) ? const Color.fromARGB(255, 57, 117, 59) : const Color.fromARGB(255, 161, 48, 40),
                     disabledBackgroundColor: (widget.account.fireUpData?['sponsor']?['s1']?['status'] ?? false) ? const Color.fromARGB(255, 36, 85, 37) : null,
                     
                   ),
                   child: const Text('S1', style: TextStyle(fontSize: 11)), // Shorter text
                 ),
               ),

               SizedBox(
                 height: 15, 
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
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Square corners
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
             tabs: const [
               Tab(
                 child: Text('Car', style: TextStyle(fontSize: 12)),
               ),
               Tab(
                 child: Text('Team', style: TextStyle(fontSize: 12)),
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
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                 padding: EdgeInsets.zero,
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
                               style: ElevatedButton.styleFrom(
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                                 padding: EdgeInsets.zero
                               ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(MdiIcons.engine, size: 16), // Engine icon
                                    SizedBox(width: 2), // Space between icon and text
                                    Text(_totalEnginesText), // Use the state variable
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
                               style: ElevatedButton.styleFrom(
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                               ),
                               child: Text('Eng'),
                             ),
                           ),
                           Expanded(
                             child: ElevatedButton(
                               onPressed: () {}, // Add functionality later
                               style: ElevatedButton.styleFrom(
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                               ),
                               child: Text('Fuel'),
                             ),
                           ),
                           Expanded(
                             child: ElevatedButton(
                               onPressed: () {}, // Add functionality later
                               style: ElevatedButton.styleFrom(
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                               ),
                               child: Text('Tyres'),
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
                                       final result = await _carService.repairCar(widget.account, i,'parts'); // Use service instance
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
                                       final result = await _carService.repairCar(widget.account, i,'engine'); // Use service instance
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
                  Center(child: Text('Team Content Placeholder')),

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

        var result = await _carService.buyEnginesWithTokens(widget.account, tokenCost); // Use service instance
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