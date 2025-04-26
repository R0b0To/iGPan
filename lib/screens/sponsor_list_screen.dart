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
              : _sponsors == null || _sponsors!.isEmpty
                  ? const Center(child: Text('No sponsors available.'))
                  : ListView.builder(
                      itemCount: _sponsors!.length,
                      itemBuilder: (context, index) {
                        final sponsor = _sponsors![index];
                        // Assuming sponsor is a List or Map with structure [id, name, image_id, income, bonus, ...]
                        // Based on user description "sponsorlist[2] is the id/name of the png image"
                        // Let's assume sponsor is a List and index 2 is the image ID, index 3 is income, index 4 is bonus
                        // This might need adjustment based on the actual pickSponsor response structure.
                        final String imageId = sponsor.length > 2 ? sponsor[2].toString() : 'placeholder'; // Use a default if index 2 is missing
                        final String income = sponsor.length > 3 ? sponsor[3].toString() : 'N/A';
                        final String bonus = sponsor.length > 4 ? sponsor[4].toString() : 'N/A';
                        final String sponsorName = sponsor.length > 1 ? sponsor[1].toString() : 'Unnamed Sponsor';


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
                                      Text(sponsorName, style: Theme.of(context).textTheme.titleMedium),
                                      Text('Income: $income'),
                                      Text('Bonus: $bonus'),
                                    ],
                                  ),
                                ),
                                // Sign Button
                                ElevatedButton(
                                  onPressed: () {
                                    // TODO: Implement sign sponsor action
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(content: Text('Sign button pressed for $sponsorName')),
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