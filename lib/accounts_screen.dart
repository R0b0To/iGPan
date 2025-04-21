import 'dart:convert';
import 'dart:io';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path_provider/path_provider.dart';

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({Key? key}) : super(key: key);

  @override
  _AccountsScreenState createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<dynamic> _accounts = [];

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final file = File('c:/Users/Ghost/Documents/accounts.json');
      final jsonString = await file.readAsString();
      setState(() {
        _accounts = jsonDecode(jsonString);
      });
    } catch (e) {
      // Handle file not found or other errors
      print('Error loading accounts: \$e');
    }
  }

  Future<void> _saveAccounts() async {
    final directory = await getApplicationDocumentsDirectory();
    final file = File('${directory.path}/accounts.json');
    final jsonString = jsonEncode(_accounts);
    await file.writeAsString(jsonString);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Account Manager'),
      ),
      body: ListView.builder(
        itemCount: _accounts.length,
        itemBuilder: (context, index) {
          final account = _accounts[index];
          return ListTile(
            title: Text(account['username'] ?? ''),
            subtitle: Text(account['nickname'] ?? ''),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // Add account logic here
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}