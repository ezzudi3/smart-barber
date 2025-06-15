// Main Admin Dashboard with Bottom Navigation
import 'package:flutter/material.dart';
import 'package:barberapp1/Admin/AnalyticsOverviewScreen.dart';
import 'package:barberapp1/Admin/AdminUserManagementScreen.dart';
import 'package:barberapp1/Admin/AdminReviewBarberApplicationsScreen.dart';
import 'package:barberapp1/Admin/AdminBookingManagementScreen.dart';
import 'package:barberapp1/Admin/AdminFeedbackScreen.dart';
import 'package:barberapp1/Admin/AdminSettingsScreen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  int _selectedIndex = 0;

  final List<Widget> _pages = [
    AnalyticsOverviewScreen(),
    AdminUserManagementScreen(),
    AdminReviewBarberApplicationsScreen(),
    AdminBookingManagementScreen(),
    AdminFeedbackScreen(),
    AdminSettingsScreen(),
  ];

  final List<String> _titles = [
    'Analytics & Overview',
    'User Management',
    'Review Barber Applications',
    'Booking Management',
    'Feedback',
    'Settings'
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_titles[_selectedIndex]),
        backgroundColor: Colors.deepPurple,
      ),
      body: _pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard), label: 'Analytics & Overview'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people), label: 'Users'),
          BottomNavigationBarItem(
              icon: Icon(Icons.how_to_reg), label: 'Barbers'),
          BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today), label: 'Booking'),
          BottomNavigationBarItem(
              icon: Icon(Icons.feedback), label: 'Feedback'),
          BottomNavigationBarItem(
              icon: Icon(Icons.settings), label: 'Settings'),
        ],
      ),
    );
  }
}
