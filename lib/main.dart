import 'dart:async';
import 'package:flutter/material.dart';
import 'accounts_screen.dart';
import 'igp_client.dart'; // Import the new file
import 'package:carousel_slider/carousel_slider.dart';

final ValueNotifier<List<Account>> accountsNotifier = ValueNotifier<List<Account>>([]);

void main() {
  runApp(const MyApp());
  initCookieManager();
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      themeMode: ThemeMode.system,
      darkTheme: ThemeData.dark(useMaterial3: true),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  bool _isLoading = true;
  int _currentPageIndex = 0; // State for horizontal page index (wide screen)
  int _currentNarrowCarouselIndex = 0; // State for narrow screen carousel
  PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadAccounts();
    // Refresh data every 30 seconds
    //Timer.periodic(const Duration(seconds: 30), (timer) {_startClientSessions();});
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }


  Future<void> _loadAccounts() async {
    await loadAccounts(accountsNotifier);
    setState(() {
      _isLoading = false;
      _startClientSessions();
    });
  }

  Future<void> _startClientSessions() async {
    await startClientSessions(accountsNotifier);
   
  }


  @override
  Widget build(BuildContext context) {
    debugPrint('Current screen size: ${MediaQuery.of(context).size.width} x ${MediaQuery.of(context).size.height}');
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<List<dynamic>>(
              valueListenable: accountsNotifier,
              builder: (context, accounts, child) {
                return accounts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text('No accounts registered.'),
                            ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AccountsScreen()),
                                );
                              },
                              child: const Text('Add Account'),
                            ),
                          ],
                        ),
                      )
                    : Column(
                        children: <Widget>[
                          Align(
                            alignment: Alignment.topLeft,
                            child: MenuBar(
                              children: [
                                SubmenuButton(
                                  menuChildren: [
                                    MenuItemButton(
                                      onPressed: () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const AccountsScreen()),
                                        );
                                      },
                                      child: const Text('Accounts'),
                                    ),
                                    MenuItemButton(
                                      onPressed: () {},
                                      child: const Text('Appearance'),
                                    ),
                                  ],
                                  child: const Text('Settings'),
                                ),
                                SubmenuButton(
                                  menuChildren: [
                                    MenuItemButton(
                                      onPressed: () {},
                                      child: const Text('Daily'),
                                    ),
                                    MenuItemButton(
                                      onPressed: () {},
                                      child: const Text('Repair'),
                                    ),
                                    MenuItemButton(
                                      onPressed: () {},
                                      child: const Text('Setup'),
                                    ),
                                    MenuItemButton(
                                      onPressed: () {},
                                      child: const Text('Strategy'),
                                    ),
                                    MenuItemButton(
                                      onPressed: () {},
                                      child: const Text('Save'),
                                    ),
                                  ],
                                  child: const Text('Actions'),
                                ),
                              ],
                            ),
                          ),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                // Define minimum size for sub-windows
                                const double minWindowWidth = 400;
                                const double minWindowHeight = 250;

                                // Check if there's enough horizontal space for two windows side-by-side
                                bool canStackWindowsHorizontally = constraints.maxWidth >= (minWindowWidth * 2);

                                // Re-interpreting the requirement based on the user's description:
                                // - If horizontal space allows two windows side-by-side (>= 800px approx):
                                //   - Stack main containers vertically. If more accounts than fit vertically, the list scrolls (ListView).
                                // - If horizontal space does NOT allow two windows side-by-side (< 800px approx):
                                //   - Stack windows vertically.
                                //   - Use a horizontal carousel for the main containers (PageView).

                                if (canStackWindowsHorizontally) {
                                  // Wide screen: Paginated Vertical Stack (Horizontal PageView)
                                  const double estimatedItemHeight = minWindowHeight + 50; // Estimate height + padding
                                  final itemsPerPage = (constraints.maxHeight / estimatedItemHeight).floor().clamp(1, accounts.length); // Ensure at least 1
                                  final pageCount = (accounts.length / itemsPerPage).ceil();

                                  return Column(
                                    children: [
                                      Expanded(
                                        child: CarouselSlider.builder(
                                          itemCount: pageCount,
                                          options: CarouselOptions(
                                            viewportFraction: 1 , // Display multiple items per page
                                            enableInfiniteScroll: false,
                                            onPageChanged: (index, reason) {
                                              setState(() {
                                                _currentPageIndex = index;
                                              });
                                            },
                                            height: constraints.maxHeight,
                                          ),
                                          itemBuilder: (context, pageIndex, realIdx) {
                                            final startIndex = pageIndex * itemsPerPage;
                                            final endIndex = (startIndex + itemsPerPage).clamp(0, accounts.length);

                                            return Column(
                                              mainAxisSize: MainAxisSize.max, // Take available space
                                              children: [
                                                for (int i = startIndex; i < endIndex; i++)
                                                  AccountMainContainer(
                                                    account: accounts[i],
                                                    minWindowWidth: minWindowWidth,
                                                    minWindowHeight: minWindowHeight,
                                                    canStackWindowsHorizontally: true, // Windows side-by-side
                                                  ),
                                              ],
                                            );
                                          },
                                        ),
                                      ),
                                      // Indicator dots for the horizontal pages
                                      if (pageCount > 1) // Only show dots if multiple pages
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: List.generate(pageCount, (index) {
                                            return Container(
                                              width: 8.0,
                                              height: 8.0,
                                              margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
                                              decoration: BoxDecoration(
                                                shape: BoxShape.circle,
                                                color: _currentPageIndex == index
                                                    ? Theme.of(context).colorScheme.primary
                                                    : Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                                              ),
                                            );
                                          }),
                                        ),
                                    ],
                                  );
                                } else {
                                  // Narrow screen: Horizontal PageView for individual accounts
                                  return Column(
                                    children: [
                                      Expanded(
                                        child: CarouselSlider.builder(
                                          itemCount: accounts.length,
                                          options: CarouselOptions(
                                            scrollDirection: Axis.horizontal, // Make it horizontal
                                            viewportFraction: 1.0,
                                            enableInfiniteScroll: false,
                                            onPageChanged: (index, reason) {
                                              setState(() {
                                                _currentNarrowCarouselIndex = index;
                                              });
                                            },
                                            height: constraints.maxHeight,
                                          ),
                                          itemBuilder: (context, index, realIdx) {
                                            final account = accounts[index];
                                            return AccountMainContainer(
                                              account: account,
                                              minWindowWidth: minWindowWidth,
                                              minWindowHeight: minWindowHeight,
                                              canStackWindowsHorizontally: false, // Windows stacked vertically
                                            );
                                          },
                                        ),
                                      ),
                                      // Indicator dots for the narrow screen
                                      Row( // Changed to Row for horizontal dots
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: List.generate(accounts.length, (index) {
                                          return Container(
                                            width: 8.0,
                                            height: 8.0,
                                            margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0), // Adjusted margin
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: _currentNarrowCarouselIndex == index
                                                  ? Theme.of(context).colorScheme.primary
                                                  : Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                                            ),
                                          );
                                        }),
                                      ),
                                    ],
                                  );
                                }
                              },
                            ),
                          ),
                        ],
                      );
              },
            ),
    );
  }
}

