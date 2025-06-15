import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BarberRequestScreen extends StatefulWidget {
  const BarberRequestScreen({Key? key}) : super(key: key);

  @override
  State<BarberRequestScreen> createState() => _BarberRequestScreenState();
}

class _BarberRequestScreenState extends State<BarberRequestScreen> {
  final _formKey = GlobalKey<FormState>();
  String? selectedBarberId;
  String? selectedBarberName;
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  final TextEditingController _styleDescController = TextEditingController();
  List<Map<String, dynamic>> availableBarbers = [];
  int _selectedIndex = 4; // Request tab index

  final List<Map<String, dynamic>> _navItems = [
    {'label': 'Appointments', 'icon': Icons.calendar_today, 'route': '/user appointments'},
    {'label': 'Location', 'icon': Icons.location_on, 'route': '/location'},
    {'label': 'Home', 'icon': Icons.home, 'route': '/home'},
    {'label': 'Profile', 'icon': Icons.person, 'route': '/profile'},
    {'label': 'Request', 'icon': Icons.request_page, 'route': '/request'},
  ];

  @override
  void initState() {
    super.initState();
    loadBarbers();
  }

  Future<void> loadBarbers() async {
    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'barber')
        .get();

    setState(() {
      availableBarbers = snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          'name': doc['name'] ?? 'Unnamed Barber',
        };
      }).toList();
    });
  }

  Future<void> submitRequest() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User not logged in')));
      return;
    }

    if (!_formKey.currentState!.validate() ||
        selectedBarberId == null ||
        selectedDate == null ||
        selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please complete all fields')));
      return;
    }

    final dateStr = "${selectedDate!.year}-${selectedDate!.month.toString().padLeft(2, '0')}-${selectedDate!.day.toString().padLeft(2, '0')}";
    final timeStr = "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}";

    final userData = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
    final userName = userData['name'] ?? '';

    final requestRef = await FirebaseFirestore.instance.collection('barberServiceRequests').add({
      'userId': user.uid,
      'userName': userName,
      'barberId': selectedBarberId,
      'barberName': selectedBarberName,
      'preferredDate': dateStr,
      'preferredTime': timeStr,
      'styleDescription': _styleDescController.text.trim(),
      'status': 'pending',
      'timestamp': FieldValue.serverTimestamp(),
    });

    await FirebaseFirestore.instance.collection('notifications').add({
      'recipientId': selectedBarberId,
      'title': 'New Service Request',
      'message': '$userName requested a custom service on $dateStr at $timeStr.',
      'type': 'service_request',
      'requestId': requestRef.id,
      'isRead': false,
      'timestamp': FieldValue.serverTimestamp(),
    });

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Request submitted successfully!')));
    Navigator.pop(context);
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  void _onTabTapped(int index) {
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
      Navigator.pushNamed(context, _navItems[index]['route']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.orange,
        title: const Text('Custom Barber Request', style: TextStyle(color: Colors.white)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Card(
            color: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 8,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('👨‍🔧 Select Preferred Barber', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    value: selectedBarberId,
                    decoration: const InputDecoration(
                      border: OutlineInputBorder(),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    hint: const Text('Choose a barber'),
                    items: availableBarbers.map((barber) {
                      return DropdownMenuItem<String>(
                        value: barber['id'],
                        child: Text(barber['name']),
                        onTap: () => selectedBarberName = barber['name'],
                      );
                    }).toList(),
                    onChanged: (value) {
                      setState(() => selectedBarberId = value);
                    },
                    validator: (value) => value == null ? 'Please select a barber' : null,
                  ),

                  const SizedBox(height: 20),
                  const Text('📅 Preferred Date & Time', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: pickDate,
                          icon: const Icon(Icons.date_range),
                          label: Text(selectedDate == null
                              ? 'Select Date'
                              : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: pickTime,
                          icon: const Icon(Icons.access_time),
                          label: Text(selectedTime == null
                              ? 'Select Time'
                              : "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}"),
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  const Text('✂️ Style Description', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  TextFormField(
                    controller: _styleDescController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      hintText: 'Describe your style (e.g. fade with design)',
                      border: OutlineInputBorder(),
                    ),
                    validator: (val) => val == null || val.isEmpty ? 'Please describe your style' : null,
                  ),

                  const SizedBox(height: 30),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: submitRequest,
                      icon: const Icon(Icons.send),
                      label: const Text('Submit Request'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.deepPurple,
                        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 28),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  )
                ],
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.orange,
        unselectedItemColor: Colors.white,
        backgroundColor: Colors.black,
        onTap: _onTabTapped,
        type: BottomNavigationBarType.fixed,
        items: _navItems.map((item) => BottomNavigationBarItem(
          icon: Icon(item['icon']),
          label: item['label'],
        )).toList(),
      ),
    );
  }
}
