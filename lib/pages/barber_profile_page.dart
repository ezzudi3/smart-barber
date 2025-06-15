import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'FullImageView.dart';

class BarberProfilePage extends StatelessWidget {
  final String barberId;

  const BarberProfilePage({Key? key, required this.barberId}) : super(key: key);

  Future<Map<String, dynamic>?> fetchBarberProfile() async {
    final doc = await FirebaseFirestore.instance.collection('users').doc(barberId).get();
    return doc.exists ? doc.data() : null;
  }

  Stream<QuerySnapshot> fetchReviews() {
    return FirebaseFirestore.instance
        .collection('reviews')
        .where('barberId', isEqualTo: barberId)
        .orderBy('timestamp', descending: true)
        .snapshots();
  }

  String formatTimestamp(Timestamp timestamp) {
    return DateFormat('MMM d, y – h:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,  // Disable default back arrow
          title: const Text('Barber Profile'),
          backgroundColor: Colors.deepPurple,
          leading: IconButton(  // Custom back arrow
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              Navigator.pop(context);  // Go back to the previous screen (home or wherever the page was called from)
            },
          ),
          bottom: const TabBar(
            indicatorColor: Colors.white,
            tabs: [
              Tab(text: 'About'),
              Tab(text: 'Services'),
              Tab(text: 'Reviews'),
              Tab(text: 'Gallery'),
            ],
          ),
        ),
        body: FutureBuilder<Map<String, dynamic>?>(
          future: fetchBarberProfile(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(child: Text('Barber profile not found.'));
            }

            final data = snapshot.data!;
            final image = data['image'];
            final name = data['name'] ?? '';
            final bio = data['bio'] ?? '';
            final experience = data['experience'] ?? '';
            final phone = data['phone'] ?? '-';
            final specialties = List<Map<String, dynamic>>.from(data['specialties'] ?? []);
            final gallery = List<String>.from(data['gallery'] ?? []);
            final workingHours = Map<String, dynamic>.from(data['workingHours'] ?? {});

            return TabBarView(
              children: [
                // === ABOUT TAB ===
                ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Center(
                      child: CircleAvatar(
                        radius: 50,
                        backgroundImage: image != null ? NetworkImage(image) : null,
                        child: image == null ? const Icon(Icons.person, size: 50) : null,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Center(child: Text(name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold))),
                    const SizedBox(height: 4),
                    Center(child: Text('$experience years of experience')),
                    const SizedBox(height: 4),
                    Center(child: Text('📞 $phone')),
                    const SizedBox(height: 16),

                    const Text('Bio', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    Text(bio.isNotEmpty ? bio : 'No bio provided.'),
                    const SizedBox(height: 20),

                    const Text('Working Hours', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 8),
                    ...[
                      'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
                    ].map((day) {
                      final entry = workingHours[day];
                      if (entry != null && entry is Map<String, dynamic>) {
                        return Text('$day: 🟢 ${entry['start']} - ${entry['end']}');
                      } else {
                        return Text('$day: 🔴 Not Available');
                      }
                    }).toList(),
                  ],
                ),

                // === SERVICES TAB ===
                specialties.isEmpty
                    ? const Center(child: Text('No specialties listed.'))
                    : ListView(
                  padding: const EdgeInsets.all(16),
                  children: specialties.map((s) {
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6),
                      child: ListTile(
                        title: Text(s['type'] ?? ''),
                        subtitle: Text(
                          'Duration: ${s['duration']} mins  •  RM ${s['price']}',
                          style: const TextStyle(fontSize: 14),
                        ),
                      ),
                    );
                  }).toList(),
                ),

                // === REVIEWS TAB ===
                StreamBuilder<QuerySnapshot>(
                  stream: fetchReviews(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(child: Text('No reviews yet.'));
                    }

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: snapshot.data!.docs.map((doc) {
                        final review = doc.data() as Map<String, dynamic>;
                        final comment = review['comment'] ?? '';
                        final rating = review['rating']?.toDouble() ?? 0.0;
                        final timestamp = review['timestamp'] as Timestamp?;
                        final formattedTime = timestamp != null ? formatTimestamp(timestamp) : 'Unknown time';

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 8),
                          child: ListTile(
                            title: Text('⭐ ${rating.toStringAsFixed(1)}'),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(comment),
                                const SizedBox(height: 4),
                                Text(formattedTime, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    );
                  },
                ),

                // === GALLERY TAB ===
                gallery.isEmpty
                    ? const Center(child: Text('No gallery photos uploaded.'))
                    : Padding(
                  padding: const EdgeInsets.all(8),
                  child: GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: gallery.length,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                    ),
                    itemBuilder: (context, index) {
                      final url = gallery[index];
                      return GestureDetector(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => FullImageView(imageUrl: url),
                            ),
                          );
                        },
                        child: Hero(
                          tag: url,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.network(
                              url,
                              fit: BoxFit.cover,
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushNamed(context, '/bookingStep1', arguments: barberId);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: const Text('Book Now'),
          ),
        ),
      ),
    );
  }
}
