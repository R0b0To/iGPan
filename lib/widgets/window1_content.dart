import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse; // Import the parse function
import '../igp_client.dart'; // Import Account and other necessary definitions
import '../utils/helpers.dart'; // Import abbreviateNumber
import '../screens/sponsor_list_screen.dart'; // Import the new sponsor list screen
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart';

class Window1Content extends StatefulWidget {
  final double minWindowHeight;
  final Account account; // Use the specific Account type

  const Window1Content({super.key, required this.minWindowHeight, required this.account});

  @override
  State<Window1Content> createState() => _Window1ContentState();
}

class _Window1ContentState extends State<Window1Content> {

  String _totalEnginesText = 'N/A'; // State variable to hold the text for total engines
  String _totalPartsText = 'N/A'; // State variable to hold the text for total parts
  bool _rewardStatus = false; // State variable for reward status

  @override
  void initState() {
    super.initState();
    // Initialize the state variables with the current values from the widget
    _totalEnginesText = widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['totalEngines'] ?? 'N/A';
    _totalPartsText = widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['totalParts'] ?? 'N/A';
    _rewardStatus = widget.account.fireUpData != null &&
        widget.account.fireUpData!.containsKey('notify') && // Added null check
        widget.account.fireUpData!['notify'] != null &&
        widget.account.fireUpData!['notify'] is Map &&
        widget.account.fireUpData!['notify']!['page'] != null &&
        widget.account.fireUpData!['notify']['page'].containsKey('nDailyReward') &&
        widget.account.fireUpData!['notify']['page']['nDailyReward'] == '0'; // Assuming '0' means available
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
                Text(widget.account.fireUpData?['manager']?['tokens'] ?? '0',style: TextStyle(fontSize: 16),), // Added null check and default
              ],
            ),

             Builder(
                 builder: (BuildContext context) {
                  return SizedBox(
                 
                   child: IconButton(
                     onPressed: _rewardStatus // Use the state variable
                         ? () async { // Make async
                             // Show loading indicator while claiming
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text('Claiming reward for ${widget.account.nickname ?? widget.account.email}...')),
                             );
                             try {
                               await claimDailyReward(widget.account);
                               ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(content: Text('Reward claimed!')),
                               );
                               setState(() {
                                 _rewardStatus = false; // Update the state variable to false after claiming
                               });
                             } catch (e) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(content: Text('Failed to claim reward: $e')),
                               );
                             }
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
       DefaultTabController( // Second row with tab bar
         length: 3,
         child: Column(
           children: [
             const TabBar(
              

               tabs: [
                 Tab(     
                        child: Text('Car', style: TextStyle(fontSize: 12)),),
                 Tab(     
                        child: Text('Team', style: TextStyle(fontSize: 12)),),
                 Tab(  
                        child: Text('Reports', style: TextStyle(fontSize: 12))),
               ],

             ),
             SizedBox(
               height: widget.minWindowHeight * 0.8, // 80% of minWindowHeight
               child: TabBarView(
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
                               onPressed: () {}, // Add functionality later
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
                                       final result = await repairCar(widget.account, i,'parts');
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
                                       final result = await repairCar(widget.account, i,'engine');
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
                   // TODO: Implement Reports tab content
                  Center(child: Text('Team Content Placeholder')),

                   Center(child: Text('Reports Content Placeholder')),

                   
                 ],
               ),
             ),
           ],
         ),
       ),
     ],
   );
 }
}