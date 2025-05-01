import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:path_provider/path_provider.dart'; // Import path_provider

import 'accounts_screen.dart';
import 'igp_client.dart'; 
import 'widgets/account_main_container.dart'; // Import the extracted widget
// Removed utils/helpers.dart import as it's not directly used here anymore

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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
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
    // Refresh data every 30 seconds
    //Timer.periodic(const Duration(seconds: 30), (timer) {_startClientSessions();});
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }


  Future<void> _loadAccounts() async {
    final directory = await getApplicationDocumentsDirectory();
    appDocumentPath = directory.path; // Set the appDocumentPath

    await loadAccounts(accountsNotifier);
    setState(() {
      _isLoading = false;
    });
    // Initial session start for all accounts after loading
    for (var account in accountsNotifier.value) {
      await startClientSessionForAccount(account);
    }
  }


  @override
  Widget build(BuildContext context) {
    //debugPrint('Current screen size: ${MediaQuery.of(context).size.width} x ${MediaQuery.of(context).size.height}');
    return Scaffold(

      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ValueListenableBuilder<List<Account>>( // Use specific type List<Account>
              valueListenable: accountsNotifier, // Use the imported notifier
              builder: (context, accounts, child) {
                // Ensure accounts list is not null before checking if empty
                if (accounts.isEmpty) {
                  // Handle null or empty case (e.g., show loading or message)
                  return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text('No accounts registered or still loading.'),
                            ElevatedButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AccountsScreen()),
                                );
                                //_loadAccounts();
                              },
                              child: const Text('Add Account'),
                            ),
                          ],
                        ),
                      );
                }
                // Build the main content based on the selected bottom navigation index
                return _buildMainContent(context, accounts);
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
            icon: Icon(Icons.people_outline),
            label: 'Home',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.settings),
            icon: Icon(Icons.settings_outlined),
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

  // Helper widget to build the main content area based on the bottom nav index
  Widget _buildMainContent(BuildContext context, List<Account> accounts) {
    switch (_bottomNavIndex) {
      case 0: // Accounts View
        return LayoutBuilder(
          builder: (context, constraints) {
            // Define minimum size for sub-windows
            const double minWindowWidth = 400;
            const double minWindowHeight = 240;

            // Check if there's enough horizontal space for two windows side-by-side
            bool canStackWindowsHorizontally = constraints.maxWidth >= (minWindowWidth * 2);

            if (canStackWindowsHorizontally) {
              // Wide screen: Paginated Vertical Stack (Horizontal PageView)
              const double estimatedItemHeight = minWindowHeight + 70; // Estimate height + padding
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
        );
      case 1: // Settings View
        // Navigate to AccountsScreen when Settings is tapped
        // Using WidgetsBinding to navigate after build to avoid issues during build phase
        WidgetsBinding.instance.addPostFrameCallback((_) {
          // Check if the widget is still mounted before navigating
          if (mounted) {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const AccountsScreen()),
            ).then((_) {
              // When returning from AccountsScreen, reload accounts and switch back to Accounts tab
              // Check if mounted again before calling setState
              if (mounted) {
                 //_loadAccounts();
                 setState(() {
                   _bottomNavIndex = 0;
                 });
              }
            });
          }
        });
        // Show a temporary loading indicator while navigating
        return const Center(child: CircularProgressIndicator(key: ValueKey('settings_loading')));
        // Alternative placeholder:
        // return const Center(child: Text('Settings Area - Navigating...'));
      case 2: // Actions View (Placeholder)
        // TODO: Implement Actions View
        return const Center(child: Text('Actions Area (Not Implemented)'));
      default: // Should not happen
        return const Center(child: Text('Error: Invalid selection'));
    }
  }
}


