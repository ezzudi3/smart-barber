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
            const SnackBar(content: Text('Location updated successfully')),
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
        title: const Text('Send Feedback'),
        content: TextField(
          controller: _feedbackController,
          maxLines: 4,
          decoration: const InputDecoration(hintText: 'Enter your feedback here'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
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
                  const SnackBar(content: Text('Thank you for your feedback!')),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Submit'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text('Barber Dashboard', style: TextStyle(color: Colors.white)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Stack(
              children: [
                const Icon(Icons.notifications, color: Colors.white),
                if (hasUnreadNotifications)
                  const Positioned(
                    right: 0,
                    top: 0,
                    child: CircleAvatar(
                      radius: 5,
                      backgroundColor: Colors.red,
                    ),
                  ),
              ],
            ),
            onPressed: () async {
              await Navigator.pushNamed(context, '/barberNotifications');
              checkUnreadNotifications();
            },
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 10),
            Text("Current Location:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(_address, style: TextStyle(fontSize: 14)),
            const SizedBox(height: 20),
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundImage: profileImageUrl != null && profileImageUrl!.isNotEmpty
                      ? NetworkImage(profileImageUrl!)
                      : const AssetImage('images/boy.jpg') as ImageProvider,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Welcome, $barberName!',
                          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                      Text('Today: $todayAppointments appointments • RM ${todayEarnings.toStringAsFixed(2)}'),
                      Text('Requested Today: $todayRequestedAppointments requests • RM ${todayRequestedEarnings.toStringAsFixed(2)}'),
                      Text('Total: $totalCompletedAppointments completed • RM ${totalEarnings.toStringAsFixed(2)}'),
                    ],
                  ),
                )
              ],
            ),
            const SizedBox(height: 30),
            _buildDashboardButton(context, title: 'View Appointments', icon: Icons.calendar_today, color: Colors.teal, route: '/barberAppointments'),
            const SizedBox(height: 20),
            _buildDashboardButton(context, title: 'Manage Schedule', icon: Icons.schedule, color: Colors.orange, route: '/schedule'),
            const SizedBox(height: 20),
            _buildDashboardButton(context, title: 'Edit Profile', icon: Icons.edit, color: Colors.indigo, route: '/editProfile'),
            const Spacer(),
            ElevatedButton.icon(
              onPressed: logout,
              icon: const Icon(Icons.logout),
              label: const Text('Logout'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.grey, padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: switchRole,
              icon: const Icon(Icons.swap_horiz),
              label: const Text('Switch to User'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
            const SizedBox(height: 10),
            ElevatedButton.icon(
              onPressed: showFeedbackDialog,
              icon: const Icon(Icons.feedback),
              label: const Text('Give Feedback'),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple, padding: const EdgeInsets.symmetric(vertical: 16)),
            ),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.deepPurple,
        onTap: _onTabTapped,
        items: _navItems.map((item) => BottomNavigationBarItem(
          icon: Icon(item['icon']),
          label: item['label'],
        )).toList(),
      ),
    );
  }

  Widget _buildDashboardButton(
      BuildContext context, {
        required String title,
        required IconData icon,
        required Color color,
        required String route,
      }) {
    return ElevatedButton(
      onPressed: () => Navigator.pushNamed(context, route),
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, color: Colors.white),
          const SizedBox(width: 12),
          Text(title, style: const TextStyle(fontSize: 18, color: Colors.white)),
        ],
      ),
    );
  }
}
