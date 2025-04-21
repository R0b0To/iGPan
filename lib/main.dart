import 'package:flutter/material.dart';
import 'accounts_screen.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'package:http/http.dart' as http;
import 'package:cookie_jar/cookie_jar.dart';
import 'package:dio_cookie_manager/dio_cookie_manager.dart';
import 'package:dio/dio.dart';

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

  @override
  void initState() {
    super.initState();
     _loadAccounts();

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
                                  // Horizontal space is sufficient for windows side-by-side.
                                  // Stack main containers vertically.
                                  return ListView.builder(
                                    itemCount: accounts.length,
                                    itemBuilder: (context, index) {
                                      final account = accounts[index];
                                      return AccountMainContainer(
                                        account: account,
                                        minWindowWidth: minWindowWidth,
                                        minWindowHeight: minWindowHeight,
                                        canStackWindowsHorizontally: true, // Windows side-by-side
                                      );
                                    },
                                  );
                                } else {
                                  // Horizontal space is NOT sufficient for windows side-by-side.
                                  // Stack windows vertically.
                                  // Use a horizontal carousel for main containers.
                                  return PageView.builder(
                                    itemCount: accounts.length,
                                    itemBuilder: (context, index) {
                                      final account = accounts[index];
                                      return AccountMainContainer(
                                        account: account,
                                        minWindowWidth: minWindowWidth,
                                        minWindowHeight: minWindowHeight,
                                        canStackWindowsHorizontally: false, // Windows stacked vertically
                                      );
                                    },
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
    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              account['nickname'] ?? account['email'] ?? 'Unnamed Account',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8.0),
            LayoutBuilder(
              builder: (context, constraints) {
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
                          color: Colors.blue[100], // Placeholder color
                          child: const Center(child: Text('Window 1')),
                        ),
                      ),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Container(
                          constraints: BoxConstraints(
                            minWidth: minWindowWidth,
                            minHeight: minWindowHeight,
                          ),
                          color: Colors.green[100], // Placeholder color
                          child: const Center(child: Text('Window 2')),
                        ),
                      ),
                    ],
                  );
                } else {
                  // Stack windows vertically
                  return Column(
                    children: [
                      Container(
                        constraints: BoxConstraints(
                          minWidth: minWindowWidth,
                          minHeight: minWindowHeight,
                        ),
                        color: Colors.blue[100], // Placeholder color
                        child: const Center(child: Text('Window 1')),
                      ),
                      const SizedBox(height: 8.0),
                      Container(
                        constraints: BoxConstraints(
                          minWidth: minWindowWidth,
                          minHeight: minWindowHeight,
                        ),
                        color: Colors.green[100], // Placeholder color
                        child: const Center(child: Text('Window 2')),
                      ),
                    ],
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}
