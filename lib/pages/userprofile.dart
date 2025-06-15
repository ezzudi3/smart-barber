import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class UserProfileScreen extends StatefulWidget {
  const UserProfileScreen({Key? key}) : super(key: key);

  @override
  State<UserProfileScreen> createState() => _UserProfileScreenState();
}

class _UserProfileScreenState extends State<UserProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  String _gender = 'Male';
  String _preferredHairstyle = '';
  String _paymentMethod = '';
  String? _profileImageUrl;
  String _role = 'user';
  final ImagePicker _picker = ImagePicker();
  Timestamp? _lastPasswordChange;
  bool _canChangePassword = true;

  int _selectedIndex = 3;
  final List<Map<String, dynamic>> _navItems = [
    {'label': 'Appointments', 'icon': Icons.calendar_today, 'route': '/user appointments'},
    {'label': 'Location', 'icon': Icons.location_on, 'route': '/location'},
    {'label': 'Home', 'icon': Icons.home, 'route': '/home'},
    {'label': 'Profile', 'icon': Icons.person, 'route': '/profile'},
    {'label': 'Request', 'icon': Icons.request_page, 'route': '/request'},
  ];

  final List<String> _hairstyleOptions = ['Fade', 'Pompadour', 'Undercut', 'Buzz Cut', 'Afro', 'Layered'];
  final List<String> _paymentOptions = ['Credit/Debit Card', 'Online Banking', 'Cash'];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data();
      setState(() {
        _nameController.text = data?['name'] ?? '';
        _phoneController.text = data?['phone'] ?? '';
        _gender = data?['gender'] ?? 'Male';
        _preferredHairstyle = data?['preferredHairstyle'] ?? '';
        _paymentMethod = data?['paymentMethod'] ?? '';
        _profileImageUrl = data?['image'];
        _role = data?['role'] ?? 'user';
        _lastPasswordChange = data?['lastPasswordChange'];
      });
      _checkPasswordChangeEligibility();
    }
  }

  void _checkPasswordChangeEligibility() {
    if (_lastPasswordChange != null) {
      final lastChange = _lastPasswordChange!.toDate();
      final now = DateTime.now();
      final difference = now.difference(lastChange).inDays;
      setState(() {
        _canChangePassword = difference >= 7;
      });
    }
  }

  Future<void> _pickProfileImage() async {
    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final ref = FirebaseStorage.instance.ref().child('users/$uid/profile.jpg');
    await ref.putFile(File(image.path));
    final downloadUrl = await ref.getDownloadURL();

    setState(() => _profileImageUrl = downloadUrl);

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'image': downloadUrl,
    });
  }
  void _showChangePasswordDialog() {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Change Password', style: TextStyle(color: Colors.orangeAccent)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: currentPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Current Password',
                labelStyle: TextStyle(color: Colors.orangeAccent),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: newPasswordController,
              obscureText: true,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'New Password',
                labelStyle: TextStyle(color: Colors.orangeAccent),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            child: const Text('Cancel', style: TextStyle(color: Colors.orangeAccent)),
            onPressed: () => Navigator.of(context).pop(),
          ),
          TextButton(
            child: const Text('Change', style: TextStyle(color: Colors.orangeAccent)),
            onPressed: () async {
              final user = FirebaseAuth.instance.currentUser;
              final cred = EmailAuthProvider.credential(
                email: user!.email!,
                password: currentPasswordController.text,
              );

              try {
                await user.reauthenticateWithCredential(cred);
                await user.updatePassword(newPasswordController.text);
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(user.uid)
                    .update({'lastPasswordChange': Timestamp.now()});

                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Password changed successfully')),
                );
              } catch (e) {
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Error: ${e.toString()}')),
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Future<void> _saveUserProfile() async {
    if (_formKey.currentState?.validate() != true) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({
        'name': _nameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'gender': _gender,
        'preferredHairstyle': _preferredHairstyle,
        'paymentMethod': _paymentMethod,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    }
  }


  Future<void> _switchUserRole() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    if (_role == 'user') {
      Navigator.pushNamed(context, '/barberApplication');
    } else {
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'role': 'user'});
      setState(() => _role = 'user');
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/home');
    }
  }
  void _showFeedbackDialog() {
    final TextEditingController feedbackController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Submit Feedback', style: TextStyle(color: Colors.orangeAccent)),
        content: TextField(
          controller: feedbackController,
          maxLines: 4,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Type your feedback here...',
            hintStyle: TextStyle(color: Colors.white70),
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.orangeAccent)),
          ),
          TextButton(
            onPressed: () async {
              final feedback = feedbackController.text.trim();
              if (feedback.isNotEmpty) {
                final uid = FirebaseAuth.instance.currentUser?.uid;
                if (uid != null) {
                  await FirebaseFirestore.instance.collection('feedback').add({
                    'uid': uid,
                    'feedback': feedback,
                    'timestamp': Timestamp.now(),
                  });
                }
                Navigator.of(context).pop();
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Thanks for your feedback!')),
                );
              }
            },
            child: const Text('Submit', style: TextStyle(color: Colors.orangeAccent)),
          ),
        ],
      ),
    );
  }


  Future<void> _logout() async {
    final shouldLogout = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text('Logout', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to log out?', style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Logout')),
        ],
      ),
    );

    if (shouldLogout == true) {
      await FirebaseAuth.instance.signOut();
      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _onTabTapped(int index) {
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
      Navigator.pushNamed(context, _navItems[index]['route']);
    }
  }

  @override
  Widget build(BuildContext context) {
    final int daysLeft = _lastPasswordChange == null
        ? 0
        : 7 - DateTime.now().difference(_lastPasswordChange!.toDate()).inDays;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('User Profile', style: TextStyle(color: Colors.orangeAccent)),
        actions: [IconButton(icon: const Icon(Icons.logout, color: Colors.orangeAccent), onPressed: _logout)],
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    CircleAvatar(
                      radius: 50,
                      backgroundImage: _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
                      child: _profileImageUrl == null ? const Icon(Icons.person, size: 50, color: Colors.white) : null,
                    ),
                    IconButton(
                      icon: const Icon(Icons.camera_alt, color: Colors.orangeAccent),
                      onPressed: _pickProfileImage,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Full Name',
                  labelStyle: TextStyle(color: Colors.orangeAccent),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter your name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(
                  labelText: 'Phone Number',
                  labelStyle: TextStyle(color: Colors.orangeAccent),
                  enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.orangeAccent)),
                ),
                validator: (value) => value == null || value.isEmpty ? 'Please enter your phone number' : null,
              ),
              const SizedBox(height: 16),
              const Text('Gender', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white)),
              Row(
                children: [
                  Expanded(child: RadioListTile(title: const Text('Male', style: TextStyle(color: Colors.white)), value: 'Male', groupValue: _gender, onChanged: (value) => setState(() => _gender = value!))),
                  Expanded(child: RadioListTile(title: const Text('Female', style: TextStyle(color: Colors.white)), value: 'Female', groupValue: _gender, onChanged: (value) => setState(() => _gender = value!))),
                ],
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: Colors.white),
                value: _preferredHairstyle.isNotEmpty ? _preferredHairstyle : null,
                decoration: const InputDecoration(labelText: 'Preferred Hairstyle', labelStyle: TextStyle(color: Colors.orangeAccent)),
                items: _hairstyleOptions.map((style) => DropdownMenuItem(value: style, child: Text(style))).toList(),
                onChanged: (value) => setState(() => _preferredHairstyle = value ?? ''),
                validator: (value) => value == null || value.isEmpty ? 'Select a hairstyle' : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                dropdownColor: Colors.grey[900],
                style: const TextStyle(color: Colors.white),
                value: _paymentMethod.isNotEmpty ? _paymentMethod : null,
                decoration: const InputDecoration(labelText: 'Setup Payment Method', labelStyle: TextStyle(color: Colors.orangeAccent)),
                items: _paymentOptions.map((method) => DropdownMenuItem(value: method, child: Text(method))).toList(),
                onChanged: (value) => setState(() => _paymentMethod = value ?? ''),
                validator: (value) => value == null || value.isEmpty ? 'Select a payment method' : null,
              ),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: _saveUserProfile,
                icon: const Icon(Icons.save, color: Colors.white70),
                label: const Text('Save Profile', style: TextStyle(color: Colors.white70)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _switchUserRole,
                icon: const Icon(Icons.switch_account, color: Colors.white70),
                label: Text(_role == 'user' ? 'Switch to Barber Mode' : 'Switch to User Mode', style: const TextStyle(color: Colors.white70)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 16)),

              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _showFeedbackDialog,
                icon: const Icon(Icons.feedback, color: Colors.white70),
                label: const Text('Give Feedback', style: TextStyle(color: Colors.white70)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 16)),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _canChangePassword ? _showChangePasswordDialog : null,
                icon: const Icon(Icons.lock, color: Colors.white70),
                label: Text(_canChangePassword ? 'Change Password' : 'Next password change in ${daysLeft.clamp(0, 7)} day(s)', style: const TextStyle(color: Colors.white70)),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, padding: const EdgeInsets.symmetric(vertical: 16)),

              ),
            ],
          ),
        ),
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
          unselectedLabelStyle: TextStyle(color: Colors.grey),

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
