import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:barberapp1/pages/bookingdetailscreen.dart';
import 'package:barberapp1/pages/RequestBookingDetailsScreen.dart';

class UserAppointmentList extends StatefulWidget {
  @override
  _UserAppointmentListState createState() => _UserAppointmentListState();
}

class _UserAppointmentListState extends State<UserAppointmentList> with SingleTickerProviderStateMixin {
  final user = FirebaseAuth.instance.currentUser;
  late TabController _tabController;
  int _selectedIndex = 0;

  final List<Map<String, dynamic>> _navItems = [
    {'label': 'Appointments', 'icon': Icons.calendar_today, 'route': '/user appointments'},
    {'label': 'Location', 'icon': Icons.location_on, 'route': '/location'},
    {'label': 'Home', 'icon': Icons.home, 'route': '/home'},
    {'label': 'Profile', 'icon': Icons.person, 'route': '/profile'},
    {'label': 'Request', 'icon': Icons.request_page, 'route': '/request'},
  ];

  void _onTabTapped(int index) {
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
      Navigator.pushNamed(context, _navItems[index]['route']);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  DateTime? toDateTime(dynamic value) {
    if (value == null) return null;
    if (value is DateTime) return value;
    if (value is Timestamp) return value.toDate();
    if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  String formatDate(dynamic scheduledAt) {
    final date = toDateTime(scheduledAt);
    if (date == null) return 'Date not available';
    return DateFormat('MMM d, y – h:mm a').format(date);
  }

  Widget buildStatusBadge(String status) {
    Color color;
    switch (status.toLowerCase()) {
      case 'pending':
      case 'on the way':
        color = Colors.orange;
        break;
      case 'during':
        color = Colors.blue;
        break;
      case 'complete':
        color = Colors.green;
        break;
      case 'cancelled':
        color = Colors.red;
        break;
      default:
        color = Colors.grey;
    }
    return Text(status.toUpperCase(), style: TextStyle(color: color, fontWeight: FontWeight.bold));
  }

  Widget buildAppointmentCard(Map<String, dynamic> data, {bool showCancel = false, bool showRebook = false, required bool isRequest}) {
    final scheduledAt = toDateTime(data['scheduledAt']);
    final formattedDate = scheduledAt != null ? formatDate(scheduledAt) : 'Date not available';
    final services = data['services'] as List<dynamic>? ?? [];
    final serviceType = services.isNotEmpty ? services[0]['type'] : (data['styleDescription'] ?? 'Custom Request');
    final barberId = data['barberId'];
    final bookingId = data['id'];
    final status = data['status'] ?? 'confirmed';
    final type = data['type'] ?? 'standard';
    final isRequestLocal = type == 'request';

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(barberId).get(),
      builder: (context, snapshot) {
        String barberName = 'Unknown Barber';
        if (snapshot.hasData && snapshot.data!.exists) {
          barberName = snapshot.data!['name'] ?? 'Unnamed Barber';
        }

        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.orange.withOpacity(0.2)),
          ),
          child: ListTile(
            leading: Icon(isRequest ? Icons.assignment : Icons.cut, color: Colors.orange, size: 30),
            title: Text('$serviceType with $barberName', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text(formattedDate, style: const TextStyle(color: Colors.white70)),
                const SizedBox(height: 4),
                buildStatusBadge(status),
                if (isRequest)
                  const Text('📌 Special Request', style: TextStyle(color: Colors.deepOrange, fontWeight: FontWeight.w500)),
              ],
            ),
            trailing: showCancel
                ? TextButton(
              child: const Text('Cancel', style: TextStyle(color: Colors.red)),
              onPressed: () async {
                await FirebaseFirestore.instance.collection('bookings').doc(bookingId).update({'status': 'cancelled'});
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Booking cancelled')));
              },
            )
                : showRebook
                ? TextButton(
              child: const Text('Leave a Review', style: TextStyle(color: Colors.orange)),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingDetailsScreen(bookingData: data),
                  ),
                );
              },
            )
                : null,
            onTap: () {
              if (isRequest) {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => RequestBookingDetailsScreen(
                      requestId: data['id'],
                      barberName: data['barberName'] ?? barberName,
                      preferredDate: data['preferredDate'] ?? '',
                      preferredTime: data['preferredTime'] ?? '',
                      styleDescription: data['styleDescription'] ?? '',
                      status: data['status'] ?? '',
                      price: (data['price'] ?? 0).toDouble(),
                      userId: data['userId'] ?? '',
                    ),
                  ),
                );
              } else {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => BookingDetailsScreen(bookingData: data),
                  ),
                );
              }
            },
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot> getOngoingStream() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user!.uid)
        .where('status', whereIn: ['pending', 'confirmed', 'on the way', 'during'])
        .orderBy('scheduledAt', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot> getRequestsStream() {
    return FirebaseFirestore.instance
        .collection('barberServiceRequests')
        .where('userId', isEqualTo: user!.uid)
        .where('status', whereIn: ['approved', 'pending', 'confirmed', 'on the way', 'during'])
        .orderBy('preferredDate', descending: false)
        .snapshots();
  }

  Future<List<Widget>> getHistoryWidgets() async {
    final bookingsSnap = await FirebaseFirestore.instance
        .collection('bookings')
        .where('userId', isEqualTo: user!.uid)
        .where('status', whereIn: ['complete', 'cancelled'])
        .orderBy('scheduledAt', descending: true)
        .get();

    final requestSnap = await FirebaseFirestore.instance
        .collection('barberServiceRequests')
        .where('userId', isEqualTo: user!.uid)
        .where('status', whereIn: ['complete', 'cancelled'])
        .orderBy('preferredDate', descending: true)
        .get();

    final bookings = bookingsSnap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      return buildAppointmentCard(data, isRequest: false, showRebook: true);
    }).toList();

    final requests = requestSnap.docs.map((doc) {
      final data = doc.data();
      data['id'] = doc.id;
      data['scheduledAt'] = '${data['preferredDate']} ${data['preferredTime']}';
      data['services'] = [{'type': 'Custom Request'}];
      return buildAppointmentCard(data, isRequest: true, showRebook: true);
    }).toList();

    return [...bookings, ...requests];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        title: const Text('My Appointments'),
        automaticallyImplyLeading: false,
        backgroundColor: Colors.orange,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.orange,
          labelColor: Colors.white70,
          unselectedLabelColor: Colors.white70,
          tabs: const [
            Tab(text: 'Ongoing'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          StreamBuilder<QuerySnapshot>(
            stream: getOngoingStream(),
            builder: (context, snapshot) {
              return StreamBuilder<QuerySnapshot>(
                stream: getRequestsStream(),
                builder: (context, requestSnap) {
                  if (!snapshot.hasData || !requestSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final bookings = snapshot.data!.docs.map((doc) {
                    final rawData = doc.data();
                    if (rawData == null) return null;
                    final data = rawData as Map<String, dynamic>;
                    data['id'] = doc.id;
                    return buildAppointmentCard(data, isRequest: false);
                  }).whereType<Widget>().toList();

                  final requests = requestSnap.data!.docs.map((doc) {
                    final rawData = doc.data();
                    if (rawData == null) return null;
                    final data = rawData as Map<String, dynamic>;
                    data['id'] = doc.id;
                    data['scheduledAt'] = '${data['preferredDate']} ${data['preferredTime']}';
                    data['services'] = [{'type': 'Custom Request'}];
                    return buildAppointmentCard(data, isRequest: true);
                  }).whereType<Widget>().toList();

                  final combined = [...requests, ...bookings];
                  if (combined.isEmpty) return const Center(child: Text('No upcoming appointments', style: TextStyle(color: Colors.white70)));
                  return ListView(children: combined);
                },
              );
            },
          ),
          FutureBuilder<List<Widget>>(
            future: getHistoryWidgets(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
              final items = snapshot.data!;
              if (items.isEmpty) return const Center(child: Text('No past appointments', style: TextStyle(color: Colors.white70)));
              return ListView(children: items);
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF2A2A2A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border(
            top: BorderSide(color: Colors.orange, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: const TextStyle(color: Colors.grey),
          onTap: _onTabTapped,
          items: _navItems.map((item) => BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(item['icon']),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item['icon']),
            ),
            label: item['label'],
          )).toList(),
        ),
      ),
    );
  }
}
