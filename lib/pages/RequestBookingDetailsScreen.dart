import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class RequestBookingDetailsScreen extends StatefulWidget {
  final String requestId;
  final String barberName;
  final String preferredDate;
  final String preferredTime;
  final String styleDescription;
  final String status;
  final double price;
  final String userId;

  const RequestBookingDetailsScreen({
    Key? key,
    required this.requestId,
    required this.barberName,
    required this.preferredDate,
    required this.preferredTime,
    required this.styleDescription,
    required this.status,
    required this.price,
    required this.userId,
  }) : super(key: key);

  @override
  _RequestBookingDetailsScreenState createState() => _RequestBookingDetailsScreenState();
}

class _RequestBookingDetailsScreenState extends State<RequestBookingDetailsScreen> {
  String? barberPhone;

  Color getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Colors.orange;
      case 'confirmed':
        return Colors.blue;
      case 'on the way':
        return Colors.indigo;
      case 'during':
        return Colors.teal;
      case 'complete':
        return Colors.green;
      case 'cancelled':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  @override
  void initState() {
    super.initState();
    fetchBarberPhone();
  }

  Future<void> fetchBarberPhone() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .where('name', isEqualTo: widget.barberName)
          .limit(1)
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final data = querySnapshot.docs.first.data();
        setState(() {
          barberPhone = data['phone'] ?? 'N/A';
        });
      } else {
        setState(() => barberPhone = 'N/A');
      }
    } catch (e) {
      setState(() => barberPhone = 'N/A');
    }
  }

  @override
  Widget build(BuildContext context) {
    final parsedDate = DateTime.tryParse(widget.preferredDate);
    final formattedRequestTime = parsedDate != null
        ? DateFormat('MMM d, y • h:mm a').format(parsedDate)
        : widget.preferredDate;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Detail"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: ListView(
          children: [
            Text('🧔 Barber Name:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(widget.barberName),
            const SizedBox(height: 8),

            Text('📞 Phone:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(barberPhone ?? 'Loading...'),
            const SizedBox(height: 8),

            Text('💇 Style Description:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(widget.styleDescription.isNotEmpty ? widget.styleDescription : 'No description provided.'),
            const SizedBox(height: 8),

            Text('🕓 Request Submitted:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(formattedRequestTime),
            const SizedBox(height: 8),

            Text('📅 Preferred Date:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(widget.preferredDate),
            const SizedBox(height: 8),

            Text('⏰ Preferred Time:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(widget.preferredTime),
            const SizedBox(height: 8),

            Text('💰 Price:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text('RM ${widget.price.toStringAsFixed(2)}'),
            const SizedBox(height: 8),

            Text('📌 Status:', style: TextStyle(fontWeight: FontWeight.bold)),
            Text(
              widget.status.toUpperCase(),
              style: TextStyle(
                color: getStatusColor(widget.status),
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
