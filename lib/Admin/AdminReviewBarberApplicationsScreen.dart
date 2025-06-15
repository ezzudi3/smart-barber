import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'full_image_view.dart';

class AdminReviewBarberApplicationsScreen extends StatelessWidget {
  const AdminReviewBarberApplicationsScreen({Key? key}) : super(key: key);

  Future<void> approveApplication(String userId, String name) async {
    await FirebaseFirestore.instance.collection('barberApplications').doc(userId).update({
      'status': 'approved'
    });

    await FirebaseFirestore.instance.collection('notifications').add({
      'recipientId': userId,
      'title': 'Barber Application Approved',
      'message': 'You\'re now approved to become a barber. Tap to confirm.',
      'type': 'barber_approval',
      'isRead': false,
      'timestamp': Timestamp.now(),
      'action': 'switchToBarber'
    });
  }

  Future<void> rejectApplication(String userId) async {
    await FirebaseFirestore.instance.collection('barberApplications').doc(userId).update({
      'status': 'rejected'
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot>(
      stream: FirebaseFirestore.instance
          .collection('barberApplications')
          .where('status', isEqualTo: 'pending')
          .orderBy('submittedAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final docs = snapshot.data!.docs;

        if (docs.isEmpty) return const Center(child: Text('No pending applications.'));

        return ListView.builder(
          itemCount: docs.length,
          itemBuilder: (context, index) {
            final data = docs[index].data() as Map<String, dynamic>;
            final userId = data['userId'];
            final name = data['name'] ?? 'Unnamed';
            final phone = data['phone'] ?? '-';
            final ic = data['icNumber'] ?? '-';
            final bio = data['bio'] ?? '-';
            final exp = data['experience'] ?? '-';
            final license = data['licenseUrl'];

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Name: $name', style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text('Phone: $phone'),
                    Text('IC Number: $ic'),
                    Text('Experience: $exp years'),
                    Text('Bio: $bio'),
                    if (license != null && license.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => FullImageView(imageUrl: license),
                              ),
                            );
                          },
                          child: Hero(
                            tag: license,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: Image.network(
                                license,
                                height: 120,
                                fit: BoxFit.cover,
                              ),
                            ),
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        ElevatedButton(
                          onPressed: () => approveApplication(userId, name),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                          child: const Text('Approve'),
                        ),
                        const SizedBox(width: 10),
                        ElevatedButton(
                          onPressed: () => rejectApplication(userId),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          child: const Text('Reject'),
                        ),
                      ],
                    )
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
