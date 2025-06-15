import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BookingDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> bookingData;

  const BookingDetailsScreen({Key? key, required this.bookingData}) : super(key: key);

  @override
  _BookingDetailsScreenState createState() => _BookingDetailsScreenState();
}

class _BookingDetailsScreenState extends State<BookingDetailsScreen> {
  final TextEditingController _reviewController = TextEditingController();
  double _rating = 3.0;
  bool _isSubmitting = false;

  String formatDate(dynamic timestamp) {
    if (timestamp is Timestamp) {
      return DateFormat('MMM d, y – h:mm a').format(timestamp.toDate());
    }
    return 'Invalid date';
  }

  Color statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'on the way':
        return Colors.orange;
      case 'during':
        return Colors.blue;
      case 'complete':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> submitReview(String barberId) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() => _isSubmitting = true);

    await FirebaseFirestore.instance.collection('reviews').add({
      'userId': user.uid,
      'barberId': barberId,
      'rating': _rating,
      'comment': _reviewController.text,
      'timestamp': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Review submitted successfully!')),
    );

    setState(() {
      _reviewController.clear();
      _rating = 3.0;
      _isSubmitting = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final bookingId = widget.bookingData['id'];
    final barberId = widget.bookingData['barberId'];
    final services = List<Map<String, dynamic>>.from(widget.bookingData['services']);
    final scheduledAt = formatDate(widget.bookingData['scheduledAt']);

    return Scaffold(
      appBar: AppBar(title: Text('Booking Details')),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance.collection('bookings').doc(bookingId).snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator());

          final bookingSnapshot = snapshot.data!;
          final currentData = bookingSnapshot.data() as Map<String, dynamic>;

          final totalPrice = currentData['totalPrice'] ?? widget.bookingData['totalPrice'];
          final totalDuration = currentData['totalDuration'] ?? widget.bookingData['totalDuration'];
          final paymentMethod = currentData['paymentMethod'] ?? widget.bookingData['paymentMethod'];
          final status = currentData['status'] ?? 'confirmed';

          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: FutureBuilder<DocumentSnapshot>(
              future: FirebaseFirestore.instance.collection('users').doc(barberId).get(),
              builder: (context, snapshot) {
                final barberData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
                final barberName = barberData['name'] ?? 'Unknown Barber';
                final barberPhone = barberData['phone'] ?? 'N/A';

                return ListView(
                  children: [
                    Text('📅 Date & Time:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(scheduledAt),
                    const SizedBox(height: 16),

                    Text('💈 Services:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ...services.map((service) => ListTile(
                      title: Text(service['type']),
                      subtitle: Text('${service['duration']} min'),
                      trailing: Text('RM ${service['price']}'),
                    )),
                    const SizedBox(height: 16),

                    Text('💳 Payment Method:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(paymentMethod),
                    const SizedBox(height: 16),

                    Text('💰 Total:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('RM $totalPrice for $totalDuration mins'),
                    const SizedBox(height: 16),

                    Text('🧔 Barber Info:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Name: $barberName'),
                    Text('Phone: $barberPhone'),
                    const SizedBox(height: 16),

                    Text('📌 Current Status:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(
                      status.toUpperCase(),
                      style: TextStyle(
                        color: statusColor(status),
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 20),

                    if (status.toLowerCase() == 'complete') ...[
                      const Divider(),
                      Text('📝 Leave a Review:', style: TextStyle(fontWeight: FontWeight.bold)),
                      Slider(
                        value: _rating,
                        onChanged: (value) => setState(() => _rating = value),
                        min: 1,
                        max: 5,
                        divisions: 4,
                        label: _rating.toStringAsFixed(1),
                      ),
                      TextField(
                        controller: _reviewController,
                        maxLines: 3,
                        decoration: InputDecoration(
                          hintText: 'Write your review here...',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 10),
                      ElevatedButton(
                        onPressed: _isSubmitting ? null : () => submitReview(barberId),
                        child: _isSubmitting
                            ? CircularProgressIndicator(color: Colors.white)
                            : Text('Submit Review'),
                      ),
                    ]
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }
}
