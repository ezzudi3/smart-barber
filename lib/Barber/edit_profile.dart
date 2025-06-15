import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:permission_handler/permission_handler.dart';

class EditBarberProfileScreen extends StatefulWidget {
  const EditBarberProfileScreen({Key? key}) : super(key: key);

  @override
  State<EditBarberProfileScreen> createState() => _EditBarberProfileScreenState();
}

class _EditBarberProfileScreenState extends State<EditBarberProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  final List<String> _availableSpecialties = [
    'Haircut',
    'Beard Trim',
    'Shave',
    'Fade',
    'Coloring',
  ];

  List<Map<String, dynamic>> _specialties = [];
  String? _profileImageUrl;
  List<String> _galleryUrls = [];
  final ImagePicker _picker = ImagePicker();
  Timestamp? _lastPasswordChange;
  bool _canChangePassword = true;


  int _currentIndex = 2;
  final List<Map<String, dynamic>> _navItems = [
    {'label': 'Home', 'icon': Icons.home, 'route': '/barb'},
    {'label': 'Appointments', 'icon': Icons.calendar_today, 'route': '/barberAppointments'},
    {'label': 'Profile', 'icon': Icons.person, 'route': '/editProfile'},
    {'label': 'Schedule', 'icon': Icons.schedule, 'route': '/schedule'},
  ];

  @override
  void initState() {
    super.initState();
    loadProfileData();
  }

  Future<void> loadProfileData() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    final doc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (doc.exists) {
      final data = doc.data();
      setState(() {
        _nameController.text = data?['name'] ?? '';
        _bioController.text = data?['bio'] ?? '';
        _experienceController.text = data?['experience'] ?? '';
        _phoneController.text = data?['phone'] ?? '';
        _profileImageUrl = data?['image'];
        _galleryUrls = List<String>.from(data?['gallery'] ?? []);
        final loadedSpecialties = data?['specialties'] ?? [];
        _specialties = List<Map<String, dynamic>>.from(loadedSpecialties);
        _lastPasswordChange = data?['lastPasswordChange'];
        _checkPasswordChangeEligibility();

      });
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


  Future<bool> requestStoragePermission() async {
    var status = await Permission.photos.request();
    if (!status.isGranted) {
      status = await Permission.storage.request();
    }

    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Storage permission denied')),
      );
      return false;
    }

    return true;
  }

  Future<void> pickProfileImage() async {
    final granted = await requestStoragePermission();
    if (!granted) return;

    final XFile? image = await _picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final storageRef = FirebaseStorage.instance.ref().child('barbers/$uid/profile.jpg');
    await storageRef.putFile(File(image.path));

    final downloadUrl = await storageRef.getDownloadURL();
    setState(() => _profileImageUrl = downloadUrl);

    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'image': downloadUrl,
    });
  }

  Future<void> deleteProfilePhoto() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || _profileImageUrl == null) return;

    try {
      final ref = FirebaseStorage.instance.refFromURL(_profileImageUrl!);
      await ref.delete();

      await FirebaseFirestore.instance.collection('users').doc(uid).update({'image': null});
      setState(() => _profileImageUrl = null);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error deleting profile photo')));
    }
  }

  Future<void> pickGalleryImages() async {
    final granted = await requestStoragePermission();
    if (!granted) return;

    final List<XFile> images = await _picker.pickMultiImage();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    for (final img in images) {
      final file = File(img.path);
      final fileName = DateTime.now().millisecondsSinceEpoch.toString();
      final ref = FirebaseStorage.instance.ref().child('barbers/$uid/gallery/$fileName.jpg');
      await ref.putFile(file);
      final downloadUrl = await ref.getDownloadURL();
      _galleryUrls.add(downloadUrl);
    }

    setState(() {});
    await FirebaseFirestore.instance.collection('users').doc(uid).update({
      'gallery': _galleryUrls,
    });
  }

  Future<void> deleteGalleryPhoto(String url) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final ref = FirebaseStorage.instance.refFromURL(url);
      await ref.delete();

      _galleryUrls.remove(url);
      await FirebaseFirestore.instance.collection('users').doc(uid).update({'gallery': _galleryUrls});
      setState(() {});
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error deleting gallery image')));
    }
  }

  Future<void> saveBarberProfile() async {
    if (!_formKey.currentState!.validate()) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not logged in.")));
      return;
    }

    final List<String> specialtyTypes = _specialties.map((s) => s['type'] as String).toList();

    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'name': _nameController.text,
      'bio': _bioController.text,
      'experience': _experienceController.text,
      'phone': _phoneController.text,
      'specialties': _specialties,
      'specialtyTypes': specialtyTypes, // ✅ New field for filtering
      'role': 'barber',
    }, SetOptions(merge: true));

    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile saved!")));
  }
  Future<void> _showChangePasswordDialog() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    bool showCurrentPassword = false;
    bool showNewPassword = false;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text('Change Password'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: currentPasswordController,
                  obscureText: !showCurrentPassword,
                  decoration: InputDecoration(
                    labelText: 'Current Password',
                    suffixIcon: IconButton(
                      icon: Icon(showCurrentPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => showCurrentPassword = !showCurrentPassword),
                    ),
                  ),
                ),
                TextField(
                  controller: newPasswordController,
                  obscureText: !showNewPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    suffixIcon: IconButton(
                      icon: Icon(showNewPassword ? Icons.visibility_off : Icons.visibility),
                      onPressed: () => setDialogState(() => showNewPassword = !showNewPassword),
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
              TextButton(
                onPressed: () async {
                  final user = FirebaseAuth.instance.currentUser;
                  final email = user?.email;
                  final currentPassword = currentPasswordController.text.trim();
                  final newPassword = newPasswordController.text.trim();

                  if (email == null || currentPassword.isEmpty || newPassword.isEmpty) return;

                  try {
                    final cred = EmailAuthProvider.credential(email: email, password: currentPassword);
                    await user!.reauthenticateWithCredential(cred);
                    await user.updatePassword(newPassword);

                    final uid = user.uid;
                    await FirebaseFirestore.instance.collection('users').doc(uid).update({
                      'lastPasswordChange': Timestamp.now(),
                    });

                    if (!mounted) return;
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Password changed successfully.')),
                    );

                    setState(() {
                      _canChangePassword = false;
                      _lastPasswordChange = Timestamp.now();
                    });
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Failed: ${e.toString()}')),
                    );
                  }
                },
                child: const Text('Change'),
              ),
            ],
          ),
        );
      },
    );
  }


  void _onTabTapped(int index) {
    if (index != _currentIndex) {
      setState(() => _currentIndex = index);
      Navigator.pushNamed(context, _navItems[index]['route']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Profile'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              Center(
                child: Column(
                  children: [
                    Stack(
                      alignment: Alignment.topRight,
                      children: [
                        CircleAvatar(
                          radius: 50,
                          backgroundImage: _profileImageUrl != null ? NetworkImage(_profileImageUrl!) : null,
                          child: _profileImageUrl == null ? const Icon(Icons.person, size: 50) : null,
                        ),
                        if (_profileImageUrl != null)
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: deleteProfilePhoto,
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ElevatedButton.icon(
                      onPressed: pickProfileImage,
                      icon: const Icon(Icons.image),
                      label: const Text('Change Profile Picture'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.teal,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                onPressed: pickGalleryImages,
                icon: const Icon(Icons.collections),
                label: const Text('Upload Gallery Photos'),
              ),
              const SizedBox(height: 16),
              const Text("Gallery", style: TextStyle(fontWeight: FontWeight.bold)),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _galleryUrls.length,
                  itemBuilder: (context, index) {
                    final url = _galleryUrls[index];
                    return Stack(
                      children: [
                        Container(
                          margin: const EdgeInsets.all(8),
                          width: 100,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(8),
                            image: DecorationImage(image: NetworkImage(url), fit: BoxFit.cover),
                          ),
                        ),
                        Positioned(
                          top: 0,
                          right: 0,
                          child: IconButton(
                            icon: const Icon(Icons.cancel, color: Colors.red),
                            onPressed: () => deleteGalleryPhoto(url),
                          ),
                        )
                      ],
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
                validator: (value) => value == null || value.isEmpty ? 'Enter your name' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _phoneController,
                decoration: const InputDecoration(labelText: 'Phone Number'),
                keyboardType: TextInputType.phone,
                validator: (value) => value == null || value.isEmpty ? 'Enter your phone number' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _experienceController,
                decoration: const InputDecoration(labelText: 'Years of Experience'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Bio / Description'),
                maxLines: 3,
              ),
              const SizedBox(height: 24),
              const Text('Specialties:', style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._availableSpecialties.map((type) {
                final index = _specialties.indexWhere((s) => s['type'] == type);
                final isSelected = index != -1;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CheckboxListTile(
                      title: Text(type),
                      value: isSelected,
                      onChanged: (selected) {
                        setState(() {
                          if (selected!) {
                            _specialties.add({'type': type, 'duration': 0, 'price': 0});
                          } else {
                            _specialties.removeWhere((s) => s['type'] == type);
                          }
                        });
                      },
                    ),
                    if (isSelected)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        child: Column(
                          children: [
                            TextFormField(
                              initialValue: _specialties[index]['duration'].toString(),
                              decoration: const InputDecoration(labelText: 'Duration (minutes)'),
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                final value = int.tryParse(val ?? '');
                                if (value == null || value <= 0) return 'Enter valid duration';
                                return null;
                              },
                              onChanged: (val) => _specialties[index]['duration'] = int.tryParse(val) ?? 0,
                            ),
                            TextFormField(
                              initialValue: _specialties[index]['price'].toString(),
                              decoration: const InputDecoration(labelText: 'Price (RM)'),
                              keyboardType: TextInputType.number,
                              validator: (val) {
                                final value = double.tryParse(val ?? '');
                                if (value == null || value <= 0) return 'Enter valid price';
                                return null;
                              },
                              onChanged: (val) => _specialties[index]['price'] = double.tryParse(val) ?? 0,
                            ),
                            const SizedBox(height: 12),
                          ],
                        ),
                      ),
                  ],
                );
              }).toList(),
              const SizedBox(height: 30),
              ElevatedButton.icon(
                onPressed: saveBarberProfile,
                icon: const Icon(Icons.save),
                label: const Text('Save Profile'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
              ),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                onPressed: _canChangePassword ? _showChangePasswordDialog : null,
                icon: const Icon(Icons.lock),
                label: Text(
                  _canChangePassword
                      ? 'Change Password'
                      : 'Next password change in ${(7 - DateTime.now().difference(_lastPasswordChange?.toDate() ?? DateTime.now()).inDays).clamp(0, 7)} day(s)',
                ),
              ),

            ],
          ),
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
}
