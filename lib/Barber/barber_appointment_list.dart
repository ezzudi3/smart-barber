import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class BarberAppointmentList extends StatefulWidget {
  const BarberAppointmentList({Key? key}) : super(key: key);

  @override
  State<BarberAppointmentList> createState() => _BarberAppointmentListState();
}

class _BarberAppointmentListState extends State<BarberAppointmentList> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final barberId = FirebaseAuth.instance.currentUser!.uid;
  int _currentIndex = 1;

  final List<Map<String, dynamic>> _navItems = [
    {'label': 'Home', 'icon': Icons.home, 'route': '/barb'},
    {'label': 'Appointments', 'icon': Icons.calendar_today, 'route': '/barberAppointments'},
    {'label': 'Profile', 'icon': Icons.person, 'route': '/editProfile'},
    {'label': 'Schedule', 'icon': Icons.schedule, 'route': '/schedule'},
  ];

  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
      Navigator.pushNamed(context, _navItems[index]['route']);
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  DateTime? toDateTime(dynamic value) {
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
    if (date == null) return 'Invalid date';
    return DateFormat('MMM d, y – h:mm a').format(date);
  }

  Widget buildBookingCard(Map<String, dynamic> data, {bool isRequest = false}) {
    final scheduledAt = formatDate(data['scheduledAt']);
    final services = (data['services'] ?? []) as List<dynamic>;
    final serviceType = services.isNotEmpty ? services[0]['type'] : 'No service';
    final userId = data['userId'];
    final requestId = data['id'];
    final status = data['status'];

    return FutureBuilder<DocumentSnapshot>(
      future: FirebaseFirestore.instance.collection('users').doc(userId).get(),
      builder: (context, snapshot) {
        String userName = 'Unknown User';
        String phone = '';
        if (snapshot.hasData && snapshot.data!.exists) {
          final userData = snapshot.data!.data() as Map<String, dynamic>;
          userName = userData['name'] ?? 'Unnamed';
          phone = userData['phone'] ?? '';
        }

        return Card(
          color: isRequest ? Colors.deepOrange.shade50 : null,
          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: ListTile(
            leading: const Icon(Icons.cut),
            title: Text(isRequest ? 'Request from $userName' : '$serviceType for $userName'),
            subtitle: Text(scheduledAt),
            trailing: phone.isNotEmpty
                ? IconButton(
              icon: const FaIcon(FontAwesomeIcons.whatsapp, color: Colors.green),
              onPressed: () async {
                final url = Uri.parse("https://wa.me/$phone?text=Hi%20I%20am%20your%20barber!");
                if (await canLaunchUrl(url)) {
                  await launchUrl(url, mode: LaunchMode.externalApplication);
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Could not launch WhatsApp')),
                  );
                }
              },
            )
                : const Text('No contact'),
            onTap: () {
              if (isRequest) {
                Navigator.pushNamed(
                  context,
                  '/requestAppointmentDetail',
                  arguments: data,
                );
              } else {
                Navigator.pushNamed(
                  context,
                  '/barberAppointmentDetails',
                  arguments: data,
                );
              }
            },
          ),
        );
      },
    );
  }

  Stream<QuerySnapshot> getBookingsStream() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('barberId', isEqualTo: barberId)
        .where('status', whereIn: ['pending', 'confirmed', 'on the way', 'during'])
        .orderBy('scheduledAt', descending: false)
        .snapshots();
  }

  Stream<QuerySnapshot> getRequestsStream() {
    return FirebaseFirestore.instance
        .collection('barberServiceRequests')
        .where('barberId', isEqualTo: barberId)
        .where('status', whereIn: ['approved', 'pending', 'confirmed', 'on the way', 'during'])
        .snapshots();
  }

  Stream<QuerySnapshot> getHistoryBookingsStream() {
    return FirebaseFirestore.instance
        .collection('bookings')
        .where('barberId', isEqualTo: barberId)
        .where('status', whereIn: ['complete', 'cancelled'])
        .orderBy('scheduledAt', descending: true)
        .snapshots();
  }

  Stream<QuerySnapshot> getHistoryRequestsStream() {
    return FirebaseFirestore.instance
        .collection('barberServiceRequests')
        .where('barberId', isEqualTo: barberId)
        .where('status', whereIn: ['complete', 'cancelled'])
        .snapshots();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Your Appointments'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Ongoing'),
            Tab(text: 'History'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // Ongoing Tab: combine standard + request
          StreamBuilder<QuerySnapshot>(
            stream: getBookingsStream(),
            builder: (context, bookingSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: getRequestsStream(),
                builder: (context, requestSnap) {
                  if (!bookingSnap.hasData || !requestSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final bookings = bookingSnap.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    return buildBookingCard(data);
                  }).toList();

                  final requests = requestSnap.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    data['scheduledAt'] = '${data['preferredDate']} ${data['preferredTime']}';
                    data['services'] = [{'type': 'Custom Request'}];
                    return buildBookingCard(data, isRequest: true);
                  }).toList();

                  final combined = [...requests, ...bookings];

                  if (combined.isEmpty) return const Center(child: Text('No upcoming appointments'));
                  return ListView(children: combined);
                },
              );
            },
          ),
          // History Tab: combine completed/cancelled requests and bookings
          StreamBuilder<QuerySnapshot>(
            stream: getHistoryBookingsStream(),
            builder: (context, bookingSnap) {
              return StreamBuilder<QuerySnapshot>(
                stream: getHistoryRequestsStream(),
                builder: (context, requestSnap) {
                  if (!bookingSnap.hasData || !requestSnap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final bookings = bookingSnap.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    return buildBookingCard(data);
                  }).toList();

                  final requests = requestSnap.data!.docs.map((doc) {
                    final data = doc.data() as Map<String, dynamic>;
                    data['id'] = doc.id;
                    data['scheduledAt'] = '${data['preferredDate']} ${data['preferredTime']}';
                    data['services'] = [{'type': 'Custom Request'}];
                    return buildBookingCard(data, isRequest: true);
                  }).toList();

                  final combined = [...requests, ...bookings];

                  if (combined.isEmpty) return const Center(child: Text('No past appointments'));
                  return ListView(children: combined);
                },
              );
            },
          ),
        ],
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
}
