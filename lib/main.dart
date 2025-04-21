import 'package:flutter/material.dart';
import 'accounts_screen.dart';
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';

final ValueNotifier<List<dynamic>> accountsNotifier = ValueNotifier<List<dynamic>>([]);

void main() {
  runApp(const MyApp());
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

  Future<void> _loadAccounts() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/accounts.json');
      final jsonString = await file.readAsString();
      accountsNotifier.value = jsonDecode(jsonString);
    } catch (e) {
      // Handle file not found or other errors
      print('Error loading accounts: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
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
                          const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: <Widget>[
                                Text('You have pushed the button this many times:'),
                                Text(
                                  '0',
                                  style: TextStyle(fontSize: 24),
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
