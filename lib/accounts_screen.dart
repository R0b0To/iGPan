import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart'; // Import secure storage
import 'main.dart'; // Import main.dart
import 'igp_client.dart'; // Import igp_client.dart for the Account class

class AccountsScreen extends StatefulWidget {
  const AccountsScreen({super.key});

  @override
  _AccountsScreenState createState() => _AccountsScreenState();
}

class _AccountsScreenState extends State<AccountsScreen> {
  List<Account> _accounts = [];
  final _storage = const FlutterSecureStorage(); // Create storage instance
  final String _accountsKey = 'accounts'; // Key for storing accounts

  @override
  void initState() {
    super.initState();
    _loadAccounts();
  }

  Future<void> _loadAccounts() async {
    try {
      final jsonString = await _storage.read(key: _accountsKey);
      if (jsonString != null) {
        setState(() {
          final List<dynamic> jsonList = jsonDecode(jsonString);
          _accounts = jsonList.map((json) => Account.fromJson(json)).toList();
        });
        //accountsNotifier.value = _accounts; // Update the ValueNotifier
      }
    } catch (e) {
      // Handle errors
      debugPrint('Error loading accounts: $e');
    }
  }

  Future<void> _saveAccounts() async {
    final jsonList = _accounts.map((account) => account.toJson()).toList();
    final jsonString = jsonEncode(jsonList);
    await _storage.write(key: _accountsKey, value: jsonString);
    //accountsNotifier.value = _accounts; // Update the ValueNotifier
  }

  Future<void> _addAccount() async {
    TextEditingController emailController = TextEditingController();
    TextEditingController passwordController = TextEditingController();
    TextEditingController nicknameController = TextEditingController();

    Account? addedAccount = await showDialog<Account>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Add Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              TextField(
                controller: nicknameController,
                decoration: const InputDecoration(labelText: 'Nickname (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                String email = emailController.text;
                String password = passwordController.text;
                String nickname = nicknameController.text;

                Account newAccount = Account(
                  email: email,
                  password: password,
                  nickname: nickname.isNotEmpty ? nickname : null,
                );
                setState(() {
                  _accounts.add(newAccount);
                });
                _saveAccounts();
                // Pass the new account back when popping
                Navigator.of(context).pop(newAccount);
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
    // Start session for the newly added account after the dialog is dismissed
    if (addedAccount != null) {
      startClientSessionForAccount(addedAccount);
    }
  }

  Future<void> _editAccount(int index) async {
    TextEditingController emailController = TextEditingController(text: _accounts[index].email);
    TextEditingController passwordController = TextEditingController(text: _accounts[index].password);
    TextEditingController nicknameController = TextEditingController(text: _accounts[index].nickname);

    Account? editedAccount = await showDialog<Account>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Edit Account'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              TextField(
                controller: passwordController,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              TextField(
                controller: nicknameController,
                decoration: const InputDecoration(labelText: 'Nickname (optional)'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                String email = emailController.text;
                String password = passwordController.text;
                String nickname = nicknameController.text;

                Account updatedAccount = Account(
                  email: email,
                  password: password,
                  nickname: nickname.isNotEmpty ? nickname : null,
                );
                setState(() {
                  _accounts[index] = updatedAccount;
                });
                _saveAccounts();
                // Pass the updated account back when popping
                Navigator.of(context).pop(updatedAccount);
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
    // Start session for the edited account after the dialog is dismissed
    if (editedAccount != null) {
      startClientSessionForAccount(editedAccount);
    }
  }

  Future<void> _deleteAccount(int index) async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Delete Account'),
          content: const Text('Are you sure you want to delete this account?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () {
                setState(() {
                  _accounts.removeAt(index);
                });
                _saveAccounts();
                Navigator.of(context).pop();
              },
              child: const Text('Delete'),
            ),
          ],
        );
      },
    );
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
            title: Text(account.email),
            subtitle: Text(account.nickname ?? ''),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    _editAccount(index);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete),
                  onPressed: () {
                    _deleteAccount(index);
                  },
                ),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addAccount,
        child: const Icon(Icons.add),
      ),
    );
  }
}
