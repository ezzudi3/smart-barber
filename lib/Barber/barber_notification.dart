import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:barberapp1/Barber/RequestDetailScreen.dart';
import 'package:barberapp1/Barber/barber_appointment_detail.dart';

class BarberNotificationsScreen extends StatelessWidget {
  const BarberNotificationsScreen({Key? key}) : super(key: key);

  String formatTimestamp(Timestamp? timestamp) {
    if (timestamp == null) return 'Unknown time';
    return DateFormat('MMM d, y • h:mm a').format(timestamp.toDate());
  }

  Future<void> markAsRead(String docId) async {
    await FirebaseFirestore.instance.collection('notifications').doc(docId).update({
      'isRead': true,
    });
  }

  Future<void> openAppointmentDetails(BuildContext context, String bookingId) async {
    final bookingSnapshot =
    await FirebaseFirestore.instance.collection('bookings').doc(bookingId).get();

    if (bookingSnapshot.exists) {
      final bookingData = bookingSnapshot.data()!..['id'] = bookingId;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const BarberAppointmentDetailsPage(),
          settings: RouteSettings(arguments: bookingData),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Booking no longer exists.')),
      );
    }
  }

  Future<void> openRequestDetails(BuildContext context, String requestId) async {
    final requestSnapshot =
    await FirebaseFirestore.instance.collection('barberServiceRequests').doc(requestId).get();

    if (requestSnapshot.exists) {
      final requestData = requestSnapshot.data()!..['id'] = requestId;

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => const RequestDetailScreen(),
          settings: RouteSettings(arguments: requestData),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request no longer exists.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final barberId = FirebaseAuth.instance.currentUser!.uid;

    final notificationsStream = FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: barberId)
        .orderBy('timestamp', descending: true)
        .snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: notificationsStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }

          final notifications = snapshot.data!.docs;

          return ListView.builder(
            itemCount: notifications.length,
            itemBuilder: (context, index) {
              final doc = notifications[index];
              final data = doc.data() as Map<String, dynamic>;
              final title = data['title'] ?? 'Notification';
              final message = data['message'] ?? '';
              final timestamp = data['timestamp'] as Timestamp?;
              final isRead = data['isRead'] == true;
              final type = data['type'];
              final bookingId = data['bookingId'];
              final requestId = data['requestId'];

              return InkWell(
                onTap: () async {
                  await markAsRead(doc.id);
                  if (type == 'booking' && bookingId != null) {
                    openAppointmentDetails(context, bookingId);
                  } else if (type == 'service_request' && requestId != null) {
                    openRequestDetails(context, requestId);
                  }
                },
                child: ListTile(
                  leading: Icon(Icons.notifications, color: isRead ? Colors.grey : Colors.deepPurple),
                  title: Text(
                    title,
                    style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold),
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(message),
                      const SizedBox(height: 4),
                      Text(formatTimestamp(timestamp), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  tileColor: isRead ? Colors.grey[100] : Colors.deepPurple.shade50,
                ),
              );
            },
          );
        },
      ),
    );
  }
}
