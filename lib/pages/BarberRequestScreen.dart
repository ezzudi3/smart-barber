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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('User not logged in', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
      return;
    }

    if (!_formKey.currentState!.validate() ||
        selectedBarberId == null ||
        selectedDate == null ||
        selectedTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Please complete all fields', style: TextStyle(color: Colors.white)),
          backgroundColor: Colors.red.shade400,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Request submitted successfully!', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.green.shade400,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
    Navigator.pop(context);
  }

  Future<void> pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: DateTime(now.year + 1),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedDate = picked);
  }

  Future<void> pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) setState(() => selectedTime = picked);
  }

  void _onTabTapped(int index) {
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
      Navigator.pushNamed(context, _navItems[index]['route']);
    }
  }

  Widget _buildSectionHeader(String title, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Colors.orange, Color(0xFFFF6B35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGradientButton({
    required VoidCallback onPressed,
    required String text,
    required IconData icon,
    bool isSecondary = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        gradient: isSecondary
            ? const LinearGradient(
          colors: [Color(0xFFFFD700), Colors.orange],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : const LinearGradient(
          colors: [Colors.orange, Color(0xFFFF6B35)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.4),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: Colors.white),
        label: Text(text, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF1A1A1A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            // Custom App Bar with Gradient
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10,
                bottom: 20,
                left: 20,
                right: 20,
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Colors.orange, Color(0xFFFF6B35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(30),
                  bottomRight: Radius.circular(30),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange,
                    blurRadius: 20,
                    offset: Offset(0, 5),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.content_cut, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 15),
                  const Expanded(
                    child: Text(
                      'Custom Barber Request',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Form(
                  key: _formKey,
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(25),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.orange.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(25),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Barber Selection Section
                          _buildSectionHeader('Select Preferred Barber', Icons.person),
                          const SizedBox(height: 15),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(15),
                              color: Colors.orange.withOpacity(0.05),
                            ),
                            child: DropdownButtonFormField<String>(
                              value: selectedBarberId,
                              decoration: const InputDecoration(
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              ),
                              hint: Text('Choose a barber', style: TextStyle(color: Colors.grey.shade600)),
                              items: availableBarbers.map((barber) {
                                return DropdownMenuItem<String>(
                                  value: barber['id'],
                                  child: Text(barber['name'], style: const TextStyle(color: Colors.black87)),
                                  onTap: () => selectedBarberName = barber['name'],
                                );
                              }).toList(),
                              onChanged: (value) {
                                setState(() => selectedBarberId = value);
                              },
                              validator: (value) => value == null ? 'Please select a barber' : null,
                              dropdownColor: Colors.white,
                              style: const TextStyle(color: Colors.black87),
                              iconEnabledColor: Colors.orange,
                            ),
                          ),

                          const SizedBox(height: 25),

                          // Date & Time Section
                          _buildSectionHeader('Preferred Date & Time', Icons.schedule),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              Expanded(
                                child: _buildGradientButton(
                                  onPressed: pickDate,
                                  text: selectedDate == null
                                      ? 'Select Date'
                                      : "${selectedDate!.day}/${selectedDate!.month}/${selectedDate!.year}",
                                  icon: Icons.date_range,
                                  isSecondary: true,
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: _buildGradientButton(
                                  onPressed: pickTime,
                                  text: selectedTime == null
                                      ? 'Select Time'
                                      : "${selectedTime!.hour.toString().padLeft(2, '0')}:${selectedTime!.minute.toString().padLeft(2, '0')}",
                                  icon: Icons.access_time,
                                  isSecondary: true,
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 25),

                          // Style Description Section
                          _buildSectionHeader('Style Description', Icons.content_cut),
                          const SizedBox(height: 15),
                          Container(
                            decoration: BoxDecoration(
                              border: Border.all(color: Colors.orange.withOpacity(0.3)),
                              borderRadius: BorderRadius.circular(15),
                              color: Colors.orange.withOpacity(0.05),
                            ),
                            child: TextFormField(
                              controller: _styleDescController,
                              maxLines: 4,
                              style: const TextStyle(color: Colors.black87),
                              decoration: InputDecoration(
                                hintText: 'Describe your desired style (e.g., fade with design, beard trim, etc.)',
                                hintStyle: TextStyle(color: Colors.grey.shade600),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.all(16),
                              ),
                              validator: (val) => val == null || val.isEmpty ? 'Please describe your style' : null,
                            ),
                          ),

                          const SizedBox(height: 35),

                          // Submit Button
                          Center(
                            child: Container(
                              width: double.infinity,
                              height: 55,
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  colors: [Colors.orange, Color(0xFFFF6B35)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.5),
                                    blurRadius: 15,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton.icon(
                                onPressed: submitRequest,
                                icon: const Icon(Icons.send_rounded, color: Colors.white, size: 22),
                                label: const Text(
                                  'Submit Request',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [Colors.black, Color(0xFF2A2A2A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.orange.withOpacity(0.2),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.white.withOpacity(0.6),
          backgroundColor: Colors.transparent,
          onTap: _onTabTapped,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.w600),
          items: _navItems.map((item) => BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: _selectedIndex == _navItems.indexOf(item)
                    ? const LinearGradient(
                  colors: [Colors.orange, Color(0xFFFF6B35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
                    : null,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                item['icon'],
                color: _selectedIndex == _navItems.indexOf(item) ? Colors.white : Colors.white.withOpacity(0.6),
              ),
            ),
            label: item['label'],
          )).toList(),
        ),
      ),
    );
  }
}