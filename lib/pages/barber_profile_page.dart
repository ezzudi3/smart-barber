import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'FullImageView.dart';

class BarberProfilePage extends StatelessWidget {
  final String barberId;

  const BarberProfilePage({Key? key, required this.barberId}) : super(key: key);

  // Color scheme
  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color darkBackground = Color(0xFF1A1A1A);
  static const Color cardBackground = Color(0xFF2D2D2D);
  static const Color textPrimary = Colors.white;
  static const Color textSecondary = Color(0xFFB0B0B0);

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

  Widget _buildInfoCard({
    required Widget child,
    EdgeInsets? padding,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: padding ?? const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: primaryOrange.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildSectionTitle(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: primaryOrange, size: 20),
            const SizedBox(width: 8),
          ],
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: primaryOrange,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWorkingHoursRow(String day, Map<String, dynamic>? entry) {
    final isAvailable = entry != null && entry is Map<String, dynamic>;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            day,
            style: const TextStyle(
              color: textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
          Row(
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: isAvailable ? Colors.green : Colors.red,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                isAvailable ? '${entry['start']} - ${entry['end']}' : 'Closed',
                style: TextStyle(
                  color: isAvailable ? textPrimary : textSecondary,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildServiceCard(Map<String, dynamic> service) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryOrange.withOpacity(0.3)),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: primaryOrange.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.content_cut,
            color: primaryOrange,
            size: 20,
          ),
        ),
        title: Text(
          service['type'] ?? '',
          style: const TextStyle(
            color: textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              Icon(Icons.access_time, size: 14, color: textSecondary),
              const SizedBox(width: 4),
              Text(
                '${service['duration']} mins',
                style: TextStyle(color: textSecondary, fontSize: 12),
              ),
              const SizedBox(width: 16),
              Icon(Icons.attach_money, size: 14, color: primaryOrange),
              Text(
                'RM ${service['price']}',
                style: const TextStyle(
                  color: primaryOrange,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReviewCard(Map<String, dynamic> review) {
    final comment = review['comment'] ?? '';
    final rating = review['rating']?.toDouble() ?? 0.0;
    final timestamp = review['timestamp'] as Timestamp?;
    final formattedTime = timestamp != null ? formatTimestamp(timestamp) : 'Unknown time';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryOrange.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryOrange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star, color: primaryOrange, size: 14),
                    const SizedBox(width: 4),
                    Text(
                      rating.toStringAsFixed(1),
                      style: const TextStyle(
                        color: primaryOrange,
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                formattedTime,
                style: const TextStyle(
                  fontSize: 12,
                  color: textSecondary,
                ),
              ),
            ],
          ),
          if (comment.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              comment,
              style: const TextStyle(
                color: textPrimary,
                fontSize: 14,
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        backgroundColor: darkBackground,
        appBar: AppBar(
          automaticallyImplyLeading: false,
          backgroundColor: Colors.black,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: primaryOrange),
            onPressed: () => Navigator.pop(context),
          ),
          title: const Text(
            'Barber Profile',
            style: TextStyle(
              color: primaryOrange,
              fontWeight: FontWeight.bold,
            ),
          ),
          bottom: TabBar(
            indicatorColor: primaryOrange,
            indicatorWeight: 3,
            labelColor: primaryOrange,
            unselectedLabelColor: textSecondary,
            labelStyle: const TextStyle(fontWeight: FontWeight.w600),
            tabs: const [
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
              return const Center(
                child: CircularProgressIndicator(color: primaryOrange),
              );
            }
            if (!snapshot.hasData || snapshot.data == null) {
              return const Center(
                child: Text(
                  'Barber profile not found.',
                  style: TextStyle(color: textSecondary),
                ),
              );
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
                SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      // Profile Header
                      _buildInfoCard(
                        child: Column(
                          children: [
                            Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(color: primaryOrange, width: 3),
                              ),
                              child: CircleAvatar(
                                radius: 50,
                                backgroundColor: cardBackground,
                                backgroundImage: image != null ? NetworkImage(image) : null,
                                child: image == null
                                    ? const Icon(Icons.person, size: 50, color: primaryOrange)
                                    : null,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              name,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: textPrimary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: primaryOrange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                '$experience years of experience',
                                style: const TextStyle(
                                  color: primaryOrange,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.phone, color: primaryOrange, size: 16),
                                const SizedBox(width: 4),
                                Text(
                                  phone,
                                  style: const TextStyle(color: textSecondary),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // Bio Section
                      _buildInfoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Bio', icon: Icons.info_outline),
                            Text(
                              bio.isNotEmpty ? bio : 'No bio provided.',
                              style: TextStyle(
                                color: bio.isNotEmpty ? textPrimary : textSecondary,
                                fontSize: 14,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Working Hours Section
                      _buildInfoCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildSectionTitle('Working Hours', icon: Icons.schedule),
                            ...[
                              'Monday', 'Tuesday', 'Wednesday', 'Thursday',
                              'Friday', 'Saturday', 'Sunday'
                            ].map((day) {
                              final entry = workingHours[day];
                              return _buildWorkingHoursRow(day, entry);
                            }).toList(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // === SERVICES TAB ===
                specialties.isEmpty
                    ? const Center(
                  child: Text(
                    'No services listed.',
                    style: TextStyle(color: textSecondary),
                  ),
                )
                    : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _buildSectionTitle('Available Services', icon: Icons.content_cut),
                    ...specialties.map((service) => _buildServiceCard(service)).toList(),
                  ],
                ),

                // === REVIEWS TAB ===
                StreamBuilder<QuerySnapshot>(
                  stream: fetchReviews(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: primaryOrange),
                      );
                    }
                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return const Center(
                        child: Text(
                          'No reviews yet.',
                          style: TextStyle(color: textSecondary),
                        ),
                      );
                    }

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        _buildSectionTitle('Customer Reviews', icon: Icons.star_outline),
                        ...snapshot.data!.docs.map((doc) {
                          final review = doc.data() as Map<String, dynamic>;
                          return _buildReviewCard(review);
                        }).toList(),
                      ],
                    );
                  },
                ),

                // === GALLERY TAB ===
                gallery.isEmpty
                    ? const Center(
                  child: Text(
                    'No gallery photos uploaded.',
                    style: TextStyle(color: textSecondary),
                  ),
                )
                    : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSectionTitle('Gallery', icon: Icons.photo_library_outlined),
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: gallery.length,
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 1,
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
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: primaryOrange.withOpacity(0.3),
                                  ),
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    url,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        color: cardBackground,
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            color: primaryOrange,
                                            strokeWidth: 2,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
        bottomNavigationBar: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: Colors.black,
            border: Border(
              top: BorderSide(color: primaryOrange.withOpacity(0.3)),
            ),
          ),
          child: SafeArea(
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pushNamed(context, '/bookingStep1', arguments: barberId);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryOrange,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 4,
                ),
                child: const Text(
                  'Book Now',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}