import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:geocoding/geocoding.dart';
import 'package:intl/intl.dart';
import 'package:location/location.dart' as loc;

class HomeBarber extends StatefulWidget {
  const HomeBarber({Key? key}) : super(key: key);

  @override
  State<HomeBarber> createState() => _HomeBarberState();
}

class _HomeBarberState extends State<HomeBarber> {
  String barberName = "Loading...";
  String? profileImageUrl;
  String _address = 'Fetching location...';

  int todayAppointments = 0;
  double todayEarnings = 0.0;
  int totalCompletedAppointments = 0;
  double totalEarnings = 0.0;
  int todayRequestedAppointments = 0;
  double todayRequestedEarnings = 0.0;

  bool hasUnreadNotifications = false;
  int _currentIndex = 0;

  final loc.Location location = loc.Location();

  // Updated Theme Colors to match AdminDashboard exactly
  static const Color primaryOrange = Color(0xFFFF6B35); // Exact match with AdminDashboard
  static const Color secondaryYellow = Color(0xFFFFC107); // Exact match with AdminDashboard
  static const Color accentAmber = Color(0xFFFFB300); // Exact match with AdminDashboard
  static const Color darkOrange = Color(0xFFE55A2B); // Darker shade of primary orange
  static const Color lightOrange = Color(0xFFFF7A47); // Lighter shade of primary orange
  static const Color primaryBlack = Color(0xFF1A1A1A); // Match AdminDashboard dark background
  static const Color cardBlack = Color(0xFF2D2D2D); // Match AdminDashboard card background
  static const Color surfaceBlack = Color(0xFF262626); // Surface elements
  static const Color textGrey = Color(0xFF9E9E9E); // Secondary text
  static const Color dividerGrey = Color(0xFF3A3A3A); // Dividers and borders
  static const Color accentPurple = Color(0xFF9C27B0); // Purple for schedule
  static const Color accentBlue = Color(0xFF2196F3); // Blue for profile
  static const Color accentGreen = Color(0xFF4CAF50); // Green for feedback
  static const Color textLight = Color(0xFFFFFBE6); // Light text color from AdminDashboard

  final List<Map<String, dynamic>> _navItems = [
    {'label': 'Home', 'icon': Icons.home, 'route': '/barb'},
    {'label': 'Appointments', 'icon': Icons.calendar_today, 'route': '/barberAppointments'},
    {'label': 'Profile', 'icon': Icons.person, 'route': '/editProfile'},
    {'label': 'Schedule', 'icon': Icons.schedule, 'route': '/schedule'},
  ];

  @override
  void initState() {
    super.initState();
    fetchAndSaveLocation();
    checkUnreadNotifications();
    fetchBarberProfile();
    calculateEarningsStats();
  }

  Future<void> calculateEarningsStats() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final endOfToday = DateTime(now.year, now.month, now.day, 23, 59, 59);

    final completedBookings = await FirebaseFirestore.instance
        .collection('bookings')
        .where('barberId', isEqualTo: uid)
        .where('status', isEqualTo: 'complete')
        .get();

    final requestedAppointments = await FirebaseFirestore.instance
        .collection('barberServiceRequests')
        .where('barberId', isEqualTo: uid)
        .where('status', whereIn: ['confirmed', 'complete'])
        .get();

    int totalCount = 0;
    double totalEarn = 0.0;
    int todayCount = 0;
    double todayEarn = 0.0;
    int todayRequestedCount = 0;
    double todayRequestedEarn = 0.0;

    for (var doc in completedBookings.docs) {
      final data = doc.data();
      final price = data['totalPrice'] ?? 0.0;
      final scheduledAt = data['scheduledAt'];

      DateTime? scheduledDate;
      if (scheduledAt is Timestamp) {
        scheduledDate = scheduledAt.toDate();
      }

      totalCount += 1;
      totalEarn += (price is num) ? price.toDouble() : 0.0;

      if (scheduledDate != null &&
          scheduledDate.isAfter(startOfToday) &&
          scheduledDate.isBefore(endOfToday)) {
        todayCount += 1;
        todayEarn += (price is num) ? price.toDouble() : 0.0;
      }
    }

    for (var doc in requestedAppointments.docs) {
      final data = doc.data();
      final price = data['price'] ?? 0.0;
      final scheduledAt = data['scheduledAt'];

      DateTime? scheduledDate;
      if (scheduledAt is Timestamp) {
        scheduledDate = scheduledAt.toDate();
      }

      todayRequestedCount += 1;
      todayRequestedEarn += (price is num) ? price.toDouble() : 0.0;

      if (scheduledDate != null &&
          scheduledDate.isAfter(startOfToday) &&
          scheduledDate.isBefore(endOfToday)) {
        todayRequestedAppointments += 1;
      }
    }

