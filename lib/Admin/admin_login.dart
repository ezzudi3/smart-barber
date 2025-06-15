import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:barberapp1/Admin/Admin_Dashboard_Layout.dart';
import 'package:barberapp1/pages/login.dart';

class AdminLogin extends StatefulWidget {
  const AdminLogin({super.key});

  @override
  State<AdminLogin> createState() => _AdminLoginState();
}

class _AdminLoginState extends State<AdminLogin> {
  final TextEditingController usernameController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  bool _obscureText = true;
  bool _isLoading = false;
  String? _errorMessage;

  Future<void> loginAdmin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final snapshot = await FirebaseFirestore.instance
          .collection("Admin")
          .where('id', isEqualTo: usernameController.text.trim())
          .where('password', isEqualTo: passwordController.text.trim())
          .get();

      if (snapshot.docs.isNotEmpty) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const AdminDashboard()),
        );
      } else {
        setState(() {
          _errorMessage = "Invalid admin ID or password.";
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = "Login failed. Please try again.";
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Top gradient banner
          Container(
            padding: const EdgeInsets.only(top: 50.0, left: 30.0),
            height: MediaQuery.of(context).size.height / 2,
            width: MediaQuery.of(context).size.width,
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [
                Color(0xFFB91635),
                Color(0Xff621d3c),
                Color(0xFF311937),
              ]),
            ),
            child: const Text(
              "Admin\nPanel",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

          // White form container
          Container(
            padding: const EdgeInsets.only(top: 40.0, left: 30.0, right: 30.0, bottom: 30.0),
            margin: EdgeInsets.only(top: MediaQuery.of(context).size.height / 4),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(40),
                topRight: Radius.circular(40),
              ),
            ),
            child: Form(
              key: _formKey,
              child: ListView(
                children: [
                  const Text(
                    "Username",
                    style: TextStyle(
                      color: Color(0xFFB91635),
                      fontSize: 23.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextFormField(
                    controller: usernameController,
                    decoration: const InputDecoration(
                      hintText: "Username",
                      prefixIcon: Icon(Icons.person_outline),
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter username' : null,
                  ),
                  const SizedBox(height: 30.0),

                  const Text(
                    "Password",
                    style: TextStyle(
                      color: Color(0xFFB91635),
                      fontSize: 23.0,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  TextFormField(
                    controller: passwordController,
                    obscureText: _obscureText,
                    decoration: InputDecoration(
                      hintText: "Password",
                      prefixIcon: const Icon(Icons.lock_outline),
                      suffixIcon: IconButton(
                        icon: Icon(
                            _obscureText ? Icons.visibility_off : Icons.visibility),
                        onPressed: () =>
                            setState(() => _obscureText = !_obscureText),
                      ),
                    ),
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Please enter password' : null,
                  ),
                  const SizedBox(height: 20),

                  if (_errorMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16.0),
                      child: Text(
                        _errorMessage!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),

                  _isLoading
                      ? const Center(child: CircularProgressIndicator())
                      : GestureDetector(
                    onTap: loginAdmin,
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 12.0),
                      width: double.infinity,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(colors: [
                          Color(0xFFB91635),
                          Color(0Xff621d3c),
                          Color(0xFF311937)
                        ]),
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: const Center(
                        child: Text(
                          "LOG IN",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22.0,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () {
                          Navigator.pushReplacement(
                            context,
                            MaterialPageRoute(builder: (context) => const LogIn()),
                          );
                        },
                        child: const Text(
                          "Login as User",
                          style: TextStyle(
                              fontSize: 16.0, color: Color(0xFFB91635)),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
