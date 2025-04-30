import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';

import 'accounts_screen.dart';
import 'igp_client.dart'; // Import for Account, client functions, and accountsNotifier
import 'widgets/account_main_container.dart'; // Import the extracted widget
// Removed utils/helpers.dart import as it's not directly used here anymore

void main() {
  runApp(const MyApp());
  initCookieManager(); // Assuming this is defined in igp_client.dart or similar
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
                                _loadAccounts();
                              },
                              child: const Text('Add Account'),
                            ),
                          ],
                        ),
                      );
                }
                // Proceed with building the layout if accounts list is valid
                return accounts.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: <Widget>[
                            const Text('No accounts registered.'),
                            ElevatedButton(
                              onPressed: () async {
                                await Navigator.push(
                                  context,
                                  MaterialPageRoute(builder: (context) => const AccountsScreen()),
                                );
                                _loadAccounts();
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
                                      onPressed: () async {
                                        await Navigator.push(
                                          context,
                                          MaterialPageRoute(builder: (context) => const AccountsScreen()),
                                        );
                                        _loadAccounts();
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
                            ),
                          ),
                        ],
                      );
              },
            ),
    );
  }
}

// AccountMainContainer class removed (moved to widgets/account_main_container.dart)

// Window1Content class removed (moved to widgets/window1_content.dart)

// abbreviateNumber function removed (moved to utils/helpers.dart)

// Window2Content class removed (moved to widgets/window2_content.dart)

// SetupContent class removed (moved to widgets/window2_content.dart)

// StrategyContent class removed (moved to widgets/window2_content.dart)
