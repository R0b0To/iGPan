import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:path_provider/path_provider.dart'; // Import path_provider

import 'accounts_screen.dart';
import 'igp_client.dart';
import 'widgets/account_main_container.dart'; // Import the extracted widget
// Removed utils/helpers.dart import as it's not directly used here anymore

// Define a ValueNotifier to hold the list of accounts
ValueNotifier<List<Account>> accountsNotifier = ValueNotifier([]);

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iGPan',
      themeMode: ThemeMode.system,
      darkTheme: ThemeData.dark(useMaterial3: true),
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color.fromARGB(255, 3, 146, 67)),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'iGPan'),
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
  int _bottomNavIndex = 0; // State for BottomNavigationBar
  int _currentNarrowCarouselIndex = 0; // State for narrow screen carousel
  final PageController _pageController = PageController();

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }


  Future<void> _loadAccounts() async {
    final directory = await getApplicationDocumentsDirectory();
    appDocumentPath = directory.path; // Set the appDocumentPath
    // Load accounts into the ValueNotifier
    await loadAccounts(); // Assuming loadAccounts populates the global 'accounts' list initially
    accountsNotifier.value = List.from(accounts); // Initialize the ValueNotifier with loaded accounts

    setState(() {
      _isLoading = false;
    });
    
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<List<Account>>( // Use ValueListenableBuilder
              valueListenable: accountsNotifier,
              builder: (context, accounts, child) {
                // Filter accounts to only include enabled ones for the Home view
                final enabledAccounts = accounts.where((account) => account.enabled).toList();

                if (accounts.isEmpty) { // Check the ValueNotifier's list
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        const Text('No accounts registered or still loading.'),
                        ElevatedButton(
                          onPressed: () {
                            // Switch to the Accounts tab directly
                            setState(() {
                              _bottomNavIndex = 1;
                            });
                          },
                          child: const Text('Add Account'),
                        ),
                      ],
                    ),
                  );
                } else {
                  return IndexedStack(
                    index: _bottomNavIndex,
                    children: <Widget>[
                      // Index 0: Home View (Existing LayoutBuilder content, using enabledAccounts)
                      LayoutBuilder(
                        builder: (context, constraints) {
                          // Define minimum size for sub-windows
                          const double minWindowWidth = 400;
                          const double minWindowHeight = 240;

                          // Check if there's enough horizontal space for two windows side-by-side
                          bool canStackWindowsHorizontally = constraints.maxWidth >= (minWindowWidth * 2);

                          if (canStackWindowsHorizontally) {
                            // Wide screen: Paginated Vertical Stack (Horizontal PageView)
                            const double estimatedItemHeight = minWindowHeight + 70; // Estimate height + padding
                            // Use enabledAccounts.length for itemsPerPage calculation
                            final itemsPerPage = (constraints.maxHeight / estimatedItemHeight).floor().clamp(1, enabledAccounts.length.clamp(1, enabledAccounts.length)); // Ensure at least 1, handle empty enabledAccounts
                            // Use enabledAccounts.length for pageCount calculation
                            final pageCount = (enabledAccounts.length / itemsPerPage).ceil();

                            // Handle case where there are no enabled accounts
                            if (enabledAccounts.isEmpty) {
                              return const Center(child: Text('No enabled accounts to display.'));
                            }

                            return Column(
                              mainAxisSize: MainAxisSize.max,
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
                                      final endIndex = (startIndex + itemsPerPage).clamp(0, enabledAccounts.length);

                                      return Column(
                                        mainAxisSize: MainAxisSize.max, // Take available space
                                        children: [
                                          for (int i = startIndex; i < endIndex; i++)
                                           AccountMainContainer(
                                             account: enabledAccounts[i], // Use enabledAccounts
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
                            // Use enabledAccounts.length for itemCount
                            if (enabledAccounts.isEmpty) {
                              return const Center(child: Text('No enabled accounts to display.'));
                            }
                            return Column(
                              mainAxisSize: MainAxisSize.max,
                              children: [
                                Expanded(
                                  child: CarouselSlider.builder(
                                    itemCount: enabledAccounts.length, // Use enabledAccounts
                                    options: CarouselOptions(
                                      scrollDirection: Axis.horizontal, // Make it horizontal
                                      viewportFraction: 1,
                                      enableInfiniteScroll: false,
                                      onPageChanged: (index, reason) {
                                        setState(() {
                                          _currentNarrowCarouselIndex = index;
                                        });
                                      },
                                      height: constraints.maxHeight,
                                    ),
                                    itemBuilder: (context, index, realIdx) {
                                      final account = enabledAccounts[index]; // Use enabledAccounts
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
                                  children: List.generate(enabledAccounts.length, (index) { // Use enabledAccounts
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
                      // Index 1: Accounts View
                      const AccountsScreen(),
                      // Index 2: Actions View (Placeholder)
                      const Center(child: Text('Actions Area (Not Implemented)')),
                    ],
                  );
                }
              },
            ),
       bottomNavigationBar: NavigationBar(
         onDestinationSelected: (int index) {
           setState(() {
             _bottomNavIndex = index;

           });
         },
         selectedIndex: _bottomNavIndex,
         destinations: const <Widget>[
           NavigationDestination(
             selectedIcon: Icon(Icons.home),
             icon: Icon(Icons.home_outlined),
             label: 'Home',
           ),
           NavigationDestination(
             selectedIcon: Icon(Icons.people),
             icon: Icon(Icons.people_outline),
             label: 'Accounts',
           ),
           NavigationDestination(
             selectedIcon: Icon(Icons.play_circle_filled),
             icon: Icon(Icons.play_circle_outline),
             label: 'Actions',
           ),
         ],
       ),
     );
   }

 }
