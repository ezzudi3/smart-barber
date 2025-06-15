import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';

class UserNotificationsScreen extends StatefulWidget {
  const UserNotificationsScreen({Key? key}) : super(key: key);

  @override
  State<UserNotificationsScreen> createState() => _UserNotificationsScreenState();
}

class _UserNotificationsScreenState extends State<UserNotificationsScreen> {
  final userId = FirebaseAuth.instance.currentUser!.uid;

  Future<void> markAsRead(String notificationId) async {
    await FirebaseFirestore.instance.collection('notifications').doc(notificationId).update({
      'isRead': true,
    });
  }

  Future<void> confirmBarberRole(String notificationId) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'role': 'barber'
    });
    await markAsRead(notificationId);
    Navigator.pushReplacementNamed(context, '/barb');
  }

  String formatDate(Timestamp? ts) {
    if (ts == null) return '';
    return DateFormat('MMM d, y – h:mm a').format(ts.toDate());
  }

  Future<void> showRequestDialog(BuildContext context, String title, String message) async {
    return showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: Colors.deepPurple,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('notifications')
            .where('recipientId', isEqualTo: userId)
            .orderBy('timestamp', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;

          if (docs.isEmpty) {
            return const Center(child: Text("No notifications yet."));
          }

          return ListView(
            children: docs.map((doc) {
              final data = doc.data() as Map<String, dynamic>;
              final isRead = data['isRead'] ?? false;
              final type = data['type'] ?? '';
              final title = data['title'] ?? 'Notification';
              final message = data['message'] ?? '';
              final timestamp = data['timestamp'] as Timestamp?;

              return InkWell(
                onTap: () async {
                  await markAsRead(doc.id);
                  if (type == 'request_response') {
                    showRequestDialog(context, title, message);
                  }
                },
                child: Card(
                  color: isRead ? null : Colors.deepPurple[50],
                  margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text(message),
                        const SizedBox(height: 4),
                        Text(formatDate(timestamp), style: const TextStyle(fontSize: 12, color: Colors.grey)),
                        const SizedBox(height: 8),

                        if (type == 'barber_approval')
                          Row(
                            children: [
                              ElevatedButton(
                                onPressed: () => confirmBarberRole(doc.id),
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                                child: const Text('Confirm'),
                              ),
                              const SizedBox(width: 8),
                              OutlinedButton(
                                onPressed: () => markAsRead(doc.id),
                                child: const Text('Cancel'),
                              ),
                            ],
                          )
                        else if (!isRead)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              child: const Text("Mark Read"),
                              onPressed: () => markAsRead(doc.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          );
        },
      ),
    );
  }
}
