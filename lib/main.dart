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

void initCookieManager() async {
  Directory appDocDir = await getApplicationDocumentsDirectory();
  String appDocPath = appDocDir.path;
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
        debugPrint('Accounts found: $accountsNotifier.value');
        for (var account in accountsNotifier.value) {
          final username = account['email'];
          final password = account['password'];
          if (username != null && password != null) {
            await _login(username, password);
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
      CookieJar cookieJar = cookieJars.putIfAbsent(username, () => CookieJar());
      Dio dio = dioClients.putIfAbsent(username, () {
        Dio newDio = Dio();
        newDio.interceptors.add(CookieManager(cookieJar));
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
        data: loginData,
      );
      debugPrint('Response for $username: ${response.data}');
      // Make the fireUp request
      final fireUpUrl = Uri.parse('https://igpmanager.com/index.php?action=fireUp&addon=igp&ajax=1&jsReply=fireUp&uwv=false&csrfName=&csrfToken=');
      try {
        final fireUpResponse = await dio.get(
          fireUpUrl.toString(),
        );
        final fireUpJson = jsonDecode(fireUpResponse.data);
        debugPrint('fireUp response for $username: ${fireUpJson['guestAccount']}');
      } catch (e) {
        debugPrint('Error making fireUp request for $username: $e');
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
                         
                        ],
                      );
              },
            ),
    );
  }
}
