import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BarberAppointmentDetailsPage extends StatefulWidget {
  const BarberAppointmentDetailsPage({Key? key}) : super(key: key);

  @override
  State<BarberAppointmentDetailsPage> createState() =>
      _BarberAppointmentDetailsPageState();
}

class _BarberAppointmentDetailsPageState
    extends State<BarberAppointmentDetailsPage> {
  late Map<String, dynamic> bookingData;
  String? selectedStatus;
  bool isUpdating = false;

  final List<String> statusOptions = [
    'pending',
    'confirmed',
    'on the way',
    'during',
    'complete',
    'cancelled',
  ];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    bookingData =
    ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    selectedStatus = bookingData['status'] ?? 'pending';
  }

  String formatDate(dynamic scheduledAt) {
    if (scheduledAt == null) return 'N/A';
    if (scheduledAt is DateTime) {
      return DateFormat('MMM d, y – h:mm a').format(scheduledAt);
    }
    if (scheduledAt is String) {
      try {
        final dt = DateTime.parse(scheduledAt);
        return DateFormat('MMM d, y – h:mm a').format(dt);
      } catch (_) {
        return 'Invalid date';
      }
    }
    if (scheduledAt is Timestamp) {
      return DateFormat('MMM d, y – h:mm a').format(scheduledAt.toDate());
    }
    return 'Invalid date';
  }

  Future<void> updateStatus(String newStatus) async {
    try {
      setState(() => isUpdating = true);

      await FirebaseFirestore.instance
          .collection('bookings')
          .doc(bookingData['id'])
          .update({'status': newStatus});

      // ✅ Send notification to user
      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': bookingData['userId'],
        'type': 'status_update',
        'title': 'Booking Status Updated',
        'message': 'Your booking is now "$newStatus".',
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
        'bookingId': bookingData['id'],
      });

      setState(() {
        selectedStatus = newStatus;
        bookingData['status'] = newStatus;
        isUpdating = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Status updated to "$newStatus"')),
      );
    } catch (e) {
      setState(() => isUpdating = false);
      print("Error updating status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error updating status')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = bookingData['services'] as List<dynamic>? ?? [];
    final scheduledAt = bookingData['scheduledAt'];
    final userId = bookingData['userId'];
    final totalPrice = bookingData['totalPrice'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Appointment Details'),
        backgroundColor: Colors.deepPurple,
      ),
      body: FutureBuilder<DocumentSnapshot>(
        future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
        builder: (context, snapshot) {
          String name = 'Unknown';
          String email = '-';
          String phone = '-';
          String? photoUrl;

          if (snapshot.hasData && snapshot.data!.exists) {
            final userData = snapshot.data!.data() as Map<String, dynamic>;
            name = userData['name'] ?? name;
            email = userData['email'] ?? email;
            phone = userData['phone'] ?? phone;
            photoUrl = userData['image']; // ✅ Correct field for profile picture
          }

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView(
              children: [
                const Text('Services:',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                ...services.map((s) {
                  return ListTile(
                    leading: const Icon(Icons.cut),
                    title: Text(s['type'] ?? 'Unknown'),
                    subtitle: Text('${s['duration']} min - RM ${s['price']}'),
                  );
                }).toList(),
                const Divider(height: 30),
                ListTile(
                  leading: const Icon(Icons.access_time),
                  title: const Text('Scheduled Time'),
                  subtitle: Text(formatDate(scheduledAt)),
                ),
                ListTile(
                  leading: const Icon(Icons.attach_money),
                  title: const Text('Total Price'),
                  subtitle: Text('RM $totalPrice'),
                ),
                const Divider(height: 30),
                const Text('User Info:',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : const AssetImage('assets/images/boy.jpg')
                      as ImageProvider,
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Name: $name',
                            style: const TextStyle(fontSize: 16)),
                        Text('Email: $email',
                            style: const TextStyle(fontSize: 16)),
                        Text('Phone: $phone',
                            style: const TextStyle(fontSize: 16)),
                      ],
                    )
                  ],
                ),
                const Divider(height: 30),
                const Text('Update Status:',
                    style:
                    TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                isUpdating
                    ? const Center(child: CircularProgressIndicator())
                    : DropdownButton<String>(
                  value: selectedStatus,
                  isExpanded: true,
                  items: statusOptions.map((status) {
                    return DropdownMenuItem(
                      value: status,
                      child: Text(status.toUpperCase()),
                    );
                  }).toList(),
                  onChanged: (value) {
                    if (value != null) updateStatus(value);
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
