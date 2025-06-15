import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher_string.dart';

class RequestAppointmentDetail extends StatefulWidget {
  const RequestAppointmentDetail({Key? key}) : super(key: key);

  @override
  State<RequestAppointmentDetail> createState() => _RequestAppointmentDetailState();
}

class _RequestAppointmentDetailState extends State<RequestAppointmentDetail> {
  String? selectedStatus;
  bool isUpdating = false;

  String formatDateTime(String date, String time) {
    return '$date at $time';
  }

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

  void openWhatsAppChat(String phone) async {
    final phoneClean = phone.replaceAll(RegExp(r'\D'), '');
    final message = Uri.encodeComponent("Hi, about your barber service request...");
    final url = "https://wa.me/$phoneClean?text=$message";

    if (await canLaunchUrlString(url)) {
      await launchUrlString(url);
    } else {
      print("Unable to launch WhatsApp");
    }
  }

  Future<void> updateStatus(String requestId, String userId, String newStatus) async {
    setState(() => isUpdating = true);
    await FirebaseFirestore.instance.collection('barberServiceRequests').doc(requestId).update({'status': newStatus});

    await FirebaseFirestore.instance.collection('notifications').add({
      'recipientId': userId,
      'title': 'Request $newStatus',
      'message': 'Your barber request has been marked as $newStatus.',
      'type': 'request_status_update',
      'timestamp': FieldValue.serverTimestamp(),
      'isRead': false,
    });

    setState(() {
      selectedStatus = newStatus;
      isUpdating = false;
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Status updated to $newStatus and user notified.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    final requestData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    final requestId = requestData['id'];
    final userName = requestData['userName'] ?? 'Unknown User';
    final userId = requestData['userId'] ?? '-';
    final preferredDate = requestData['preferredDate'] ?? '-';
    final preferredTime = requestData['preferredTime'] ?? '-';
    final styleDescription = requestData['styleDescription'] ?? '-';
    final status = requestData['status'] ?? 'pending';
    final timestamp = requestData['timestamp'] ?? Timestamp.now();
    final userImage = requestData['userImage'];
    final userPhone = requestData['userPhone'];
    final price = requestData['price']; // Fetch the price

    selectedStatus ??= status;

    final formattedRequestTime = DateFormat('MMM d, y • h:mm a').format(timestamp.toDate());

    return Scaffold(
      appBar: AppBar(
        title: const Text("Request Detail"),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        userImage != null
                            ? CircleAvatar(radius: 30, backgroundImage: NetworkImage(userImage))
                            : const CircleAvatar(radius: 30, child: Icon(Icons.person)),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            userName,
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                        ),
                        if (userPhone != null)
                          IconButton(
                            icon: const Icon(Icons.chat, color: Colors.green),
                            onPressed: () => openWhatsAppChat(userPhone),
                          ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Text('Style Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text(styleDescription),
                    const SizedBox(height: 20),
                    Text('🕓 Request Submitted: $formattedRequestTime'),
                    Text('📅 Preferred Date: $preferredDate'),
                    Text('⏰ Preferred Time: $preferredTime'),
                    const SizedBox(height: 12),

                    // Display price if available
                    if (price != null)
                      Text(
                        '💰 Price: RM ${price.toStringAsFixed(2)}',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                    const SizedBox(height: 12),

                    Row(
                      children: [
                        const Text('Status: ', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          selectedStatus!.toUpperCase(),
                          style: TextStyle(
                            color: getStatusColor(selectedStatus!),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    DropdownButtonFormField<String>(
                      value: selectedStatus,
                      items: [
                        'approved',
                        'pending',
                        'confirmed',
                        'on the way',
                        'during',
                        'complete',
                        'cancelled'
                      ].map((status) => DropdownMenuItem(value: status, child: Text(status))).toList(),
                      onChanged: isUpdating
                          ? null
                          : (val) {
                        if (val != null && val != selectedStatus) {
                          updateStatus(requestId, userId, val);
                        }
                      },
                      decoration: const InputDecoration(
                        labelText: 'Update Status',
                        border: OutlineInputBorder(),
                      ),
                    )
                  ],
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}
