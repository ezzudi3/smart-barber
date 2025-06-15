import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({Key? key}) : super(key: key);

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  String adminName = 'Loading...';
  String adminEmail = 'Loading...';
  final TextEditingController nameController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadAdminData();
  }

  // Fetch admin name and email
  Future<void> _loadAdminData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      setState(() {
        adminName = doc.data()?['FirstName'] ?? 'Admin';
        adminEmail = user.email ?? 'No email';
        nameController.text = adminName; // Pre-populate the name field
      });
    }
  }

  // Logout function
  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.of(context).pushReplacementNamed('/adminLogin');
    }
  }

  // Update admin name function
  Future<void> _updateAdminName() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null && nameController.text.isNotEmpty) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
          'FirstName': nameController.text,
        });
        setState(() {
          adminName = nameController.text;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Admin name updated successfully")),
        );
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Welcome message
          Text('👤 Welcome, $adminName',
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          // Admin name update
          Text('Admin Email: $adminEmail', style: const TextStyle(fontSize: 16)),
          const SizedBox(height: 20),
          TextField(
            controller: nameController,
            decoration: const InputDecoration(
              labelText: 'Update Admin Name',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: _updateAdminName,
            style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            child: const Text('Update Name'),
          ),
          const Divider(),
          // Logout Option
          ListTile(
            leading: const Icon(Icons.logout),
            title: const Text('Logout'),
            onTap: _logout,
          ),
          const Divider(),
          // Add more settings options here if needed (e.g., change password, etc.)
        ],
      ),
    );
  }
}
