import 'package:flutter/material.dart';
import 'package:igpan/main.dart'; // Assuming dioClients is accessible via this
// import 'package:url_launcher/url_launcher.dart'; // No longer needed for external launch here

import '../screens/in_app_webview_screen.dart'; // Import the new screen (will create next)
import 'window1_content.dart';
import 'window2_content.dart';
import '../igp_client.dart'; // Import Account definition
import 'package:auto_size_text/auto_size_text.dart';

class AccountMainContainer extends StatefulWidget { // Changed to StatefulWidget
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
  State<AccountMainContainer> createState() => _AccountMainContainerState(); // Create state
}

class _AccountMainContainerState extends State<AccountMainContainer> { // State class
  bool _isLoadingData = false;

  @override
  void initState() {
    super.initState();
    if (widget.account.fireUpData == null) {
      _isLoadingData = true;
      _fetchAccountData();
    }
  }

  Future<void> _fetchAccountData() async {
    await startClientSessionForAccount(widget.account, onSuccess: () {
      if (mounted) {
        setState(() {
          _isLoadingData = false;
        });
      }
      // Assuming accountsNotifier and accounts are globally accessible or passed differently
      // For now, using the provided accountsNotifier directly.
      accountsNotifier.value = List.from(accountsNotifier.value);
      debugPrint('Account data loaded for ${widget.account.email}');
    });
    // If startClientSessionForAccount itself can fail or not call onSuccess,
    // ensure _isLoadingData is set to false in such error cases too.
    // For simplicity, assuming onSuccess is always called on completion for now.
    // If not, add error handling here and set _isLoadingData = false.
    if (mounted && widget.account.fireUpData == null) { // Handle case where data is still null after attempt
        setState(() {
            _isLoadingData = false; // Stop loading, but data might still be null
        });
        debugPrint('Failed to load account data for ${widget.account.email}');
    }
  }

