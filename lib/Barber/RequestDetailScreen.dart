import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class RequestDetailScreen extends StatefulWidget {
  const RequestDetailScreen({Key? key}) : super(key: key);

  @override
  _RequestDetailScreenState createState() => _RequestDetailScreenState();
}

class _RequestDetailScreenState extends State<RequestDetailScreen> {
  late String requestId;
  late String userName;
  late String preferredDate;
  late String preferredTime;
  late String style;
  late String userId;
  late String status;
  late String barberName;
  late String barberId;

  double? price;

  @override
  Widget build(BuildContext context) {
    final requestData = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    requestId = requestData['id'];
    userName = requestData['userName'] ?? '';
    preferredDate = requestData['preferredDate'] ?? '';
    preferredTime = requestData['preferredTime'] ?? '';
    style = requestData['styleDescription'] ?? '';
    userId = requestData['userId'];
    status = requestData['status'];
    barberName = requestData['barberName'] ?? 'Barber';
    barberId = requestData['barberId'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Request Details'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('From: $userName', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                Text('Preferred Date: $preferredDate'),
                Text('Preferred Time: $preferredTime'),
                const SizedBox(height: 12),
                const Text('Style Description:', style: TextStyle(fontWeight: FontWeight.bold)),
                Text(style),
                const SizedBox(height: 16),
                Text('Status: ${status.toUpperCase()}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: status == 'approved'
                          ? Colors.green
                          : status == 'denied'
                          ? Colors.red
                          : Colors.orange,
                    )),
                const SizedBox(height: 16),

                // Barber adjusts price before approving or denying
                if (status == 'pending') ...[
                  const Text('Set Price (RM):', style: TextStyle(fontWeight: FontWeight.bold)),
                  TextField(
                    onChanged: (value) {
                      setState(() {
                        price = double.tryParse(value);
                      });
                    },
                    keyboardType: TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      hintText: 'Enter price',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                const Spacer(),

                // Buttons for approving or denying request
                if (status == 'pending')
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => updateRequestStatus(
                            context: context,
                            requestId: requestId,
                            status: 'approved',
                            userId: userId,
                            barberName: barberName,
                            barberId: barberId,
                            preferredDate: preferredDate,
                            preferredTime: preferredTime,
                            styleDescription: style,
                            price: price, // Add price to update
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Approve'),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () => updateRequestStatus(
                            context: context,
                            requestId: requestId,
                            status: 'denied',
                            userId: userId,
                            barberName: barberName,
                            barberId: barberId,
                            preferredDate: preferredDate,
                            preferredTime: preferredTime,
                            styleDescription: style,
                            price: price, // Add price to update
                          ),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Deny'),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> updateRequestStatus({
    required BuildContext context,
    required String requestId,
    required String status,
    required String userId,
    required String barberId,
    required String barberName,
    required String preferredDate,
    required String preferredTime,
    required String styleDescription,
    required double? price,
  }) async {
    final firestore = FirebaseFirestore.instance;

    // 1. Update the request status
    await firestore.collection('barberServiceRequests').doc(requestId).update({
      'status': status,
      'price': price ?? 0.0, // If no price is provided, set as 0.0
    });

    // 2. If approved, only update the request (no creation of booking)
    if (status == 'approved') {
      // We are not adding a booking, just updating the request
      // (The previous booking creation code has been removed as per the request)
    }

    // 3. Notify user
    final message = status == 'approved'
        ? 'Your request with $barberName has been approved!'
        : 'Your request with $barberName has been denied.';

    await firestore.collection('notifications').add({
      'recipientId': userId,
      'title': 'Request $status',
      'message': message,
      'type': 'request_response',
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Request $status and user notified.')),
    );

    Navigator.pop(context);
  }
}
