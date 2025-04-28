import 'package:flutter/material.dart';
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
    Key? key,
    required this.account,
    required this.minWindowWidth,
    required this.minWindowHeight,
    required this.canStackWindowsHorizontally,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Check if fireUpData is available (assuming fireUpData is a property of Account)
    if (account.fireUpData == null) {
      debugPrint('Account data is null or not loaded yet for ${account.nickname ?? account.email}.');
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

    // Estimate height based on internal layout
    // Add some padding/margin allowance
    // final estimatedHeight = canStackWindowsHorizontally
    //     ? minWindowHeight + 50 // Approx height when windows are horizontal
    //     : (minWindowHeight * 2) + 60; // Approx height when windows are vertical
        // Let the content determine the height using MainAxisSize.min
    double fontSize = minWindowWidth > 100 ? 24 : 18; // <<< Change font size based on width
    return Card(
      margin: const EdgeInsets.all(2),
      child: Container( // Use Container to constrain height if needed, though Card might handle it

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min, // Important for Column height in ListView/PageView
          children: [
            AutoSizeText(
        account.nickname ?? account.email ?? 'Unnamed Account',
        style: Theme.of(context).textTheme.titleLarge,
        maxLines: 1,        // Only 1 line, shrink font if needed
        minFontSize: 12,    // Don't go smaller than 12
        overflow: TextOverflow.ellipsis, // "..." if really needed
      ),
            // Use Flexible or Expanded if windows need to fill space,
            // but for fixed min size, direct Container might be okay.
            _buildInternalWindows(context),
          ],
        ),
      ),
    );
  }

  Widget _buildInternalWindows(BuildContext context) {
    // Create instances of the window content widgets once
    final window1Content = Window1Content(minWindowHeight: minWindowHeight, account: account);
    // Check if the account is in a league before creating Window2Content
    final bool isInLeague = account.fireUpData?['team']?['_league'] != null &&
                           account.fireUpData!['team']['_league'] != '0'; // Added null check for safety
    final window2Content = isInLeague ? Window2Content(minWindowHeight: minWindowHeight-50, account: account) : null;


     if (canStackWindowsHorizontally) {
        // Stack windows horizontally
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Align tops
          children: [
            Expanded(
              child: Container(
                constraints: BoxConstraints(
                  minWidth: minWindowWidth,
                  minHeight: minWindowHeight,
                ),
                // color: const Color.fromARGB(255, 96, 121, 141), // Remove placeholder color
                child: window1Content,
              ),
            ),
            // Only add SizedBox and second window if it exists
            if (window2Content != null) ...[
              const SizedBox(width: 8.0),
              Expanded(
                child: Container(
                  constraints: BoxConstraints(
                    minWidth: minWindowWidth,
                    minHeight: minWindowHeight,
                  ),
                  // color: const Color.fromARGB(255, 98, 121, 99), // Remove placeholder color
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
              constraints: BoxConstraints(
                minWidth: double.infinity, // Take full width available
                minHeight: minWindowHeight,
              ),
              // color: const Color.fromARGB(255, 93, 108, 121), // Remove placeholder color
              child: window1Content,
            ),
            // Only add SizedBox and second window if it exists
            if (window2Content != null) ...[

              Container(
                constraints: BoxConstraints(
                   minWidth: double.infinity, // Take full width available
                   minHeight: minWindowHeight,
                ),
                // color: const Color.fromARGB(255, 111, 133, 112), // Remove placeholder color
                child: window2Content,
              ),
            ]
          ],
        );
      }
  }
}