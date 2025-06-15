import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminBookingManagementScreen extends StatefulWidget {
  const AdminBookingManagementScreen({super.key});

  @override
  State<AdminBookingManagementScreen> createState() => _AdminBookingManagementScreenState();
}

class _AdminBookingManagementScreenState extends State<AdminBookingManagementScreen> {
  List<Map<String, dynamic>> mergedBookings = [];
  List<Map<String, dynamic>> filteredBookings = [];
  String searchQuery = '';
  String statusFilter = 'all';

  Map<String, String> userIdToName = {};
  Map<String, String> barberIdToName = {};

  @override
  void initState() {
    super.initState();
    fetchUsersAndBarbers().then((_) => fetchAllBookings());
  }

  Future<void> fetchUsersAndBarbers() async {
    final userSnap = await FirebaseFirestore.instance.collection('users').get();
    for (var doc in userSnap.docs) {
      final data = doc.data();
      userIdToName[doc.id] = data['name'] ?? '';
    }
  }

  Future<void> fetchAllBookings() async {
    try {
      final bookingsSnap = await FirebaseFirestore.instance.collection('bookings').get();
      final requestSnap = await FirebaseFirestore.instance.collection('barberServiceRequests').get();

      List<Map<String, dynamic>> combined = [];

      for (var doc in bookingsSnap.docs) {
        final data = doc.data();
        combined.add({
          'id': doc.id,
          'source': 'bookings',
          'userName': userIdToName[data['userId']] ?? 'Unknown',
          'barberName': userIdToName[data['barberId']] ?? 'Unknown',
          'dateTime': data['scheduledAt']?.toDate(),
          'status': data['status'],
          'paymentMethod': data['paymentMethod'] ?? '',
          'services': data['services'] ?? [],
        });
      }

      for (var doc in requestSnap.docs) {
        final data = doc.data();
        combined.add({
          'id': doc.id,
          'source': 'barberServiceRequests',
          'userName': userIdToName[data['userId']] ?? 'Unknown',
          'barberName': userIdToName[data['barberId']] ?? 'Unknown',
          'dateTime': data['timestamp']?.toDate(),
          'status': data['status'],
          'styleDescription': data['styleDescription'] ?? '',
          'paymentMethod': 'N/A',
        });
      }

      combined.sort((a, b) => b['dateTime'].compareTo(a['dateTime']));

      setState(() {
        mergedBookings = combined;
        applyFilters();
      });
    } catch (e) {
      print('Error fetching: $e');
    }
  }

  void applyFilters() {
    setState(() {
      filteredBookings = mergedBookings.where((booking) {
        final nameMatch = booking['userName'].toLowerCase().contains(searchQuery) ||
            booking['barberName'].toLowerCase().contains(searchQuery) ||
            booking['id'].toLowerCase().contains(searchQuery);

        final statusMatch = (statusFilter == 'all') ||
            (booking['status']?.toLowerCase() == statusFilter.toLowerCase());

        return nameMatch && statusMatch;
      }).toList();
    });
  }

  void cancelBooking(String bookingId) {
    final reasonController = TextEditingController();
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Cancel Booking'),
        content: TextField(
          controller: reasonController,
          decoration: const InputDecoration(hintText: 'Reason for cancellation'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
          TextButton(
            onPressed: () async {
              final reason = reasonController.text.trim();
              if (reason.isNotEmpty) {
                await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({
                  'status': 'cancelled',
                  'cancelReason': reason,
                });
                Navigator.pop(context);
                fetchAllBookings();
              }
            },
            child: const Text('Confirm', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void viewBookingDetails(Map<String, dynamic> data) {
    final formattedDateTime = data['dateTime'] != null
        ? DateFormat('yyyy-MM-dd – kk:mm').format(data['dateTime'])
        : 'N/A';

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Booking Details'),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Booking ID: ${data['id']}'),
              Text('User: ${data['userName']}'),
              Text('Barber: ${data['barberName']}'),
              Text('Date: $formattedDateTime'),
              Text('Payment: ${data['paymentMethod']}'),
              Text('Status: ${data['status']}'),
              const SizedBox(height: 10),
              Text(data['source'] == 'barberServiceRequests'
                  ? 'Style: ${data['styleDescription']}'
                  : 'Services: ${(data['services'] as List).map((s) => s['type']).join(', ')}'),
            ],
          ),
        ),
        actions: [
          if ((data['status'] ?? '') == 'pending' && data['source'] == 'bookings')
            TextButton(
              onPressed: () => cancelBooking(data['id']),
              child: const Text('Cancel Booking', style: TextStyle(color: Colors.red)),
            ),
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(hintText: 'Search by name or ID'),
                    onChanged: (val) {
                      searchQuery = val.toLowerCase();
                      applyFilters();
                    },
                  ),
                ),
                const SizedBox(width: 8),
                DropdownButton<String>(
                  value: statusFilter,
                  items: const [
                    DropdownMenuItem(value: 'all', child: Text('All')),
                    DropdownMenuItem(value: 'pending', child: Text('Pending')),
                    DropdownMenuItem(value: 'confirmed', child: Text('Confirmed')),
                    DropdownMenuItem(value: 'cancelled', child: Text('Cancelled')),
                    DropdownMenuItem(value: 'complete', child: Text('Completed')),
                  ],
                  onChanged: (val) {
                    statusFilter = val!;
                    applyFilters();
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              itemCount: filteredBookings.length,
              itemBuilder: (context, index) {
                final data = filteredBookings[index];
                final formattedDateTime = data['dateTime'] != null
                    ? DateFormat('yyyy-MM-dd – kk:mm').format(data['dateTime'])
                    : 'N/A';

                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: ListTile(
                    onTap: () => viewBookingDetails(data),
                    title: Text('${data['userName']} → ${data['barberName']}'),
                    subtitle: Text('Date: $formattedDateTime\nStatus: ${data['status']}'),
                    trailing: const Icon(Icons.arrow_forward_ios, size: 16),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
