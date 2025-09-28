import 'dart:async';
import 'package:flutter/material.dart';
import 'package:carousel_slider/carousel_slider.dart';
import 'package:path_provider/path_provider.dart'; // Import path_provider
import 'accounts_screen.dart';
import 'igp_client.dart';
import 'widgets/account_main_container.dart'; // Import the extracted widget
import 'screens/actions_screen.dart'; // Import the new ActionsScreen
// Removed utils/helpers.dart import as it's not directly used here anymore

// Define a ValueNotifier to hold the list of accounts
ValueNotifier<List<Account>> accountsNotifier = ValueNotifier([]);

void main() {
  WidgetsFlutterBinding.ensureInitialized(); // Ensure bindings are initialized
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
  int _currentPageIndex = 0; // Tracks the current page index for the wide-screen horizontal CarouselSlider.
  int _bottomNavIndex = 0; // Tracks the selected index of the BottomNavigationBar, determining which main view (Home, Accounts, Actions) is active.
  int _currentNarrowCarouselIndex = 0; // Tracks the current account card index for the narrow-screen horizontal CarouselSlider.
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


  // Asynchronously loads account data from storage when the widget is initialized.
  // It also sets the global `appDocumentPath` and updates `accountsNotifier`.
  Future<void> _loadAccounts() async {
    final directory = await getApplicationDocumentsDirectory();
    appDocumentPath = directory.path; // Set the appDocumentPath
    // Load accounts into the ValueNotifier
    await loadAccounts(); // Assuming loadAccounts populates the global 'accounts' list initially
    accountsNotifier.value = List.from(accounts); // Initialize the ValueNotifier with loaded accounts

    // Trigger data loading for enabled accounts immediately
    final enabledAccounts = accountsNotifier.value.where((account) => account.enabled).toList();
    for (var account in enabledAccounts) {
      // No need to await here, let them load concurrently
      startClientSessionForAccount(account, onSuccess: () {
        // Optionally update the UI if needed after each account loads
        // For now, just debug print
        debugPrint('Pre-loaded data for enabled account: ${account.email}');
        // This might trigger a rebuild of AccountMainContainer if it's listening to changes
        // accountsNotifier.value = List.from(accountsNotifier.value); // This would force a rebuild
      });
    }

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

                return IndexedStack(
                  index: _bottomNavIndex,
                  children: <Widget>[
                    // Index 0: Home View
                    Builder(
                      builder: (context) {
                        if (accounts.isEmpty) {
                          return Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                const Text('No accounts registered.'),
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
                          // Accounts exist, use LayoutBuilder to determine layout based on available screen width.
                          return LayoutBuilder(
                            builder: (context, constraints) {
                              // Define minimum size for individual account display containers.
                              const double minWindowWidth = 400;
                              const double minWindowHeight = 240;

                              // Condition for switching layouts:
                              // If the screen width can accommodate at least two 'minWindowWidth' containers side-by-side,
                              // use the wide-screen layout. Otherwise, use the narrow-screen layout.
                              bool canStackWindowsHorizontally = constraints.maxWidth >= (minWindowWidth * 2);

                              if (canStackWindowsHorizontally) {
                                // Wide-screen layout:
                                // Displays accounts in a paginated vertical stack. Each page is horizontally scrollable
                                // using a CarouselSlider. This allows multiple accounts to be visible at once if vertical space permits.
                                const double estimatedItemHeight = minWindowHeight + 70; // Estimate height per item + padding.
                                // Calculate how many items can fit vertically per page.
                                final itemsPerPage = (constraints.maxHeight / estimatedItemHeight).floor().clamp(1, enabledAccounts.length.clamp(1, enabledAccounts.length));
                                // Calculate the total number of horizontal pages needed.
                                final pageCount = (enabledAccounts.length / itemsPerPage).ceil();

                                if (enabledAccounts.isEmpty) {
                                  return const Center(child: Text('No enabled accounts to display. Manage accounts in the \'Accounts\' tab.'));
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
                                // Narrow-screen layout:
                                // Displays one account card at a time in a horizontally scrolling CarouselSlider.
                                // This is suitable for smaller screens where side-by-side display isn't feasible.
                                if (enabledAccounts.isEmpty) {
                                  return const Center(child: Text('No enabled accounts to display. Manage accounts in the \'Accounts\' tab.'));
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
                          );
                        }
                      },
                    ),
                    // Index 1: Accounts View
                    const AccountsScreen(),
                      // Index 2: Actions View
                    const ActionsScreen(),
                    ],
                  );
              },
            ),
       bottomNavigationBar: NavigationBar(
        height: 40,
         onDestinationSelected: (int index) {
           setState(() {
             _bottomNavIndex = index;

           });
         },
         selectedIndex: _bottomNavIndex,
          labelBehavior: NavigationDestinationLabelBehavior.onlyShowSelected,
         destinations: const <Widget>[
           NavigationDestination(
             selectedIcon: Icon(Icons.home),
             icon: Icon(Icons.home_outlined),
             label: '',
           ),
           NavigationDestination(
             selectedIcon: Icon(Icons.people),
             icon: Icon(Icons.people_outline),
             label: '',
           ),
           NavigationDestination(
             selectedIcon: Icon(Icons.play_circle_filled),
             icon: Icon(Icons.play_circle_outline),
             label: '',
           ),
         ],
       ),
     );
   }

 }