    setState(() {
      todayAppointments = todayCount;
      todayEarnings = todayEarn;
      totalCompletedAppointments = totalCount;
      totalEarnings = totalEarn;
      todayRequestedAppointments = todayRequestedCount;
      todayRequestedEarnings = todayRequestedEarn;
    });
  }

  Future<void> fetchBarberProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      final data = doc.data();
      setState(() {
        barberName = data?['name'] ?? 'Barber';
        profileImageUrl = data?['image'];
      });
    }
  }

  Future<void> checkUnreadNotifications() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final snapshot = await FirebaseFirestore.instance
        .collection('notifications')
        .where('recipientId', isEqualTo: uid)
        .where('isRead', isEqualTo: false)
        .get();

    setState(() => hasUnreadNotifications = snapshot.docs.isNotEmpty);
  }

  Future<void> fetchAndSaveLocation() async {
    try {
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) return;
      }

      final permissionGranted = await location.requestPermission();
      if (permissionGranted == loc.PermissionStatus.granted) {
        final locData = await location.getLocation();

        List<Placemark> placemarks = await placemarkFromCoordinates(
          locData.latitude!,
          locData.longitude!,
        );

        final place = placemarks.first;
        final readableAddress =
            '${place.subLocality}, ${place.locality}, ${place.administrativeArea}, ${place.country}';

        setState(() => _address = readableAddress);

        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid != null) {
          await FirebaseFirestore.instance.collection('users').doc(uid).update({
            'location': {
              'lat': locData.latitude,
              'lng': locData.longitude,
            },
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Location updated successfully'),
              backgroundColor: primaryOrange,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
          );
        }
      }
    } catch (e) {
      print('Error getting location: $e');
      setState(() => _address = 'Unable to fetch location');
    }
  }

  Future<void> logout() async {
    await FirebaseAuth.instance.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
      Navigator.pushNamed(context, _navItems[index]['route']);
    }
  }

  Future<void> switchRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final currentRole = doc.data()?['role'] ?? 'user';
    final newRole = currentRole == 'barber' ? 'user' : 'barber';

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'role': newRole,
    });

    if (newRole == 'barber') {
      Navigator.pushReplacementNamed(context, '/barb');
    } else {
      Navigator.pushReplacementNamed(context, '/home');
    }
  }

  void showFeedbackDialog() {
    final TextEditingController _feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: cardBlack,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Send Feedback', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: Container(
          width: double.maxFinite,
          child: TextField(
            controller: _feedbackController,
            maxLines: 4,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'Enter your feedback here',
              hintStyle: TextStyle(color: textGrey),
              filled: true,
              fillColor: surfaceBlack,
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: dividerGrey),
                borderRadius: BorderRadius.circular(12),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: primaryOrange, width: 2),
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: TextStyle(color: textGrey)),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [primaryOrange, secondaryYellow],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(25),
            ),
            child: ElevatedButton(
              onPressed: () async {
                final message = _feedbackController.text.trim();
                final user = FirebaseAuth.instance.currentUser;

                if (message.isNotEmpty && user != null) {
                  await FirebaseFirestore.instance.collection('feedbacks').add({
                    'message': message,
                    'role': 'barber',
                    'timestamp': Timestamp.now(),
                    'userId': user.uid,
                  });
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: const Text('Thank you for your feedback!'),
                      backgroundColor: primaryOrange,
                      behavior: SnackBarBehavior.floating,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(25)),
              ),
              child: const Text('Submit', style: TextStyle(color: Colors.white)),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: primaryBlack,
      body: SafeArea(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                // Location Header with Notification
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  child: Row(
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: primaryOrange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(Icons.location_on, color: primaryOrange, size: 22),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Current Location',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    _address,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: textGrey,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          color: cardBlack,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: IconButton(
                          icon: Stack(
                            children: [
                              Icon(Icons.notifications_outlined, color: Colors.white, size: 26),
                              if (hasUnreadNotifications)
                                Positioned(
                                  right: 0,
                                  top: 0,
                                  child: Container(
                                    padding: EdgeInsets.all(2),
                                    decoration: BoxDecoration(
                                      color: Colors.red,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    constraints: BoxConstraints(minWidth: 16, minHeight: 16),
                                    child: Text(
                                      '!',
                                      style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          onPressed: () async {
                            await Navigator.pushNamed(context, '/barberNotifications');
                            checkUnreadNotifications();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Profile Card with updated gradient matching AdminDashboard
                Container(
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        primaryOrange,
                        secondaryYellow,
                        accentAmber,
                      ],
                      stops: [0.0, 0.5, 1.0],
                    ),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: primaryOrange.withOpacity(0.4),
                        blurRadius: 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Stack(
                    children: [
                      // Background pattern
                      Positioned(
                        right: -20,
                        top: -20,
                        child: CircleAvatar(
                          radius: 50,
                          backgroundColor: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      Positioned(
                        right: 20,
                        bottom: -30,
                        child: CircleAvatar(
                          radius: 30,
                          backgroundColor: Colors.white.withOpacity(0.05),
                        ),
                      ),

                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(color: Colors.white, width: 4),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.2),
                                        blurRadius: 10,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  child: CircleAvatar(
                                    radius: 40,
                                    backgroundImage: profileImageUrl != null && profileImageUrl!.isNotEmpty
                                        ? NetworkImage(profileImageUrl!)
                                        : const AssetImage('images/boy.jpg') as ImageProvider,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Welcome back!',
                                        style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white.withOpacity(0.95),
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        barberName,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 24),

                            // Stats Row
                            Row(
                              children: [
                                Expanded(
                                  child: _buildStatCard(
                                    'TODAY',
                                    todayAppointments.toString(),
                                    'RM ${todayEarnings.toStringAsFixed(0)}',
                                    Icons.today_rounded,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    'REQUESTS',
                                    todayRequestedAppointments.toString(),
                                    'RM ${todayRequestedEarnings.toStringAsFixed(0)}',
                                    Icons.assignment_outlined,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: _buildStatCard(
                                    'TOTAL',
                                    totalCompletedAppointments.toString(),
                                    'RM ${totalEarnings.toStringAsFixed(0)}',
                                    Icons.trending_up_rounded,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Quick Actions Grid with updated colors
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 2,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 1.5,
                  children: [
                    _buildQuickActionCard(
                      'Appointments',
                      Icons.calendar_today,
                      primaryOrange,
                      '/barberAppointments',
                    ),
                    _buildQuickActionCard(
                      'Schedule',
                      Icons.schedule,
                      secondaryYellow,
                      '/schedule',
                    ),
                    _buildQuickActionCard(
                      'Profile',
                      Icons.edit,
                      accentAmber,
                      '/editProfile',
                    ),
                    _buildQuickActionCard(
                      'Feedback',
                      Icons.feedback,
                      accentGreen,
                      null,
                      onTap: showFeedbackDialog,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Action Buttons
                Column(
                  children: [
                    _buildFullWidthButton(
                      'Switch to User Mode',
                      Icons.swap_horiz,
                      primaryOrange,
                      switchRole,
                    ),
                    const SizedBox(height: 12),
                    _buildFullWidthButton(
                      'Logout',
                      Icons.logout,
                      surfaceBlack,
                      logout,
                    ),
                  ],
                ),

                const SizedBox(height: 100), // Extra space for bottom navigation
              ],
            ),
          ),
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              cardBlack,
              primaryBlack,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Container(
            height: 70,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _navItems.asMap().entries.map((entry) {
                int index = entry.key;
                Map<String, dynamic> item = entry.value;
                bool isSelected = _currentIndex == index;

                return Expanded(
                  child: GestureDetector(
                    onTap: () => _onTabTapped(index),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        gradient: isSelected
                            ? LinearGradient(
                          colors: [primaryOrange, secondaryYellow],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                            : null,
                        color: isSelected ? null : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isSelected
                            ? [
                          BoxShadow(
                            color: primaryOrange.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                            : null,
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            item['icon'],
                            color: isSelected ? Colors.white : textGrey,
                            size: isSelected ? 24 : 22,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item['label'],
                            style: TextStyle(
                              color: isSelected ? Colors.white : textGrey,
                              fontSize: 10,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                            ),
                            textAlign: TextAlign.center,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String title, String number, String amount, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: Colors.white, size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            number,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.white.withOpacity(0.9),
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            amount,
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.8),
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionCard(
      String title,
      IconData icon,
      Color color,
      String? route, {
        VoidCallback? onTap,
      }) {
    return GestureDetector(
      onTap: () {
        if (onTap != null) {
          onTap();
        } else if (route != null) {
          Navigator.pushNamed(context, route);
        }
      },
      child: Container(
        decoration: BoxDecoration(
          color: cardBlack,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3)),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFullWidthButton(
      String title,
      IconData icon,
      Color color,
      VoidCallback onPressed,
      ) {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        gradient: color == primaryOrange
            ? LinearGradient(
          colors: [primaryOrange, secondaryYellow],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: color == primaryOrange ? null : color,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white, size: 20),
        label: Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.bold,
          ),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}