  // Handles menu item selections
  void _handleMenuSelection(String value) async { // Make async for launchUrl
    print('Selected menu item: $value for account: ${widget.account.nickname ?? widget.account.email}');

    if (value == 'browser') {
      final Uri url = Uri.parse('https://igpmanager.com/app/');
      final dio = widget.account.dioClient; // Get the Dio instance for this account

      if (dio == null) {
         print('Error: Dio client not found for ${widget.account.email}');
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text('Could not find session data to open browser.')),
           );
         }
         return; // Stop if no dio instance
      }

      // Navigate to the new WebView screen
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => InAppWebViewScreen(
            initialUrl: url.toString(),
            dioInstance: dio, // Pass the specific Dio instance
            accountNickname: widget.account.nickname ?? widget.account.email,
          ),
        ),
      ).then((value) {
           startClientSessionForAccount(widget.account, onSuccess: () {
          debugPrint('reloaded account after webview session');
          accountsNotifier.value = List.from(accountsNotifier.value); // Assuming this handles state elsewhere
        });
      });
    }
  }

  List<PopupMenuEntry<String>> _buildMenuItems(BuildContext context) {
    // Build the list of menu items dynamically if needed
    return <PopupMenuEntry<String>>[

      const PopupMenuItem<String>(
        value: 'browser', // Keep existing
        child: Text('Open in Browser'),
      ),
      const PopupMenuItem<String>(
        value: 'league', // Keep existing
        child: Text('League Info'), // Slightly better text?
      ),
      // Add more PopupMenuItems here as needed
    ];
  }


  @override
  Widget build(BuildContext context) {
    if (_isLoadingData) {
      return Card(
        margin: const EdgeInsets.all(8.0),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          height: widget.canStackWindowsHorizontally ? widget.minWindowHeight + 50 : (widget.minWindowHeight * 2) + 60,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.account.nickname ?? widget.account.email ?? 'Unnamed Account', style: Theme.of(context).textTheme.titleLarge),
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

    if (widget.account.fireUpData == null && !_isLoadingData) {
      // Handle case where loading finished but data is still null (e.g., error)
      return Card(
        margin: const EdgeInsets.all(8.0),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          height: widget.canStackWindowsHorizontally ? widget.minWindowHeight + 50 : (widget.minWindowHeight * 2) + 60,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(widget.account.nickname ?? widget.account.email ?? 'Unnamed Account', style: Theme.of(context).textTheme.titleLarge),
                const SizedBox(height: 10),
                const Icon(Icons.error_outline, color: Colors.red, size: 48),
                const SizedBox(height: 10),
                const Text('Failed to load account data.'),
                ElevatedButton(onPressed: _fetchAccountData, child: const Text('Retry'))
              ],
            ),
          ),
        ),
      );
    }
    
    // Data is loaded and available
    double fontSize = widget.minWindowWidth > 100 ? 24 : 18; // <<< Change font size based on width
    return Card(
        child: SafeArea(
          child: Column(
            children:[
            Padding( // Add some padding around the Row
              padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
              
              child: Row(
                children: [
                  Expanded( // Make text take available space
                    child: AutoSizeText(
                      widget.account.nickname ?? widget.account.email ?? 'Unnamed Account',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(fontSize: fontSize), // Apply dynamic font size
                      maxLines: 1,        // Only 1 line, shrink font if needed
                      minFontSize: 12,    // Don't go smaller than 12
                      overflow: TextOverflow.ellipsis, // "..." if really needed
                    ),
                  ),
                  PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert), // Standard menu icon
                    onSelected: _handleMenuSelection, // Now defined in state
                    itemBuilder: _buildMenuItems,      // Now defined in state
                    tooltip: 'Account Options', // Add tooltip for accessibility
                  ),
                ],
              ),
            ),
            _buildInternalWindows(context), // Call helper method from state
          ],)
        ),

    );
  }

  // Moved helper method into the state class
  Widget _buildInternalWindows(BuildContext context) {
    // Access properties using widget.
    final window1Content = Window1Content(minWindowHeight: widget.minWindowHeight+50, account: widget.account);
    final bool isInLeague = widget.account.fireUpData?['team']?['_league'] != null &&
                           widget.account.fireUpData!['team']['_league'] != '0';
    final window2Content = isInLeague ? Window2Content(minWindowHeight: widget.minWindowHeight-50, account: widget.account) : null;


     if (widget.canStackWindowsHorizontally) {

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start, // Align tops
          children: [
            Expanded(
              child: Container(
                margin: const EdgeInsets.all(4.0),
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color:Colors.lightGreenAccent.shade700,
                      blurRadius: 2,
                     
                    ),
                  ],
                ),
                child: window1Content,
              ),
            ),
            if (window2Content != null) ...[
              const SizedBox(width: 8.0),
              Expanded(
                child: Container(
                  margin: const EdgeInsets.all(4.0),
                  padding: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(8.0),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.blueAccent.shade700,
                        blurRadius: 2,
                       
                      ),
                    ],
                  ),
                  child: window2Content,
                ),
              ),
            ] else
              Expanded(child: SizedBox.shrink()),
          ],
        );
      } else {
        return Column(
           mainAxisSize: MainAxisSize.min,
           children: [
            Container(
              margin: const EdgeInsets.all(4.0),
              padding: const EdgeInsets.all(4.0),
              decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.lightGreenAccent.shade700,
                    blurRadius: 2,
                  ),
                ],
              ),
              child: window1Content,
            ),
            if (window2Content != null) ...[
              Container(
                margin: const EdgeInsets.all(4.0),
                padding: const EdgeInsets.all(4.0),
                decoration: BoxDecoration(
                  color: Theme.of(context).cardColor,
                  borderRadius: BorderRadius.circular(8.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blueAccent.shade700,
                      blurRadius: 2,
                    
                    ),
                  ],
                ),
                child: window2Content,
              ),
            ]
          ],
        );
      }
  }
}