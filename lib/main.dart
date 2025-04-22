import 'package:flutter/material.dart';
import 'accounts_screen.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio/dio.dart';
import 'package:carousel_slider/carousel_slider.dart';

final ValueNotifier<List<dynamic>> accountsNotifier = ValueNotifier<List<dynamic>>([]);
final Map<String, CookieJar> cookieJars = {};
final Map<String, Dio> dioClients = {};

void main() {
  runApp(const MyApp());
  initCookieManager();
}

String? appDocumentPath;

void initCookieManager() async {
  Directory appDocDir = await getApplicationDocumentsDirectory();
  appDocumentPath = appDocDir.path;
  // dio.interceptors.add(CookieManager(cookieJar)); // Remove global cookie manager
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
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    setState(() {
    _isLoading = false;
  });
    _startClientSessions();
}

  Future<void> _loadAccounts() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/accounts.json');
      final jsonString = await file.readAsString();
      accountsNotifier.value = jsonDecode(jsonString);
      debugPrint('Accounts loaded: ${accountsNotifier.value}');

      // Initialize persistent cookie jars for each account
      if (appDocumentPath != null) {
        for (var account in accountsNotifier.value) {
          final username = account['email'];
          if (username != null) {
            cookieJars[username] = PersistCookieJar(
              storage: FileStorage('$appDocumentPath/.cookies/$username/'),
            );
          }
        }
      }

    } catch (e) {
      // Handle file not found or other errors
      debugPrint('Error loading accounts: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
      final accounts = accountsNotifier.value;
      debugPrint('starting client sessions... $accounts');
      if (accountsNotifier.value.isNotEmpty) {
        debugPrint('Accounts found: ${accountsNotifier.value}');
        for (var account in accountsNotifier.value) {
          final username = account['email'];
          final password = account['password'];
          if (username != null && password != null) {
            // Attempt to use existing cookies first by making the fireUp request
            bool sessionValid = false;
            try {
              CookieJar? cookieJar = cookieJars[username];
               if (cookieJar != null) {
                Dio dio = dioClients.putIfAbsent(username, () {
                  Dio newDio = Dio();
                  newDio.interceptors.add(CookieManager(cookieJar!));
                  return newDio;
                });
                final fireUpUrl = Uri.parse('https://igpmanager.com/index.php?action=fireUp&addon=igp&ajax=1&jsReply=fireUp&uwv=false&csrfName=&csrfToken=');
                final fireUpResponse = await dio.get(fireUpUrl.toString());
                final fireUpJson = jsonDecode(fireUpResponse.data);

                if (fireUpJson != null && fireUpJson['guestAccount'] == false) {
                  debugPrint('Session is valid for $username using saved cookies.');
                  sessionValid = true;
                } else {
                   debugPrint('Session invalid for $username based on fireUp response.');
                }
               }
            } catch (e) {
              debugPrint('Error during initial fireUp request for $username: $e. Session likely invalid.');
              // Error likely means session is not valid
            }

            if (!sessionValid) {
              debugPrint('Attempting full login for $username.');
              await _login(username, password);
            }

          } else {
            debugPrint('Username or password missing for account: $account');
          }
        }
      }
    }
  }

  Future<void> _startClientSessions() async {
    if (accountsNotifier.value.isNotEmpty) {
      for (var account in accountsNotifier.value) {
        final username = account['username'];
        final password = account['password'];
        if (username != null && password != null) {
          await _login(username, password);
        } else {
          debugPrint('Username or password missing for account: $account');
        }
      }
    }
  }

  Future<void> _login(String username, String password) async {
      CookieJar? cookieJar = cookieJars[username];
      if (cookieJar == null) {
        debugPrint('No persistent cookie jar found for $username. Creating a new one.');
        // Fallback to a non-persistent cookie jar if persistent storage is not available
        cookieJar = CookieJar();
        cookieJars[username] = cookieJar; // Store it for potential future use (though not persistent)
      }

      Dio dio = dioClients.putIfAbsent(username, () {
        Dio newDio = Dio();
        newDio.interceptors.add(CookieManager(cookieJar!));
        return newDio;
      });
      final url = Uri.parse('https://igpmanager.com/index.php?action=send&addon=igp&type=login&jsReply=login&ajax=1');
      final loginData = {
        'loginUsername': username,
        'loginPassword': password,
      'loginRemember': 'on',
      'csrfName': '',
      'csrfToken': ''
    };
    try {
      final response = await dio.post(
        url.toString(),
        data: FormData.fromMap(loginData),
      );
      debugPrint('Response for $username: ${response.data}');
      final loginResponseJson = jsonDecode(response.data);

      if (loginResponseJson != null && loginResponseJson['status'] == 1) {
        debugPrint('Login successful for $username');
        // Make the fireUp request
        final fireUpUrl = Uri.parse('https://igpmanager.com/index.php?action=fireUp&addon=igp&ajax=1&jsReply=fireUp&uwv=false&csrfName=&csrfToken=');
        try {
          final fireUpResponse = await dio.get(
            fireUpUrl.toString(),
          );
          final fireUpJson = jsonDecode(fireUpResponse.data);
          debugPrint('is $username a guest? ${fireUpJson['guestAccount']}');
        } catch (e) {
          debugPrint('Error making fireUp request for $username: $e');
        }
      } else {
        debugPrint('Login failed for $username. Response: ${response.data}');
        // Handle failed login, e.g., show an error message to the user
      }
    } catch (e) {
      debugPrint('Error logging in $username: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
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
              account['nickname'] ?? account['email'] ?? 'Unnamed Account',
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
                child: Column(
                  children: [
                    Row( // First row with buttons and label - Compacted
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly, // Align start
                      children: [
                        SizedBox( // Wrap button for size control
                          
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero, // Remove padding
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Square corners
                            ),
                            child: const Text('Money', style: TextStyle(fontSize: 10)), // Shorter text
                          ),
                        ),
                        
                        const Text('Tokens: 100'), // Keep text as is for now
                        const SizedBox(width: 4), // Small spacer
                        SizedBox( // Wrap button for size control
      
                          child: ElevatedButton(
                            onPressed: () {},
                            style: ElevatedButton.styleFrom(
                              padding: EdgeInsets.zero, // Remove padding
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.zero), // Square corners
                            ),
                            child: const Text('Daily', style: TextStyle(fontSize: 10)), // Shorter text
                          ),
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
                            const SizedBox(height: 2), // Small vertical space
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
                ),
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
                child: const Center(child: Text('Window 2')),
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
              child: const Center(child: Text('Window 1')),
            ),
            const SizedBox(height: 8.0),
            Container(
              constraints: BoxConstraints(
                 minWidth: minWindowWidth, // Should be maxWidth of parent?
                 minHeight: minWindowHeight,
              ),
              color: const Color.fromARGB(255, 111, 133, 112), // Placeholder color
              child: const Center(child: Text('Window 2')),
            ),
          ],
        );
      }
  }
}

class VerticalAccountStack extends StatelessWidget {
  final List<Widget> accounts;
  final double maxHeight;

  const VerticalAccountStack({Key? key, required this.accounts, required this.maxHeight}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: maxHeight,
      child: SingleChildScrollView( // Enable scrolling if content overflows
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: accounts,
        ),
      ),
    );
  }
}

