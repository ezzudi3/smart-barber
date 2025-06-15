import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart';

class BarberApplicationScreen extends StatefulWidget {
  const BarberApplicationScreen({Key? key}) : super(key: key);

  @override
  State<BarberApplicationScreen> createState() => _BarberApplicationScreenState();
}

class _BarberApplicationScreenState extends State<BarberApplicationScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _icController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _bioController = TextEditingController();

  File? _licenseImage;
  bool _isSubmitting = false;

  Future<void> _pickLicenseImage() async {
    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (pickedFile != null) {
      setState(() => _licenseImage = File(pickedFile.path));
    }
  }

  Future<void> _submitApplication() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();

    String? licenseUrl;
    if (_licenseImage != null) {
      final ref = FirebaseStorage.instance.ref().child('barber_licenses/$uid.jpg');
      await ref.putFile(_licenseImage!);
      licenseUrl = await ref.getDownloadURL();
    }

    await FirebaseFirestore.instance.collection('barberApplications').doc(uid).set({
      'userId': uid,
      'name': userDoc['name'],
      'phone': userDoc['phone'],
      'icNumber': _icController.text.trim(),
      'experience': _experienceController.text.trim(),
      'bio': _bioController.text.trim(),
      'licenseUrl': licenseUrl ?? '',
      'status': 'pending',
      'submittedAt': Timestamp.now(),
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Application submitted. Please wait for approval.')),
    );

    setState(() => _isSubmitting = false);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Apply to Become a Barber'), backgroundColor: Colors.deepPurple),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              TextFormField(
                controller: _icController,
                decoration: const InputDecoration(labelText: 'IC Number'),
                validator: (value) => value == null || value.isEmpty ? 'Enter IC Number' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _experienceController,
                decoration: const InputDecoration(labelText: 'Years of Experience'),
                keyboardType: TextInputType.number,
                validator: (value) => value == null || value.isEmpty ? 'Enter experience' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _bioController,
                decoration: const InputDecoration(labelText: 'Short Bio'),
                maxLines: 3,
                validator: (value) => value == null || value.isEmpty ? 'Enter bio' : null,
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  ElevatedButton.icon(
                    icon: const Icon(Icons.upload_file),
                    label: const Text('Upload License'),
                    onPressed: _pickLicenseImage,
                  ),
                  const SizedBox(width: 10),
                  if (_licenseImage != null)
                    const Icon(Icons.check_circle, color: Colors.green),
                ],
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isSubmitting ? null : _submitApplication,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.deepPurple,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Submit Application'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
