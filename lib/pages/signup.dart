import 'package:barberapp1/pages/home.dart';
import 'package:barberapp1/pages/login.dart';
import 'package:barberapp1/services/database.dart';
import 'package:barberapp1/services/shared_pref.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:random_string/random_string.dart';

class SignUp extends StatefulWidget {
  const SignUp({super.key});

  @override

  State<SignUp> createState() => _SignUpState();
}

class _SignUpState extends State<SignUp> {
  TextEditingController namecontroller = TextEditingController();
  TextEditingController emailcontroller = TextEditingController();
  TextEditingController passwordcontroller = TextEditingController();

  final _formkey = GlobalKey<FormState>();
  bool _obscureText = true;

  Future<void> registration() async {
    final nameText = namecontroller.text.trim();
    final email = emailcontroller.text.trim();
    final pass = passwordcontroller.text.trim();

    if (nameText.isNotEmpty && email.isNotEmpty && pass.isNotEmpty) {
      try {
        UserCredential userCredential = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: pass);

        final uid = userCredential.user?.uid;
        String id = randomAlphaNumeric(10);

        await SharedpreferenceHelper().saveUserName(nameText);
        await SharedpreferenceHelper().saveUserEmail(email);
        await SharedpreferenceHelper().saveUserImage(
            "https://firebasestorage.googleapis.com/v0/b/barberapp-ebcc1.appspot.com/o/icon1.png?alt=media&token=0fad24a5-a01b-4d67-b4a0-676fbc75b34a");
        await SharedpreferenceHelper().saveUserId(id);

        Map<String, dynamic> userInfoMap = {
          "Name": nameText,
          "Email": email,
          "Id": id,
          "Image":
          "https://firebasestorage.googleapis.com/v0/b/barberapp-ebcc1.appspot.com/o/icon1.png?alt=media&token=0fad24a5-a01b-4d67-b4a0-676fbc75b34a"
        };
        await DatabaseMethods().addUserDetails(userInfoMap, id);

        if (uid != null) {
          try {
            await FirebaseFirestore.instance.collection('users').doc(uid).set({
              'name': nameText,
              'email': email,
              'role': 'user',
              'createdAt': FieldValue.serverTimestamp(),
            });
          } catch (e) {
            print('⚠️ Firestore write failed: $e');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text("Error saving user info. Please try again.")),
            );
            return;
          }
        }

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Registered Successfully", style: TextStyle(fontSize: 20)),
          ),
        );

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const Home()),
        );
      } on FirebaseAuthException catch (e) {
        if (e.code == 'weak-password') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Password Provided is too weak", style: TextStyle(fontSize: 20))),
          );
        } else if (e.code == "email-already-in-use") {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text("Account Already exists", style: TextStyle(fontSize: 20))),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
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
              "Create Your\nAccount",
              style: TextStyle(
                color: Colors.white,
                fontSize: 32.0,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.all(30.0),
            margin: EdgeInsets.only(top: MediaQuery.of(context).size.height / 4),
            height: MediaQuery.of(context).size.height,
            width: MediaQuery.of(context).size.width,
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(40), topRight: Radius.circular(40)),
            ),
            child: Form(
              key: _formkey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Name",
                      style: TextStyle(
                          color: Color(0xFFB91635),
                          fontSize: 23.0,
                          fontWeight: FontWeight.w500)),
                  TextFormField(
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Please Enter Name' : null,
                    controller: namecontroller,
                    decoration: const InputDecoration(
                        hintText: "Name", prefixIcon: Icon(Icons.person_outline)),
                  ),
                  const SizedBox(height: 40.0),
                  const Text("Gmail",
                      style: TextStyle(
                          color: Color(0xFFB91635),
                          fontSize: 23.0,
                          fontWeight: FontWeight.w500)),
                  TextFormField(
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Please Enter E-mail' : null,
                    controller: emailcontroller,
                    decoration: const InputDecoration(
                        hintText: "Gmail", prefixIcon: Icon(Icons.mail_outline)),
                  ),
                  const SizedBox(height: 40.0),
                  const Text("Password",
                      style: TextStyle(
                          color: Color(0xFFB91635),
                          fontSize: 23.0,
                          fontWeight: FontWeight.w500)),
                  TextFormField(
                    validator: (value) =>
                    value == null || value.isEmpty ? 'Please Enter Password' : null,
                    controller: passwordcontroller,
                    decoration: InputDecoration(
                      hintText: "Password",
                      prefixIcon: const Icon(Icons.password_outlined),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscureText ? Icons.visibility_off : Icons.visibility,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscureText = !_obscureText;
                          });
                        },
                      ),
                    ),
                    obscureText: _obscureText,
                  ),
                  const SizedBox(height: 60.0),
                  GestureDetector(
                    onTap: () {
                      if (_formkey.currentState!.validate()) {
                        registration();
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 10.0),
                      width: MediaQuery.of(context).size.width,
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
                          "SIGN UP",
                          style: TextStyle(
                              color: Colors.white,
                              fontSize: 24.0,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  const Spacer(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: const [
                      Text(
                        "Already have an account?",
                        style: TextStyle(
                            color: Color(0xFF311937),
                            fontSize: 17.0,
                            fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.pushReplacement(
                          context, MaterialPageRoute(builder: (context) => const LogIn()));
                    },
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: const [
                        Text(
                          "Sign In",
                          style: TextStyle(
                              color: Color(0Xff621d3c),
                              fontSize: 22.0,
                              fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
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
