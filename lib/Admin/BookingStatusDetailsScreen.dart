import 'package:flutter/material.dart';

class BookingStatusDetailsScreen extends StatelessWidget {
  final String status;
  final List<Map<String, dynamic>> bookingRecords;

  const BookingStatusDetailsScreen({
    super.key,
    required this.status,
    required this.bookingRecords,
  });

  @override
  Widget build(BuildContext context) {
    final filtered = bookingRecords.where((b) => b['status'] == status).toList();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Bookings: ${status[0].toUpperCase()}${status.substring(1)}',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: filtered.isEmpty
          ? const Center(child: Text("No bookings with this status."))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: filtered.length,
        itemBuilder: (context, index) {
          final record = filtered[index];
          return Card(
            elevation: 3,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Date: ${record['date']}", style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("User: ${record['userName']} (${record['userPhone']})"),
                  Text("Barber: ${record['barberName']} (${record['barberPhone']})"),
                  const SizedBox(height: 4),
                  Text("Status: ${status[0].toUpperCase()}${status.substring(1)}",
                      style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
