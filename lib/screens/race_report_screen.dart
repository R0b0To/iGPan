import '../igp_client.dart'; // Import the IGP client (for Account model)
import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart'; // Import for CountryFlag
import '../screens/driver_report_screen.dart';

class RaceReportScreen extends StatefulWidget {
  final Map report;
  final Account account;

  const RaceReportScreen({required this.report, required this.account});

  @override
  _RaceReportScreenState createState() => _RaceReportScreenState();
}

class _RaceReportScreenState extends State<RaceReportScreen> {
  Map<dynamic, dynamic>? _reportInfo;
  bool _isLoading = true;
  late Account _account;
  @override
  void initState() {
    super.initState();
    _account = widget.account; // Initialize account from widget
    _fetchRaceReport();
  }

  Future<void> _fetchRaceReport() async {
    try {
      final reportData = await _account.requestRaceReport(widget.report['id']); // Call method on service instance
      setState(() {
        _reportInfo = reportData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching race report: $e');
      setState(() {
        _isLoading = false;
        _reportInfo = null; // Set reportInfo to null on error
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Loading Race Report...'),
        ),
        body: const Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (_reportInfo == null) {
      return Scaffold(
        appBar: AppBar(
          title: const Text('Error'),
        ),
        body: const Center(
          child: Text('Failed to load race report.'),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min, // Prevent Row from taking full width
          children: [
            // Ensure widget.report['track'] is not null and is a valid string before using it
            if (widget.report['track'] != null && widget.report['track'] is String && (widget.report['track'] as String).isNotEmpty)
              CountryFlag.fromCountryCode(
                widget.report['track'] as String, // Cast to String after check
                shape: const RoundedRectangle(6),
                width: 30, // Adjust size as needed
                height: 20, // Adjust size as needed
              ),
            // Add SizedBox only if the flag is displayed
            if (widget.report['track'] != null && widget.report['track'] is String && (widget.report['track'] as String).isNotEmpty)
              const SizedBox(width: 8), // Add some space between flag and text
            Text(widget.report['text'] ?? 'Race Report'),
          ],
        ),
        actions: [
          PopupMenuButton<String>(
            onSelected: (String result) {
              // TODO: Implement actions for popup menu options
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'option1',
                child: Text('Option 1'),
              ),
              const PopupMenuItem<String>(
                value: 'option2',
                child: Text('Option 2'),
              ),
              const PopupMenuItem<String>(
                value: 'option3',
                child: Text('Option 3'),
              ),
            ],
          ),
        ],
      ),
      body: Column(
        children: [
          // Row for race name (already in AppBar, can add here if needed elsewhere)
          // Row for popup button - REMOVED
          // Row for TabBar
          Expanded(
            child: DefaultTabController(
              initialIndex: 2,
              length: 3,
              child: Column(
                children: [
                  const TabBar(
                    tabs: [
                      Tab(text: 'Practice'),
                      Tab(text: 'Qualifying'),
                      Tab(text: 'Race'),
                    ],
                  ),
                  Expanded(
                    child: TabBarView(
                      children: [
                        // Practice Tab Content
                        _buildResultsList(context, _reportInfo?['practiceResults'] as List<dynamic>?, 'practice'),
                        // Qualifying Tab Content
                        _buildResultsList(context, _reportInfo?['qualifyingResults'] as List<dynamic>?, 'qualifying'),
                        // Race Tab Content
                        _buildResultsList(context, _reportInfo?['raceResults'] as List<dynamic>?, 'race'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper function to build the results list for each tab
  Widget _buildResultsList(BuildContext context, List<dynamic>? results, String type) {
    if (results == null || results.isEmpty) {
      String message = 'No results available.';
      if (type == 'practice') message = 'No practice results available.';
      if (type == 'qualifying') message = 'No qualifying results available.';
      if (type == 'race') message = 'No race results available.';
      return Center(child: Text(message));
    }

    return ListView.builder(
      itemCount: results.length,
      itemBuilder: (context, index) {
        final driverRow = results[index];
        final bool isMyTeam = driverRow['myTeam'] == true;

        String subtitleText = '';
        Widget? trailingWidget;

        if (type == 'race') {
          subtitleText = 'Time: ${driverRow['raceTime']} | Pits: ${driverRow['pits']}';
          // trailingWidget = Text('Pts: ${driverRow['points']}'); // Optional: Add points back if needed
        } else { // Practice or Qualifying
          if(index == 0)
          {
            subtitleText = '${driverRow['lapTime']}';
          }else{
            subtitleText = '${driverRow['gap']}';
          }
          
          final tyre = driverRow['tyre'];
          if (tyre != null && tyre.isNotEmpty) {
             // Assuming tyre images are named like 'S.png', 'M.png' etc. in assets/tyres/
            trailingWidget = Image.asset(
              'assets/tyres/_$tyre.png',
              height: 30, // Adjust size as needed
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.image_not_supported, size: 24), // Placeholder on error
            );
          }
        }

        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0), // Keep margin on Card
          color: isMyTeam ? Colors.lightBlueAccent.withOpacity(0.3) : null, // Keep color on Card
          child: InkWell( // Wrap ListTile with InkWell for tap effect
            onTap: (type == 'race' && driverRow['driverReportId'] != null && driverRow['driverReportId'].isNotEmpty)
              ? () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => DriverReportScreen(
                        account: _account, // Pass the account
                        report: widget.report, // Pass the original report for app bar info
                        driverReportId: driverRow['driverReportId'], // Pass the specific driver report ID
                      ),
                    ),
                  );
                }
              : null, // Disable onTap if conditions are not met
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: isMyTeam ? Theme.of(context).colorScheme.primaryContainer : Theme.of(context).colorScheme.secondaryContainer,
                child: Text('${index + 1}'), // Position
              ),
              title: Text('${driverRow['driver']} - ${driverRow['team']}'), // Driver/Team
              subtitle: Text(subtitleText),
              trailing: trailingWidget,
            ),
          ),
        );
      },
    );
  }
}