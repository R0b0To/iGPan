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
                                const double minWindowHeight = 200;

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
                child: Window1Content(minWindowHeight: minWindowHeight, account: account),
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
                child: Window2Content(minWindowHeight: minWindowHeight, account: account),
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
              child: Window1Content(minWindowHeight: minWindowHeight, account: account),
            ),
            const SizedBox(height: 8.0),
            Container(
              constraints: BoxConstraints(
                 minWidth: minWindowWidth, // Should be maxWidth of parent?
                 minHeight: minWindowHeight,
              ),
              color: const Color.fromARGB(255, 111, 133, 112), // Placeholder color
              child: Window2Content(minWindowHeight: minWindowHeight, account: account),
            ),
          ],
        );
      }
  }
}

class Window1Content extends StatelessWidget {
 final double minWindowHeight;
 final dynamic account;

 const Window1Content({Key? key, required this.minWindowHeight, required this.account}) : super(key: key);

 @override
 Widget build(BuildContext context) {
   return Column(
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
                 abbreviateNumber(account.fireUpData['team']['_balance']),
                 style: TextStyle(fontSize: 10),
               ), // Shorter text
             ),
           ),

           Text(account.fireUpData['manager']['tokens']), // Keep text as is for now
           const SizedBox(width: 4), // Small spacer

             Builder(
                 builder: (BuildContext context) {
                   bool reward_status;
                   if (account.fireUpData['notify'] == null || !account.fireUpData['notify'].containsKey('page') || !account.fireUpData['notify']['page'].containsKey('nDailyReward')) {
                     reward_status = false;
                   } else {
                     reward_status = true;
                   }
                   return ElevatedButton(
                     onPressed: reward_status ? () {} : null,
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
               height: minWindowHeight * 0.8, // 80% of minWindowHeight
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

class Window2Content extends StatelessWidget {
  final double minWindowHeight;
  final dynamic account;

  const Window2Content({Key? key, required this.minWindowHeight, required this.account}) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
            const Text('Label'),
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
        DefaultTabController( // Second row with tab bar
          length: 3,
          child: Column(
            children: [
              const TabBar(             
                tabs: [
                  Tab(text: 'Setup'),
                  Tab(text: 'Practice'),
                  Tab(text: 'Strategy'),
                ],
              ),
              SizedBox(
                height: minWindowHeight * 0.8,
                child: const TabBarView(
                  children: [
                    Center(child: Text('Setup Content')),
                    Center(child: Text('Practice Content')),
                    Center(child: Text('Strategy Content')),
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