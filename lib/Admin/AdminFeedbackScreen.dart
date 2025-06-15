import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class AdminFeedbackScreen extends StatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  State<AdminFeedbackScreen> createState() => _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends State<AdminFeedbackScreen> {
  List<Map<String, dynamic>> feedbacks = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    fetchFeedbacks();
  }

  Future<void> fetchFeedbacks() async {
    try {
      final snap = await FirebaseFirestore.instance
          .collection('feedbacks')
          .orderBy('timestamp', descending: true)
          .get();

      List<Map<String, dynamic>> tempData = [];

      for (var doc in snap.docs) {
        final feedback = doc.data();
        final userSnap = await FirebaseFirestore.instance.collection('users').doc(feedback['userId']).get();
        final userData = userSnap.data();

        tempData.add({
          'id': doc.id,
          'userId': feedback['userId'],
          'role': feedback['role'],
          'message': feedback['message'],
          'timestamp': feedback['timestamp']?.toDate(),
          'status': feedback['status'],
          'name': userData?['name'] ?? 'Unknown',
          'phone': userData?['phone'] ?? 'No phone',
        });
      }

      setState(() {
        feedbacks = tempData;
        isLoading = false;
      });
    } catch (e) {
      print('Error fetching feedbacks: $e');
      setState(() => isLoading = false);
    }
  }

  void sendReply(String userId, String message) {
    final controller = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Reply to Feedback'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Type your reply here'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () async {
              final reply = controller.text.trim();
              if (reply.isNotEmpty) {
                await FirebaseFirestore.instance.collection('notifications').add({
                  'recipientId': userId,
                  'message': reply,
                  'timestamp': Timestamp.now(),
                  'isRead': false,
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Reply sent successfully')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Send Reply'),
          ),
        ],
      ),
    );
  }

  void deleteFeedback(String feedbackId) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete Feedback'),
        content: const Text('Are you sure you want to delete this feedback?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await FirebaseFirestore.instance.collection('feedbacks').doc(feedbackId).delete();
      fetchFeedbacks(); // Refresh list
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Feedback deleted')),
      );
    }
  }

  String formatDate(DateTime? dt) {
    if (dt == null) return '-';
    return DateFormat('dd MMM yyyy, hh:mm a').format(dt);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : feedbacks.isEmpty
          ? const Center(child: Text('No feedbacks found.'))
          : ListView.builder(
        padding: const EdgeInsets.all(12),
        itemCount: feedbacks.length,
        itemBuilder: (context, index) {
          final item = feedbacks[index];
          return Card(
            margin: const EdgeInsets.symmetric(vertical: 8),
            child: ListTile(
              title: Text(item['name'] ?? 'Unknown'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Phone: ${item['phone']}'),
                  Text('Role: ${item['role']}'),
                  const SizedBox(height: 5),
                  Text('Feedback: ${item['message']}'),
                  const SizedBox(height: 5),
                  Text(formatDate(item['timestamp']),
                      style: const TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.reply, color: Colors.deepPurple),
                    onPressed: () => sendReply(item['userId'], item['message']),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: () => deleteFeedback(item['id']),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
