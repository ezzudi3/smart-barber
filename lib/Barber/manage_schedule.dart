import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ManageScheduleScreen extends StatefulWidget {
  const ManageScheduleScreen({Key? key}) : super(key: key);

  @override
  State<ManageScheduleScreen> createState() => _ManageScheduleScreenState();
}

class _ManageScheduleScreenState extends State<ManageScheduleScreen> {
  final List<String> _days = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday',
  ];

  Map<String, Map<String, String>?> workingHours = {};
  int _currentIndex = 3;  // Start with Schedule screen selected in the bottom navigation.

  @override
  void initState() {
    super.initState();
    loadScheduleData();
  }

  Future<void> loadScheduleData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    final data = doc.data();

    setState(() {
      for (var day in _days) {
        if (data?['workingHours']?[day] != null) {
          workingHours[day] = {
            'start': data!['workingHours'][day]['start'],
            'end': data['workingHours'][day]['end'],
          };
        } else {
          workingHours[day] = null;
        }
      }
    });
  }

  Future<void> pickTime(String day, bool isStart) async {
    final initialTime = TimeOfDay.now();
    final picked = await showTimePicker(context: context, initialTime: initialTime);
    if (picked != null) {
      setState(() {
        workingHours[day] ??= {'start': '', 'end': ''};
        workingHours[day]![isStart ? 'start' : 'end'] = picked.format(context);
      });
    }
  }

  Future<void> saveSchedule() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'workingHours': workingHours,
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Schedule saved!")),
    );
  }

  // Bottom Navigation Bar Navigation
  void _onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });

    // Navigate based on selected tab index
    if (index == 0) {
      Navigator.pushNamed(context, '/barb'); // Home Screen Route
    } else if (index == 1) {
      Navigator.pushNamed(context, '/barberAppointments'); // Appointments Screen Route
    } else if (index == 2) {
      Navigator.pushNamed(context, '/editProfile'); // Profile Screen Route
    } else if (index == 3) {
      // Current screen (Schedule), no action needed
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.deepPurple,
        title: const Text("Manage Schedule", style: TextStyle(fontSize: 24)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView.builder(
          itemCount: _days.length,
          itemBuilder: (context, index) {
            final day = _days[index];
            final times = workingHours[day];

            return Card(
              margin: const EdgeInsets.symmetric(vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              elevation: 4,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(day, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        Switch(
                          value: times != null,
                          onChanged: (value) {
                            setState(() {
                              workingHours[day] = value ? {'start': '', 'end': ''} : null;
                            });
                          },
                        ),
                      ],
                    ),
                    if (times != null) ...[
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Start: ${times['start'] ?? 'Not set'}', style: const TextStyle(fontSize: 16)),
                          ElevatedButton(
                            onPressed: () => pickTime(day, true),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                            child: const Text('Pick Start', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('End: ${times['end'] ?? 'Not set'}', style: const TextStyle(fontSize: 16)),
                          ElevatedButton(
                            onPressed: () => pickTime(day, false),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
                            child: const Text('Pick End', style: TextStyle(color: Colors.white, fontSize: 16)),
                          ),
                        ],
                      ),
                    ]
                  ],
                ),
              ),
            );
          },
        ),
      ),
      bottomSheet: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ElevatedButton.icon(
          onPressed: saveSchedule,
          icon: const Icon(Icons.save),
          label: const Text("Save Schedule", style: TextStyle(fontSize: 18)),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurple,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
        ),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        selectedItemColor: Colors.deepPurple,
        onTap: _onTabTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Appointments'),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule'),
        ],
      ),
    );
  }
}
