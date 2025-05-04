import 'package:flutter/material.dart';
import 'package:iGPan/main.dart';
import 'window1_content.dart'; // Will create this file next
import 'window2_content.dart'; // Will create this file later
import '../igp_client.dart'; // Import Account definition
import 'package:auto_size_text/auto_size_text.dart';

class AccountMainContainer extends StatelessWidget {
  final Account account; // Use the specific Account type
  final double minWindowWidth;
  final double minWindowHeight;
  final bool canStackWindowsHorizontally;

  const AccountMainContainer({
    super.key,
    required this.account,
    required this.minWindowWidth,
    required this.minWindowHeight,
    required this.canStackWindowsHorizontally,
  });

  @override
  Widget build(BuildContext context) {
    // Check if fireUpData is available (assuming fireUpData is a property of Account)
    if (account.fireUpData == null) {
      startClientSessionForAccount(account, onSuccess: () {
          debugPrint('test account layout from account_main_container.dart');
          accountsNotifier.value = List.from(accountsNotifier.value);
        });
      
      // Provide a more informative placeholder or loading state
      return Card(
        margin: const EdgeInsets.all(8.0),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          height: canStackWindowsHorizontally ? minWindowHeight + 50 : (minWindowHeight * 2) + 60,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(account.nickname ?? account.email ?? 'Unnamed Account', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                const CircularProgressIndicator(),
                const SizedBox(height: 10),
                const Text('Loading data...'),
              ],
            ),
          ),
        ),
      );
    }


    double fontSize = minWindowWidth > 100 ? 24 : 18; // <<< Change font size based on width
    return Card(
        child: SafeArea(
          child: Column(
            children:[
            AutoSizeText(
        account.nickname ?? account.email ?? 'Unnamed Account',
        style: Theme.of(context).textTheme.titleLarge,
        maxLines: 1,        // Only 1 line, shrink font if needed
        minFontSize: 12,    // Don't go smaller than 12
        overflow: TextOverflow.ellipsis, // "..." if really needed
      ),

            _buildInternalWindows(context),
          ],)
        ),
      
    );
  }

  Widget _buildInternalWindows(BuildContext context) {
    // Create instances of the window content widgets once
    final window1Content = Window1Content(minWindowHeight: minWindowHeight+50, account: account);
    // Check if the account is in a league before creating Window2Content
    final bool isInLeague = account.fireUpData?['team']?['_league'] != null &&
                           account.fireUpData!['team']['_league'] != '0'; // Added null check for safety
    final window2Content = isInLeague ? Window2Content(minWindowHeight: minWindowHeight-50, account: account) : null;


     if (canStackWindowsHorizontally) {

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Align tops
          children: [
            Expanded(
              child: Container(
                child: window1Content,
              ),
            ),
            // Only add SizedBox and second window if it exists
            if (window2Content != null) ...[
              const SizedBox(width: 8.0),
              Expanded(
                child: Container(
                  child: window2Content,
                ),
              ),
            ] else // Add an empty Expanded to maintain layout if window2 is absent
              Expanded(child: SizedBox.shrink()),
          ],
        );
      } else {
        // Stack windows vertically
        return Column(
           mainAxisSize: MainAxisSize.min, // Ensure column takes minimum required height
           children: [
            Container(
              child: window1Content,
            ),
            // Only add SizedBox and second window if it exists
            if (window2Content != null) ...[
              Container(
                child: window2Content,
              ),
            ]
          ],
        );
      }
  }
}