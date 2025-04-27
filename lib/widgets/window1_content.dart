import 'package:flutter/material.dart';
import 'package:html/parser.dart' show parse; // Import the parse function
import '../igp_client.dart'; // Import Account and other necessary definitions
import '../utils/helpers.dart'; // Import abbreviateNumber
import '../screens/sponsor_list_screen.dart'; // Import the new sponsor list screen

class Window1Content extends StatefulWidget {
  final double minWindowHeight;
  final Account account; // Use the specific Account type

  const Window1Content({Key? key, required this.minWindowHeight, required this.account}) : super(key: key);

  @override
  State<Window1Content> createState() => _Window1ContentState();
}

class _Window1ContentState extends State<Window1Content> {


  @override
  Widget build(BuildContext context) {
    final numCarsString = widget.account.fireUpData?['team']?['_numCars'];
    final numCars = int.tryParse(numCarsString ?? '1') ?? 1;
    // Determine reward status directly from account data
    bool rewardStatus = widget.account.fireUpData != null &&
        widget.account.fireUpData!.containsKey('notify') && // Added null check
        widget.account.fireUpData!['notify'] != null &&
        widget.account.fireUpData!['notify'] is Map &&
        widget.account.fireUpData!['notify']!['page'] != null &&
        widget.account.fireUpData!['notify']['page'].containsKey('nDailyReward') &&
        widget.account.fireUpData!['notify']['page']['nDailyReward'] == '0'; // Assuming '0' means available
    
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
               child: Text(
                 abbreviateNumber(widget.account.fireUpData?['team']?['_balance'] ?? '0'), // Added null check and default
                 style: TextStyle(fontSize: 10),
               ), // Shorter text
             ),
           ),

           Text(widget.account.fireUpData?['manager']?['tokens'] ?? '0'), // Added null check and default
           const SizedBox(width: 4), // Small spacer

             Builder(
                 builder: (BuildContext context) {
                   return ElevatedButton(
                     onPressed: rewardStatus
                         ? () async { // Make async
                             // Show loading indicator while claiming
                             ScaffoldMessenger.of(context).showSnackBar(
                               SnackBar(content: Text('Claiming reward for ${widget.account.nickname ?? widget.account.email}...')),
                             );
                             try {
                               await claimDailyReward(widget.account, accountsNotifier); // Assuming accountsNotifier is accessible or passed down
                               ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(content: Text('Reward claimed!')),
                               );
                               // The ValueNotifier should trigger a rebuild where needed
                             } catch (e) {
                               ScaffoldMessenger.of(context).showSnackBar(
                                 SnackBar(content: Text('Failed to claim reward: $e')),
                               );
                             }
                           }
                         : null, // Disable button if reward not available
                     style: ElevatedButton.styleFrom(
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                       backgroundColor: rewardStatus ? Colors.green : null, // Indicate availability
                     ),
                     child: const Text('Daily', style: TextStyle(fontSize: 10)),
                   );
                 },
               ),

           Column( // Keep sponsor buttons in a column, but make them square
             children: [
               SizedBox(
                 child: ElevatedButton(
                   onPressed: (widget.account.fireUpData?['sponsor']?['s1']?['status'] ?? false) ? null : () {
                     Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => SponsorListScreen(account: widget.account, sponsorNumber: 1), // Pass sponsorNumber 1
                       ),
                     );
                   },
                   style: ElevatedButton.styleFrom(
                     padding: EdgeInsets.zero,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Square corners
                     backgroundColor: (widget.account.fireUpData?['sponsor']?['s1']?['status'] ?? false) ? const Color.fromARGB(255, 57, 117, 59) : const Color.fromARGB(255, 161, 48, 40),
                     disabledBackgroundColor: (widget.account.fireUpData?['sponsor']?['s1']?['status'] ?? false) ? const Color.fromARGB(255, 36, 85, 37) : null,
                     
                   ),
                   child: const Text('S1', style: TextStyle(fontSize: 10)), // Shorter text
                 ),
               ),

               SizedBox(
                 child: ElevatedButton(
                   onPressed: (widget.account.fireUpData?['sponsor']?['s2']?['status'] ?? false) ? null : () {
                      Navigator.push(
                       context,
                       MaterialPageRoute(
                         builder: (context) => SponsorListScreen(account: widget.account, sponsorNumber: 2), // Pass sponsorNumber 2
                       ),
                     );
                   },
                   style: ElevatedButton.styleFrom(
                     padding: EdgeInsets.zero,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Square corners
                     backgroundColor: (widget.account.fireUpData?['sponsor']?['s2']?['status'] ?? false) ? const Color.fromARGB(255, 63, 104, 64) : const Color.fromARGB(255, 161, 48, 40),
                     disabledBackgroundColor: (widget.account.fireUpData?['sponsor']?['s2']?['status'] ?? false) ? const Color.fromARGB(255, 36, 85, 37) : null,
                     
                   ),
                   child: const Text('S2', style: TextStyle(fontSize: 10)), // Shorter text
                 ),
               ),
             ],
           ),
         ],
       ),
       SizedBox(height: 4), // Reduced spacer height
       DefaultTabController( // Second row with tab bar
         length: 2,
         child: Column(
           children: [
             const TabBar(
               tabs: [
                 Tab(text: 'Car'),
                 Tab(text: 'Reports'),
               ],
             ),
             SizedBox(
               height: widget.minWindowHeight * 0.8, // 80% of minWindowHeight
               child: TabBarView(
                 children: [
                   // TODO: Implement Car tab content
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
                               ),
                                child: Text('Parts: ${widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['totalParts']?? 'N/A'}'),
                              ),
                            ),
                           SizedBox(width: 8), // Spacer
                           Expanded(
                             child: ElevatedButton(
                               onPressed: () {}, // Add functionality later
                               style: ElevatedButton.styleFrom(
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                               ),
                                child: Text('Engines: ${widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['totalEngines']  ?? 'N/A'}'),
                              ),
                            ),
                            SizedBox(width: 8), // Spacer
                            Text('Restock: ${widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['restockRaces'] ?? 'N/A'}'),
                          ],
                        ),
                        SizedBox(height: 8), // Spacer
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
                               child: Text('Engine'),
                             ),
                           ),
                           SizedBox(width: 8), // Spacer
                           Expanded(
                             child: ElevatedButton(
                               onPressed: () {}, // Add functionality later
                               style: ElevatedButton.styleFrom(
                                 shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                               ),
                               child: Text('Fuel'),
                             ),
                           ),
                           SizedBox(width: 8), // Spacer
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
                       SizedBox(height: 8), // Spacer
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
                                     onPressed: () {
                                      repairCar(widget.account, i,'parts',accountsNotifier); 
                                     }, // Add functionality later
                                   ),
                                   CircularProgressButton(
                                     label: 'Engine',
                                     progress: double.tryParse(widget.account.fireUpData?['preCache']?['p=cars']?['vars']?['c${i}Engine'] ?? '0') ?? 0.0,
                                     onPressed: () {
                                      repairCar(widget.account, i,'engine',accountsNotifier); 
                                     }, // Add functionality later
                                   ),

                                 ],
                               ),
                             ),
                         ],
                       ),
                     ],
                   ),
                   // TODO: Implement Reports tab content
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