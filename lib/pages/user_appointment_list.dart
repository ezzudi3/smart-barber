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
    Color backgroundColor;
    Color textColor = Colors.white;
    IconData icon;

    switch (status.toLowerCase()) {
      case 'pending':
        backgroundColor = Colors.orange.shade600;
        icon = Icons.schedule;
        break;
      case 'on the way':
        backgroundColor = Colors.blue.shade600;
        icon = Icons.directions_car;
        break;
      case 'during':
        backgroundColor = const Color(0xFFFF6B35);
        icon = Icons.content_cut;
        break;
      case 'complete':
        backgroundColor = Colors.green.shade600;
        icon = Icons.check_circle;
        break;
      case 'cancelled':
        backgroundColor = Colors.red.shade600;
        icon = Icons.cancel;
        break;
      default:
        backgroundColor = Colors.grey.shade600;
        icon = Icons.help;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: backgroundColor.withOpacity(0.3),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: textColor, size: 14),
          const SizedBox(width: 4),
          Text(
            status.toUpperCase(),
            style: TextStyle(
              color: textColor,
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToDetailScreen(Map<String, dynamic> data, String barberName, {required bool isRequest}) {
    if (isRequest) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => RequestBookingDetailsScreen(
            requestId: data['id'],
            barberName: barberName,
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

        return GestureDetector(
          onTap: () => _navigateToDetailScreen(data, barberName, isRequest: isRequest),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.grey[800],
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  blurRadius: 15,
                  spreadRadius: 2,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: isRequest
                    ? const Color(0xFFFF6B35).withOpacity(0.3)
                    : Colors.orange.withOpacity(0.3),
                width: 1,
              ),
            ),
            child: Column(
              children: [
                // Header with gradient
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Colors.orange, Color(0xFFFF6B35)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: const BorderRadius.only(
                      topLeft: Radius.circular(20),
                      topRight: Radius.circular(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          isRequest ? Icons.assignment : Icons.content_cut,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              serviceType,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'with $barberName',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      if (isRequest)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text(
                            'REQUEST',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      // Tap to view indicator
                      Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios,
                          color: Colors.white,
                          size: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Body content
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.orange.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.schedule,
                              color: Colors.orange.shade300,
                              size: 16,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              formattedDate,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Tap hint text
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.orange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: Colors.orange.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.touch_app,
                              color: Colors.orange.shade300,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              'Tap to view details',
                              style: TextStyle(
                                color: Colors.orange.shade300,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      Row(
                        children: [
                          buildStatusBadge(status),
                          const Spacer(),
                          if (showCancel)
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.red.shade900,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.red.shade600),
                              ),
                              child: TextButton(
                                onPressed: () async {
                                  final confirmed = await showDialog<bool>(
                                    context: context,
                                    builder: (context) => AlertDialog(
                                      backgroundColor: Colors.grey[800],
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(16),
                                      ),
                                      title: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: Colors.red.shade900,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Text(
                                          'Cancel Appointment',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      content: const Text(
                                        'Are you sure you want to cancel this appointment?',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(context, false),
                                          child: const Text('No', style: TextStyle(color: Colors.grey)),
                                        ),
                                        Container(
                                          decoration: BoxDecoration(
                                            color: Colors.red,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: TextButton(
                                            onPressed: () => Navigator.pop(context, true),
                                            child: const Text(
                                              'Yes, Cancel',
                                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirmed == true) {
                                    await FirebaseFirestore.instance
                                        .collection('bookings')
                                        .doc(bookingId)
                                        .update({'status': 'cancelled'});
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                        content: const Text('Appointment cancelled successfully'),
                                        backgroundColor: Colors.red.shade600,
                                      ),
                                    );
                                  }
                                },
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            )
                          else if (showRebook)
                            Container(
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.orange, Color(0xFFFF6B35)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: TextButton(
                                onPressed: () => _navigateToDetailScreen(data, barberName, isRequest: isRequest),
                                child: const Text(
                                  'Leave Review',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
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

  Widget _buildEmptyState(String title, String subtitle, IconData icon) {
    return Center(
      child: Container(
        padding: const EdgeInsets.all(32),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.grey[800],
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 15,
              spreadRadius: 3,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.orange, Color(0xFFFF6B35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 40,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[300],
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text(
          'My Appointments',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange, Color(0xFFFF6B35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(50),
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange, Color(0xFFFF6B35)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: TabBar(
              controller: _tabController,
              indicatorColor: Colors.white,
              indicatorWeight: 3,
              labelColor: Colors.white,
              unselectedLabelColor: Colors.white70,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold),
              unselectedLabelStyle: const TextStyle(fontWeight: FontWeight.normal),
              tabs: const [
                Tab(text: 'Ongoing'),
                Tab(text: 'History'),
              ],
            ),
          ),
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
                    return Center(
                      child: Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.grey[800],
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ],
                        ),
                        child: const CircularProgressIndicator(
                          valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                        ),
                      ),
                    );
                  }

                  final bookings = snapshot.data!.docs.map((doc) {
                    final rawData = doc.data();
                    if (rawData == null) return null;
                    final data = rawData as Map<String, dynamic>;
                    data['id'] = doc.id;
                    return buildAppointmentCard(data, isRequest: false, showCancel: true);
                  }).whereType<Widget>().toList();

                  final requests = requestSnap.data!.docs.map((doc) {
                    final rawData = doc.data();
                    if (rawData == null) return null;
                    final data = rawData as Map<String, dynamic>;
                    data['id'] = doc.id;
                    data['scheduledAt'] = '${data['preferredDate']} ${data['preferredTime']}';
                    data['services'] = [{'type': 'Custom Request'}];
                    return buildAppointmentCard(data, isRequest: true, showCancel: true);
                  }).whereType<Widget>().toList();

                  final combined = [...requests, ...bookings];
                  if (combined.isEmpty) {
                    return _buildEmptyState(
                      'No Ongoing Appointments',
                      'Your upcoming appointments will appear here',
                      Icons.calendar_today,
                    );
                  }
                  return ListView(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    children: combined,
                  );
                },
              );
            },
          ),
          FutureBuilder<List<Widget>>(
            future: getHistoryWidgets(),
            builder: (context, snapshot) {
              if (!snapshot.hasData) {
                return Center(
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.grey[800],
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.grey.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFFF6B35)),
                    ),
                  ),
                );
              }
              final items = snapshot.data!;
              if (items.isEmpty) {
                return _buildEmptyState(
                  'No Past Appointments',
                  'Your completed and cancelled appointments will appear here',
                  Icons.history,
                );
              }
              return ListView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                children: items,
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.grey[900],
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.3),
              blurRadius: 10,
              spreadRadius: 2,
              offset: const Offset(0, -2),
            ),
          ],
          border: const Border(
            top: BorderSide(
              color: Colors.orange,
              width: 2,
            ),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: const Color(0xFFFF6B35),
          unselectedItemColor: Colors.grey[400],
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 12,
          ),
          unselectedLabelStyle: TextStyle(
            color: Colors.grey[400],
            fontSize: 12,
          ),
          onTap: _onTabTapped,
          items: _navItems.map((item) => BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              child: Icon(
                item['icon'],
                size: 20,
              ),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.orange, Color(0xFFFF6B35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Icon(
                item['icon'],
                color: Colors.white,
                size: 20,
              ),
            ),
            label: item['label'],
          )).toList(),
        ),
      ),
    );
  }
}