class AccountMainContainer extends StatelessWidget {
  final dynamic account;
  final double minWindowWidth;
  final double minWindowHeight;
  final bool canStackWindowsHorizontally;

  const AccountMainContainer({
    Key? key,
    required this.account,
    required this.minWindowWidth,
    required this.minWindowHeight,
    required this.canStackWindowsHorizontally,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if fireUpData is available
    if (account.fireUpData == null) {
      debugPrint('Account data is null or not loaded yet.');
      return const Center(child: CircularProgressIndicator());
    }

    // Estimate height based on internal layout
    // Add some padding/margin allowance
    final estimatedHeight = canStackWindowsHorizontally
        ? minWindowHeight + 50 // Approx height when windows are horizontal
        : (minWindowHeight * 2) + 60; // Approx height when windows are vertical

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Container( // Use Container to constrain height if needed, though Card might handle it
        // height: estimatedHeight, // Maybe not needed if PageView/Column handles sizing
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important for Column height in ListView/PageView
          children: [
            Text(
              account.nickname ?? account.email ?? 'Unnamed Account',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8.0),
            // Use Flexible or Expanded if windows need to fill space,
            // but for fixed min size, direct Container might be okay.
            _buildInternalWindows(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInternalWindows(BuildContext context) {
    // Create instances of the window content widgets once
    final window1Content = Window1Content(minWindowHeight: minWindowHeight, account: account);
    final window2Content = account.fireUpData['team']['_league'] == '0' ? null : Window2Content(minWindowHeight: minWindowHeight, account: account);

     if (canStackWindowsHorizontally) {
        // Stack windows horizontally
        return Row(
          children: [
            Expanded(
              child: Container(
                constraints: BoxConstraints(
                  minWidth: minWindowWidth,
                  minHeight: minWindowHeight,
                ),
                color: const Color.fromARGB(255, 96, 121, 141), // Placeholder color
                child: window1Content,
              ),
            ),
            const SizedBox(width: 8.0),
            Expanded(
              child: Container(
                constraints: BoxConstraints(
                  minWidth: minWindowWidth,
                  minHeight: minWindowHeight,
                ),
                color: const Color.fromARGB(255, 98, 121, 99), // Placeholder color
                child: window2Content,
              ),
            ),
          ],
        );
      } else {
        // Stack windows vertically
        // Wrap in IntrinsicHeight or give fixed height if needed in PageView
        return Column(
           mainAxisSize: MainAxisSize.min, // Ensure column takes minimum required height
           children: [
            Container(
              constraints: BoxConstraints(
                minWidth: minWindowWidth, // Should be maxWidth of parent?
                minHeight: minWindowHeight,
              ),
              color: const Color.fromARGB(255, 93, 108, 121), // Placeholder color
              child: window1Content,
            ),
            const SizedBox(height: 8.0),
            Container(
              constraints: BoxConstraints(
                 minWidth: minWindowWidth, // Should be maxWidth of parent?
                 minHeight: minWindowHeight,
              ),
              color: const Color.fromARGB(255, 111, 133, 112), // Placeholder color
              child: window2Content,
            ),
          ],
        );
      }
  }
}

class Window1Content extends StatefulWidget {
  final double minWindowHeight;
  final dynamic account;

  const Window1Content({Key? key, required this.minWindowHeight, required this.account}) : super(key: key);

  @override
  State<Window1Content> createState() => _Window1ContentState();
}

class _Window1ContentState extends State<Window1Content> {
  @override
  Widget build(BuildContext context) {
    // Determine reward status directly from account data
bool rewardStatus = widget.account.fireUpData != null &&
        widget.account.fireUpData.containsKey('notify') &&
        widget.account.fireUpData['notify'] != null &&
        widget.account.fireUpData['notify'] is Map &&
        widget.account.fireUpData['notify']!['page'] != null &&
        widget.account.fireUpData['notify']['page'].containsKey('nDailyReward') &&
        widget.account.fireUpData['notify']['page']['nDailyReward'] == '0'; // Assuming true means available
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
                 abbreviateNumber(widget.account.fireUpData['team']['_balance']),
                 style: TextStyle(fontSize: 10),
               ), // Shorter text
             ),
           ),

           Text(widget.account.fireUpData['manager']['tokens']), // Keep text as is for now
           const SizedBox(width: 4), // Small spacer

             Builder(
                 builder: (BuildContext context) {
                   
                   return ElevatedButton(
                     onPressed: rewardStatus
                         ? () {
                             claimDailyReward(widget.account, accountsNotifier);
                             // No need to setState here if claimDailyReward updates the account object
                           }
                         : null,
                     style: ElevatedButton.styleFrom(
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                     ),
                     child: const Text('Daily', style: TextStyle(fontSize: 10)),
                   );
                 },
               ),

           Column( // Keep sponsor buttons in a column, but make them square
             children: [
               SizedBox(
                 child: ElevatedButton(
                   onPressed: () {},
                   style: ElevatedButton.styleFrom(
                     padding: EdgeInsets.zero,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Square corners
                   ),
                   child: const Text('S1', style: TextStyle(fontSize: 10)), // Shorter text
                 ),
               ),

               SizedBox(

                 child: ElevatedButton(
                   onPressed: () {},
                   style: ElevatedButton.styleFrom(
                     padding: EdgeInsets.zero,
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Square corners
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
               child: const TabBarView(
                 children: [
                   Center(child: Text('Car Content')),
                   Center(child: Text('Reports Content')),
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




String abbreviateNumber(String input) {
  final n = double.tryParse(input);
  if (n == null || n == 0) return '0';

  final suffixes = ['', 'K', 'M', 'B', 'T', 'P', 'E', 'Z', 'Y'];
  int magnitude = 0;
  double value = n;

  while (value.abs() >= 1000 && magnitude < suffixes.length - 1) {
    magnitude++;
    value /= 1000.0;
  }

  return '${value.toStringAsFixed(1)}${suffixes[magnitude]}';
}

class Window2Content extends StatefulWidget {
  final double minWindowHeight;
  final dynamic account;

  const Window2Content({Key? key, required this.minWindowHeight, required this.account}) : super(key: key);

  @override
  _Window2ContentState createState() => _Window2ContentState();
}

class _Window2ContentState extends State<Window2Content> with TickerProviderStateMixin {
  late TabController _tabController;
  final CarouselSliderController _carouselController = CarouselSliderController();
  int _currentTabIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize tab controller with a length that will be updated in build
    _tabController = TabController(length: 0, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Get the number of cars, default to 1 if not available or invalid
    final numCarsString = widget.account.fireUpData?['team']?['_numCars'];
    final numCars = int.tryParse(numCarsString ?? '1') ?? 1;

    // Define the tabs and content, which are always the same for each car
    const List<Tab> tabs = [
      Tab(text: 'Setup'),
      Tab(text: 'Practice'),
      Tab(text: 'Strategy'),
    ];


    // Create a list of widgets for the carousel, one for each car
    // Each item is a DefaultTabController with its own TabBar and TabBarView
    final List<Widget> carouselItems = List.generate(numCars, (carIndex) {
      return DefaultTabController(
        length: tabs.length,
        child: Column(
          children: [
            // TabBar for the current car
            const TabBar(
              tabs: tabs,
            ),
            // TabBarView for the current car's content
            SizedBox(
              height: widget.minWindowHeight * 0.8,
              child: TabBarView( // Removed const
                children: [
                  // Setup Content (Car-specific)
                  SetupContent(account: widget.account, carIndex: carIndex), // Use widget.account
                  // Practice Content (Same for all cars)
                  Center(child: Text('Practice Content')),
                  // Strategy Content (Same for all cars)
                  StrategyContent(account: widget.account, carIndex: carIndex),
                ],
              ),
            ),
          ],
        ),
      );
    });


    return Column(
      children: [
        Row( // First row with buttons and label
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton(
              onPressed: () {},
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
                ),
                SizedBox(height: 4), // Add some spacing
                Text(
                  widget.account.raceData?['vars']?['raceTime'] ?? 'No Race Time',
                ),
              ],
            ),
            ElevatedButton(
              onPressed: () {},
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
          height: widget.minWindowHeight * 0.8 + 50, // Adjust 50 if needed
          child: CarouselSlider.builder(
            carouselController: _carouselController,
            itemCount: carouselItems.length, // Number of items is number of cars
            options: CarouselOptions(
              height: widget.minWindowHeight * 0.8 + 50, // Match SizedBox height
              viewportFraction: 1.0,
              enableInfiniteScroll: false,
              onPageChanged: (index, reason) {
                setState(() {
                  // Update the current carousel page index for the indicator dots
                  _currentTabIndex = index;
                });
              },
            ),
            itemBuilder: (context, index, realIdx) {
              return carouselItems[index];
            },
          ),
        ),
        // Indicator dots (only show if numCars is 2)
        if (numCars == 2)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(numCars, (index) { // Generate dots based on number of cars
              return Container(
                width: 8.0,
                height: 8.0,
                margin: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 2.0),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _currentTabIndex == index
                      ? Theme.of(context).colorScheme.primary
                      : Theme.of(context).colorScheme.secondary.withOpacity(0.4),
                ),
              );
            }),
          ),
      ],
    );
  }
}

class SetupContent extends StatefulWidget {
  final dynamic account;
  final int carIndex;

  const SetupContent({Key? key, required this.account, required this.carIndex}) : super(key: key);

  @override
  _SetupContentState createState() => _SetupContentState();
}

class _SetupContentState extends State<SetupContent> {
  // Map suspension values
  Map<String, String> suspensionMap = {
    '1': 'soft',
    '2': 'neutral',
    '3': 'firm',
  };

  // Get initial suspension value
  late String initialSuspension;

  @override
  void initState() {
    super.initState();
    String skey = 'd${widget.carIndex+1}Suspension';
    initialSuspension = suspensionMap[widget.account.raceData['vars'][skey]] ?? 'neutral'; // Default to neutral if value is unexpected
  }

  @override
  Widget build(BuildContext context) {
    debugPrint('SetupContent: account: ${widget.account}, carIndex: ${widget.carIndex}');
    // Define keys

    String akey = 'd${widget.carIndex+1}Aerodynamics';
    String rkey = 'd${widget.carIndex+1}Ride';

    return Column( // Wrap in Column
      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Align children to the start
     
      children: [
        // Existing Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            SizedBox( // Wrap in SizedBox to control height
              
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Square corners
                       padding: EdgeInsets.zero, // Remove padding
                     ),
                onPressed: () {

                  // TODO: Implement Driver button action
                },
                child: Text(widget.account.fireUpData['drivers'][widget.carIndex].name),
              ),
            ),
            SizedBox( // Wrap in SizedBox to control height
              
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Square corners
                       padding: EdgeInsets.zero, // Remove padding
                     ),
                onPressed: () {
                  // TODO: Implement Stamina button action
                },
                child: Text(widget.account.fireUpData['drivers'][widget.carIndex].attributes[12].toString()),
              ),
            ),
            SizedBox( // Wrap in SizedBox to control height
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Square corners
                       padding: EdgeInsets.zero, // Remove padding
                     ),
                onPressed: () {
                  // TODO: Implement Contract button action
                },
                child: Text(widget.account.fireUpData['drivers'][widget.carIndex].contract.toString()),
              ),
            ),
          ],
        ),
       
        // New Row 1: Suspension
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text('Suspension'),
            SizedBox( // Wrap in SizedBox to control height
              
              child: DropdownButton<String>(
                value: initialSuspension,
                items: suspensionMap.values.map((String value) {
                  return DropdownMenuItem<String>(
                    value: value,
                    child: Text(value),
                  );
                }).toList(),
                onChanged: (String? newValue) {
                  setState(() {
                    initialSuspension = newValue!;
                  });
                  debugPrint('Suspension changed to: $newValue');
                },
              ),
            ),
            SizedBox( // Wrap in SizedBox to control height
              
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Square corners
                       padding: EdgeInsets.zero, // Remove padding
                     ),
                onPressed: () {
                  // TODO: Implement Suspension button action
                },
                child: Text('Button'), // Placeholder text
              ),
            ),
          ],
        ),
        // New Row 2: Height
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text('Height'),
            SizedBox( // Wrap TextField in SizedBox to give it a defined width and height
              width: 35, // Adjust width as needed
              
              child: TextField(
                controller: TextEditingController(text: widget.account.raceData['vars'][rkey].toString()),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)), // Reduced padding
                // TODO: Implement Height input change
              ),
            ),
             SizedBox( // Wrap TextField in SizedBox to give it a defined width and height
              width: 35, // Adjust width as needed
              
              child: TextField(
                controller: TextEditingController(text: '0'),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)), // Reduced padding
                // TODO: Implement Height input change
              ),
            ),
          ],
        ),
        // New Row 3: Wing
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            Text('Wing'),
             SizedBox( // Wrap TextField in SizedBox to give it a defined width and height
              width: 35, // Adjust width as needed
              
              child: TextField(
                controller: TextEditingController(text: widget.account.raceData['vars'][akey].toString()),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)), // Reduced padding
                // TODO: Implement Wing input change
              ),
            ),
             SizedBox( // Wrap TextField in SizedBox to give it a defined width and height
              width: 35, // Adjust width as needed
              
              child: TextField(
                controller: TextEditingController(text: '0'),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(border: OutlineInputBorder(), isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)), // Reduced padding
                // TODO: Implement Wing input change
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class StrategyContent extends StatefulWidget {
  final dynamic account;
  final int carIndex;

  const StrategyContent({Key? key, required this.account, required this.carIndex}) : super(key: key);

  @override
  _StrategyContentState createState() => _StrategyContentState();
}

class _StrategyContentState extends State<StrategyContent> {
  @override
  Widget build(BuildContext context) {
    // Calculate pitKey and number of segments
    String pitKey = 'd${widget.carIndex+1}Pits';
    int numberOfSegments = 0;
    if (widget.account.raceData != null &&
        widget.account.raceData.containsKey('vars') &&
        widget.account.raceData['vars'] != null &&
        widget.account.raceData['vars'].containsKey(pitKey) &&
        widget.account.raceData['vars'][pitKey] is String) {
      numberOfSegments = int.parse(widget.account.raceData['vars'][pitKey]);
    }

    // Build the strategy display
    Widget strategyContent;
    if (numberOfSegments > 0 &&
        widget.account.raceData != null &&
        widget.account.raceData.containsKey('parsedStrategy') &&
        widget.account.raceData['parsedStrategy'] != null &&
        widget.account.raceData['parsedStrategy'] is List &&
        widget.carIndex < widget.account.raceData['parsedStrategy'].length &&
        widget.account.raceData['parsedStrategy'][widget.carIndex] is List) {

      List<Widget> strategyItems = [];
      // Iterate up to numberOfSegments, assuming parsedStrategy has enough data
      for (int i = 0; i < numberOfSegments; i++) {
        // Add checks for parsedStrategy[widget.carIndex][i] existence and format
        if (i < widget.account.raceData['parsedStrategy'][widget.carIndex].length &&
            widget.account.raceData['parsedStrategy'][widget.carIndex][i] is List &&
            widget.account.raceData['parsedStrategy'][widget.carIndex][i].length >= 2 &&
            widget.account.raceData['parsedStrategy'][widget.carIndex][i][0] is String &&
            widget.account.raceData['parsedStrategy'][widget.carIndex][i][1] is String) {

          String tyreAsset = widget.account.raceData['parsedStrategy'][widget.carIndex][i][0];
          String labelText = widget.account.raceData['parsedStrategy'][widget.carIndex][i][1];

          strategyItems.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Image.asset(
                    'assets/tyres/$tyreAsset.png',
                    width: 40, // Adjusted size
                    height: 40, // Adjusted size
                  ),
                  Text(
                    labelText,
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 10, // Adjusted size
                    ),
                  ),
                ],
              ),
            ),
          );
        } else {
          // Handle unexpected data format for a segment
          strategyItems.add(
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4.0),
              child: Text('Invalid data for segment $i'),
            ),
          );
        }
      }

      strategyContent = Container(
        padding: const EdgeInsets.all(8.0), // Add padding around the container
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center the row content if it doesn't fill the width
            children: strategyItems,
          ),
        ),
      );

    } else {
      // Handle cases where there's no strategy data or no pits
      strategyContent = Center(child: Text('No strategy data available.'));
    }

    return strategyContent;
  }
}

