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
  final _storage = const FlutterSecureStorage();
  final String _accountsKey = 'accounts';

  @override
  void initState() {
    super.initState();
  }



  Future<void> _saveAccounts() async {
    final jsonList = accountsNotifier.value.map((account) => account.toJson()).toList(); // Use accountsNotifier.value
    final jsonString = jsonEncode(jsonList);
    await _storage.write(key: _accountsKey, value: jsonString);
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
                // Update the ValueNotifier and notify listeners
                accountsNotifier.value = List.from(accountsNotifier.value)..add(newAccount);
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
      
     //notifier is updated on save accounts that triggers the main build that calls startSession
    }
  }

  Future<void> _editAccount(int index) async {
    // Use accountsNotifier.value to get the account
    TextEditingController emailController = TextEditingController(text: accountsNotifier.value[index].email);
    TextEditingController passwordController = TextEditingController(text: accountsNotifier.value[index].password);
    TextEditingController nicknameController = TextEditingController(text: accountsNotifier.value[index].nickname);

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
                // Update the ValueNotifier and notify listeners
                accountsNotifier.value = List.from(accountsNotifier.value)
                  ..[index] = updatedAccount;
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
      startClientSessionForAccount(editedAccount, onSuccess: () {
          if (mounted) {
            debugPrint('test account layout from accounts_screnn.dart');
            setState(() {});
          }
        });
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
                // Update the ValueNotifier and notify listeners
                accountsNotifier.value = List.from(accountsNotifier.value)..removeAt(index);
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
    // Use ValueListenableBuilder to react to changes in accountsNotifier
    return ValueListenableBuilder<List<Account>>(
      valueListenable: accountsNotifier,
      builder: (context, accounts, child) {
        return Scaffold(
          appBar: AppBar(
            title: const Text('Account Manager'),
          ),
          body: ListView.builder(
            itemCount: accounts.length, // Use the list from ValueNotifier
            itemBuilder: (context, index) {
              final account = accounts[index]; // Use the account from the ValueNotifier's list
              return ListTile(
                title: Text(account.email),
                subtitle: Text(account.nickname ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Add the Switch widget
                    Switch(
                      value: account.enabled,
                      onChanged: (bool value) {

                        setState(() {
                          account.enabled=value;
                        });
                        _saveAccounts();
                        // No need for setState here as ValueNotifier handles updates
                      },
                    ),
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
      },
    );
  }
}
