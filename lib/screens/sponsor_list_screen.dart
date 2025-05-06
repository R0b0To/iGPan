import 'package:flutter/material.dart';
import '../igp_client.dart'; // Assuming Account is here
import '../services/sponsor_service.dart'; // Import the SponsorService

class SponsorListScreen extends StatefulWidget {
  final Account account;
  final int sponsorNumber; // Add sponsorNumber parameter

  const SponsorListScreen({super.key, required this.account, required this.sponsorNumber});

  @override
  _SponsorListScreenState createState() => _SponsorListScreenState();
}

class _SponsorListScreenState extends State<SponsorListScreen> {
  final SponsorService _sponsorService = SponsorService(); // Instantiate the service
  List<dynamic>? _sponsors;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _fetchSponsors();
  }

  Future<void> _fetchSponsors() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    try {
      // Pass the sponsorNumber to pickSponsor
      final Map<String, List<String>> data = await _sponsorService.pickSponsor(widget.account, widget.sponsorNumber); // Call method on service instance
      setState(() {
        // Transform the map into the list format expected by the UI
        _sponsors = [
          data['incomeList'] ?? [],
          data['bonusList'] ?? [],
          data['idList'] ?? [],
        ];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Failed to load sponsors: ${e.toString()}';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Available Sponsors'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _errorMessage != null
              ? Center(child: Text(_errorMessage!))
             : _sponsors == null || _sponsors!.length < 3 || (_sponsors![0] as List).isEmpty
                 ? const Center(child: Text('No sponsors available or data format incorrect.'))
                 : ListView.builder(
                     // Use the length of the first inner list (incomeList) as itemCount
                     itemCount: (_sponsors![0] as List).length,
                     itemBuilder: (context, index) {
                       // Extract data from the corresponding lists using the index
                       final List<dynamic> incomeList = _sponsors![0];
                       final List<dynamic> bonusList = _sponsors![1];
                       final List<dynamic> imageIdList = _sponsors![2];

                       // Basic validation to prevent index out of bounds
                       if (index >= incomeList.length || index >= bonusList.length || index >= imageIdList.length) {
                         return const SizedBox.shrink(); // Return empty widget if index is invalid
                       }

                       final String income = incomeList[index]?.toString() ?? 'N/A';
                       final String bonus = bonusList[index]?.toString() ?? 'N/A';
                       final String imageId = imageIdList[index]?.toString() ?? 'placeholder';
                       // Sponsor name is not directly available in this structure, using image ID as a placeholder name


                       return Card(
                         margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                         child: Padding(
                           padding: const EdgeInsets.all(8.0),
                           child: Row(
                             children: [
                               // Sponsor Image
                               Image.asset(
                                 'assets/sponsors/$imageId.png',
                                 width: 40,
                                 height: 40,
                                 errorBuilder: (context, error, stackTrace) {
                                   // Handle image loading errors
                                   return const Icon(Icons.monetization_on, size: 40); // Placeholder icon
                                 },
                               ),
                               const SizedBox(width: 16.0),
                               // Sponsor Details (Income, Bonus)
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text('Income: $income'),
                                     Text('Bonus: $bonus'),
                                   ],
                                 ),
                               ),
                               // Sign Button
                               ElevatedButton(
                                 onPressed: () async { // Make async
                                   try {
                                     // Await the saveSponsor call
                                     var result = await _sponsorService.saveSponsor(widget.account, widget.sponsorNumber, imageId, income, bonus); // Call method on service instance
                                     
                                     if (result != null && context.mounted) { // Check result and if widget is still mounted
                                       
                                       ScaffoldMessenger.of(context).showSnackBar(
                                         SnackBar(content: Text('Sponsor signed successfully (ID: $imageId)')), // Updated message
                                       );
                                       Navigator.pop(context, true); // Close the screen on success and return true
                                     } else if (context.mounted) {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                         SnackBar(content: Text('Failed to sign sponsor (ID: $imageId). API returned null.')),
                                       );
                                     }
                                   } catch (e, stackTrace) {
                                     debugPrint('Error signing sponsor: $e\n$stackTrace');
                                     if (context.mounted) {
                                       ScaffoldMessenger.of(context).showSnackBar(
                                         SnackBar(content: Text('Error signing sponsor: $e')),
                                       );
                                     }
                                   }
                                 },
                                 child: const Text('Sign'),
                               ),
                             ],
                           ),
                         ),
                       );
                     },
                   ),
   );
 }
}