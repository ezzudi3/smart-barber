import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class BookingStep4Complete extends StatefulWidget {
  final String barberId;
  final List<Map<String, dynamic>> selectedServices;
  final double totalPrice;
  final int totalDuration;
  final DateTime selectedDateTime;
  final String paymentMethod;

  const BookingStep4Complete({
    Key? key,
    required this.barberId,
    required this.selectedServices,
    required this.totalPrice,
    required this.totalDuration,
    required this.selectedDateTime,
    required this.paymentMethod,
  }) : super(key: key);

  @override
  State<BookingStep4Complete> createState() => _BookingStep4CompleteState();
}

class _BookingStep4CompleteState extends State<BookingStep4Complete> {
  bool isSaving = true;
  String? barberPhone;

  @override
  void initState() {
    super.initState();
    fetchBarberPhone();
    saveBookingToFirestore();
  }

  Future<void> fetchBarberPhone() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.barberId).get();
      if (doc.exists) {
        setState(() {
          barberPhone = doc.data()?['phone'];
        });
      }
    } catch (e) {
      print("❌ Failed to fetch barber phone: $e");
    }
  }

  Future<bool> isSlotAvailable(DateTime start, DateTime end) async {
    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('barberId', isEqualTo: widget.barberId)
        .where('scheduledAt', isLessThan: Timestamp.fromDate(end))
        .get();

    for (var doc in snapshot.docs) {
      final bookedStart = (doc['scheduledAt'] as Timestamp).toDate();
      final bookedEnd = (doc['estimatedEndAt'] as Timestamp?)?.toDate() ??
          bookedStart.add(Duration(minutes: doc['totalDuration']));
      if (start.isBefore(bookedEnd) && end.isAfter(bookedStart)) {
        return false;
      }
    }
    return true;
  }

  Future<void> saveBookingToFirestore() async {
    try {
      final userId = FirebaseAuth.instance.currentUser?.uid;
      if (userId == null) throw Exception("User not logged in");

      final start = widget.selectedDateTime;
      final end = start.add(Duration(minutes: widget.totalDuration));

      final slotAvailable = await isSlotAvailable(start, end);
      if (!slotAvailable) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("❌ This slot was just booked by someone else.")),
        );
        Navigator.pop(context);
        return;
      }

      final bookingRef = FirebaseFirestore.instance.collection('bookings').doc();
      final bookingId = bookingRef.id;

      await bookingRef.set({
        'bookingId': bookingId,
        'userId': userId,
        'barberId': widget.barberId,
        'services': widget.selectedServices,
        'totalPrice': widget.totalPrice,
        'totalDuration': widget.totalDuration,
        'scheduledAt': Timestamp.fromDate(start),
        'estimatedEndAt': Timestamp.fromDate(end),
        'paymentMethod': widget.paymentMethod,
        'status': 'pending',
        'type': 'standard',
        'createdAt': FieldValue.serverTimestamp(),
      });

      await FirebaseFirestore.instance.collection('notifications').add({
        'recipientId': widget.barberId,
        'type': 'new_booking',
        'title': 'New Booking',
        'message': 'A new appointment has been booked.',
        'bookingId': bookingId,
        'timestamp': FieldValue.serverTimestamp(),
        'isRead': false,
      });

      setState(() => isSaving = false);
    } catch (e) {
      print("❌ Error saving booking: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error saving booking: $e")),
      );
    }
  }

  void openWhatsAppChat() async {
    if (barberPhone == null || barberPhone!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Barber phone number is missing.")),
      );
      return;
    }

    final phone = barberPhone!.replaceAll(RegExp(r'\D'), '');
    final message = Uri.encodeComponent("Hi, I just booked an appointment via your app!");
    final url = "https://wa.me/$phone?text=$message";

    final canOpen = await canLaunchUrlString(url);
    if (canOpen) {
      await launchUrlString(url, mode: LaunchMode.externalApplication);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Unable to launch WhatsApp")),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = "${widget.selectedDateTime.toLocal()}".split('.')[0];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Booking Confirmation'),
        backgroundColor: Colors.deepPurple,
      ),
      body: isSaving
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green, size: 80),
                    const SizedBox(height: 16),
                    const Text(
                      "Booking Confirmed!",
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    Text("📅 $formattedDate"),
                    Text("⏱ ${widget.totalDuration} mins"),
                    Text("💵 RM ${widget.totalPrice.toStringAsFixed(2)}"),
                    Text("💳 ${widget.paymentMethod}"),
                    const SizedBox(height: 20),
                    const Text("✂️ Services:", style: TextStyle(fontWeight: FontWeight.bold)),
                    ...widget.selectedServices.map((s) => Text("- ${s['type']}")),
                    const SizedBox(height: 24),
                    if (barberPhone != null)
                      ElevatedButton.icon(
                        onPressed: openWhatsAppChat,
                        icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.white),
                        label: const Text("Chat on WhatsApp"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/home', (_) => false),
              icon: const Icon(Icons.home),
              label: const Text("Back to Home"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            ),
            const SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () => Navigator.pushNamedAndRemoveUntil(context, '/user appointments', (_) => false),
              icon: const Icon(Icons.calendar_today),
              label: const Text("View My Appointments"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey[700]),
            ),
          ],
        ),
      ),
    );
  }
}
