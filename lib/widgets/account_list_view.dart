import 'package:flutter/material.dart';
import '../igp_client.dart'; // Assuming Account is defined here or in a file imported by igp_client.dart
import 'account_main_container.dart';

class AccountListView extends StatelessWidget {
  final List<Account> accounts;
  final double minWindowWidth;
  final double minWindowHeight;
  final bool canStackWindowsHorizontally;

  const AccountListView({
    Key? key,
    required this.accounts,
    required this.minWindowWidth,
    required this.minWindowHeight,
    required this.canStackWindowsHorizontally,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.max, // Take available space
      children: [
        for (final account in accounts)
          AccountMainContainer(
            account: account,
            minWindowWidth: minWindowWidth,
            minWindowHeight: minWindowHeight,
            canStackWindowsHorizontally: canStackWindowsHorizontally,
          ),
      ],
    );
  }
}