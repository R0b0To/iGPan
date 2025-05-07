import 'package:flutter/material.dart';
import 'package:country_flags/country_flags.dart';
import 'package:material_design_icons_flutter/material_design_icons_flutter.dart'; // Import MDI icons
import '../igp_client.dart'; // Import the IGP client (for Account model)
import '../utils/data_parsers.dart'; // Import data_parsers for tyre assets etc.
import '../services/history_service.dart'; // Import the HistoryService

class DriverReportScreen extends StatefulWidget {
  final Account account;
  final Map report; // Original race report for app bar info
  final String driverReportId;

  const DriverReportScreen({
    super.key,
    required this.account,
    required this.report,
    required this.driverReportId,
  });

  @override
  State<DriverReportScreen> createState() => _DriverReportScreenState();
}

class _DriverReportScreenState extends State<DriverReportScreen> {
  final HistoryService _historyService = HistoryService(); // Instantiate the service
  List<dynamic>? _driverReportData;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchDriverReport();
  }

  Future<void> _fetchDriverReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final reportData = await _historyService.requestDriverReport(widget.account, widget.driverReportId); // Call method on service instance
      setState(() {
        _driverReportData = reportData;
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error fetching driver report: $e');
      setState(() {
        _error = 'Failed to load driver report: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
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
            Expanded( // Allow text to wrap or truncate
              child: Text(
                widget.report['text'] ?? 'Driver Report',
                overflow: TextOverflow.ellipsis, // Handle long text
              ),
            ),
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
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    if (_driverReportData == null || _driverReportData!.isEmpty) {
      return const Center(child: Text('No driver report data available.'));
    }

    // TODO: Implement ListView builder here based on _driverReportData
    return ListView.builder(
      itemCount: _driverReportData!.length,
      itemBuilder: (context, index) {
        final item = _driverReportData![index];
        final bool isPitStop = item.containsKey('duration'); // Check if it's a pit stop

        if (isPitStop) {
          // Build Pit Stop Row
          return ListTile(
            tileColor: const Color.fromARGB(255, 41, 95, 70).withOpacity(0.2), // Highlight pit stops
            leading: Image.asset(
              getTyreAssetPath(item['tyre']), // Use helper for tyre asset
              height: 40,
              errorBuilder: (context, error, stackTrace) => const Icon(Icons.tire_repair, size: 24),
            ),
            title:  index==0?Text('Start') :Text('Pit Stop: ${item['duration']}'),
           
            // Add more details if needed
          );
        } else {
          // Build Lap Row
          return ListTile(
            leading: CircleAvatar(child: Text(item['lap'] ?? '?')),
            title: Text('Pos: ${item['pos']} | Gap: ${item['gap']}'), // Move Pos to title
            subtitle: Row( // Use a Row for wear and fuel
              children: [
                Container(
                  padding: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4.0),
                    color: item['tyreWear'] == null || item['tyreWear'] == '?'
                        ? Colors.grey.withOpacity(0.1) // Default color for null or '?'
                        : double.tryParse(item['tyreWear']) != null
                            ? Color.lerp(Colors.red.withOpacity(0.3), Colors.green.withOpacity(0.3), double.parse(item['tyreWear']) / 100.0) // Interpolate between green and red based on wear percentage
                            : Colors.grey.withOpacity(0.1), // Default color if parsing fails
                  ),
                  child: Text('Wear: ${item['tyreWear'] ?? '?'}'), // Extract text
                ),
                const SizedBox(width: 8.0), // Space between containers
                Container(
                  padding: const EdgeInsets.all(4.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey),
                    borderRadius: BorderRadius.circular(4.0),
                    color: item['fuel'] == null || item['fuel'] == '-'
                        ? Colors.grey.withOpacity(0.1) // Default color for null or '-'
                        : double.tryParse(item['fuel']) != null
                            ? Color.lerp(Colors.red.withOpacity(0.3), Colors.green.withOpacity(0.3), double.parse(item['fuel']) / 100.0) // Interpolate between red and green based on fuel percentage
                            : Colors.grey.withOpacity(0.1), // Default color if parsing fails
                  ),
                  child: Row( // Use a Row to place icon and text side-by-side
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(MdiIcons.gasStation, size: 16), // Fuel icon
                      const SizedBox(width: 4.0), // Space between icon and text
                      Text('${item['fuel'] ?? '?'}'), // Extract text
                    ],
                  ),
                ),
              ],
            ),
            // trailing: // Potentially show tyre wear/fuel icons here - already handled by the containers
          );
        }
      },
    );
  }
}