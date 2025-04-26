import 'package:flutter/material.dart';
import '../igp_client.dart'; // Assuming pickSponsor and Account are here

class SponsorListScreen extends StatefulWidget {
  final Account account;
  final int sponsorNumber; // Add sponsorNumber parameter

  const SponsorListScreen({Key? key, required this.account, required this.sponsorNumber}) : super(key: key);

  @override
  _SponsorListScreenState createState() => _SponsorListScreenState();
}

class _SponsorListScreenState extends State<SponsorListScreen> {
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
      final data = await pickSponsor(widget.account, widget.sponsorNumber);
      setState(() {
        _sponsors = data;
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
                                 'assets/sponsors/$imageId',
                                 width: 50,
                                 height: 50,
                                 errorBuilder: (context, error, stackTrace) {
                                   // Handle image loading errors
                                   return const Icon(Icons.business, size: 50); // Placeholder icon
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
                                 onPressed: () {
                                   // TODO: Implement sign sponsor action using the imageId or index
                                   ScaffoldMessenger.of(context).showSnackBar(
                                     SnackBar(content: Text('Sign button pressed (ID: $imageId)')),
                                   );
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