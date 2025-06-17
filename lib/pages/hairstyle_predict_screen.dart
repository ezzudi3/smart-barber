import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class HairstylePredictScreen extends StatefulWidget {
  final String userId;
  HairstylePredictScreen({required this.userId});

  @override
  _HairstylePredictScreenState createState() => _HairstylePredictScreenState();
}

class _HairstylePredictScreenState extends State<HairstylePredictScreen> {
  final TextEditingController ageController = TextEditingController();
  String gender = 'Male';
  String facialShape = 'Oval';
  String hairTexture = 'Straight';
  String preferredStyle = 'Undercut';

  String result = '';
  List<String> recommendations = [];
  bool isLoading = false;

  final String baseUrl = 'https://e9b8-2001-e68-5472-b3e4-885f-ff62-7cb8-4c04.ngrok-free.app';

  Future<void> predictHairstyle() async {
    setState(() {
      isLoading = true;
      result = '';
      recommendations.clear();
    });

    final data = {
      "FacialShape": facialShape,
      "Gender": gender,
      "Age": int.tryParse(ageController.text) ?? 0,
      "HairTexture": hairTexture,
      "PreferredStyle": preferredStyle,
    };

    try {
      print("📡 Sending to: $baseUrl/predict-hairstyle");

      // 1. Predict suitability
      final response = await http.post(
        Uri.parse('$baseUrl/predict-hairstyle'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      print("✅ STATUS: ${response.statusCode}");
      print("📄 BODY: ${response.body}");

      bool suitable = false;
      double confidence = 0.0;

      if (response.statusCode == 200) {
        final prediction = jsonDecode(response.body);
        suitable = prediction['suitable'];
        confidence = prediction['confidence'] * 100;

        setState(() {
          result = suitable
              ? '✅ Suitable (Confidence: ${confidence.toStringAsFixed(1)}%)'
              : '❌ Not Suitable (Confidence: ${confidence.toStringAsFixed(1)}%)';
        });
      } else {
        throw Exception("Unexpected response code: ${response.statusCode}");
      }

      // 2. Fetch recommendations
      final recResponse = await http.post(
        Uri.parse('$baseUrl/recommend-hairstyles'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(data),
      );

      print("🎯 Rec STATUS: ${recResponse.statusCode}");
      print("🎯 Rec BODY: ${recResponse.body}");

      if (recResponse.statusCode == 200) {
        final recData = jsonDecode(recResponse.body);
        setState(() {
          recommendations = List<String>.from(recData['recommendations']);
        });
      } else {
        throw Exception("Recommendation failed: ${recResponse.statusCode}");
      }

      // ✅ 3. Save result to Firestore
      await FirebaseFirestore.instance.collection('hairstyle_predictions').add({
        'userId': widget.userId,
        'timestamp': Timestamp.now(),
        'facialShape': facialShape,
        'gender': gender,
        'age': int.tryParse(ageController.text) ?? 0,
        'hairTexture': hairTexture,
        'preferredStyle': preferredStyle,
        'isSuitable': suitable,
        'confidence': confidence,
        'recommendations': recommendations,
      });

      print("✅ Saved to Firestore");

    } catch (e) {
      print("❌ ERROR: $e");
      setState(() {
        result = 'Error occurred: $e';
      });
    } finally {
      setState(() => isLoading = false);
    }
  }

  Widget buildStyledDropdown<T>(String label, T value, List<T> items, ValueChanged<T?> onChanged) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: DropdownButtonFormField<T>(
        value: value,
        items: items.map((e) => DropdownMenuItem<T>(
            value: e,
            child: Text(
              e.toString(),
              style: TextStyle(color: Colors.black87),
            )
        )).toList(),
        onChanged: onChanged,
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.orange.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        dropdownColor: Colors.white,
        icon: Icon(Icons.arrow_drop_down, color: Colors.orange.shade700),
      ),
    );
  }

  Widget buildStyledTextField(String label, TextEditingController controller) {
    return Container(
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(15),
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.1),
            blurRadius: 10,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: TextField(
        controller: controller,
        keyboardType: TextInputType.number,
        style: TextStyle(color: Colors.black87),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Colors.orange.shade700),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Colors.white,
          contentPadding: EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange, Color(0xFFFF6B35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Custom App Bar
              Container(
                padding: EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: Icon(Icons.arrow_back, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ),
                    SizedBox(width: 15),
                    Expanded(
                      child: Text(
                        "Hairstyle Predictor",
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.content_cut, color: Colors.white, size: 28),
                    ),
                  ],
                ),
              ),

              // Main Content
              Expanded(
                child: Container(
                  margin: EdgeInsets.only(top: 20),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade50,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(30),
                      topRight: Radius.circular(30),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: ListView(
                      children: [
                        // Header Section
                        Container(
                          padding: EdgeInsets.all(20),
                          margin: EdgeInsets.only(bottom: 24),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.orange.shade100, Colors.white],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.orange.shade200, width: 1),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.psychology,
                                size: 50,
                                color: Colors.orange.shade700,
                              ),
                              SizedBox(height: 10),
                              Text(
                                "AI Hairstyle Analysis",
                                style: TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black87,
                                ),
                              ),
                              SizedBox(height: 5),
                              Text(
                                "Get personalized hairstyle recommendations",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        // Form Fields
                        buildStyledTextField("Age", ageController),
                        buildStyledDropdown("Gender", gender, ['Male', 'Female'], (val) => setState(() => gender = val!)),
                        buildStyledDropdown("Facial Shape", facialShape, ['Oval', 'Round', 'Square', 'Heart', 'Diamond'], (val) => setState(() => facialShape = val!)),
                        buildStyledDropdown("Hair Texture", hairTexture, ['Straight', 'Wavy', 'Curly'], (val) => setState(() => hairTexture = val!)),
                        buildStyledDropdown("Preferred Style", preferredStyle, [
                          'Undercut',
                          'Pixie',
                          'Pompadour',
                          'Bob',
                          'Faux Hawk',
                          'Bangs',
                          'Layered Cut',
                          'Fade',
                          'Side Part'
                        ], (val) => setState(() => preferredStyle = val!)),

                        SizedBox(height: 10),

                        // Predict Button
                        Container(
                          height: 60,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              colors: [Colors.orange, Color(0xFFFF6B35)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.3),
                                blurRadius: 15,
                                offset: Offset(0, 8),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: isLoading ? null : predictHairstyle,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(15),
                              ),
                            ),
                            child: isLoading
                                ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 2,
                                  ),
                                ),
                                SizedBox(width: 10),
                                Text(
                                  "Analyzing...",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            )
                                : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(Icons.auto_awesome, color: Colors.white),
                                SizedBox(width: 10),
                                Text(
                                  "Check & Suggest",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.white,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        SizedBox(height: 30),

                        // Results Section
                        if (result.isNotEmpty)
                          Container(
                            padding: EdgeInsets.all(20),
                            margin: EdgeInsets.only(bottom: 20),
                            decoration: BoxDecoration(
                              color: result.contains("✅") ? Colors.green.shade50 : Colors.red.shade50,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(
                                color: result.contains("✅") ? Colors.green.shade200 : Colors.red.shade200,
                                width: 1,
                              ),
                            ),
                            child: Column(
                              children: [
                                Icon(
                                  result.contains("✅") ? Icons.check_circle : Icons.cancel,
                                  size: 40,
                                  color: result.contains("✅") ? Colors.green.shade700 : Colors.red.shade700,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  result,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                    color: result.contains("✅") ? Colors.green.shade700 : Colors.red.shade700,
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Recommendations Section
                        if (recommendations.isNotEmpty)
                          Container(
                            padding: EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [Colors.orange.shade50, Colors.white],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.orange.shade200, width: 1),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: Colors.orange.shade100,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Icon(
                                        Icons.star,
                                        color: Colors.orange.shade700,
                                        size: 24,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Text(
                                      "Recommended Styles",
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: 15),
                                ...recommendations.map((style) => Container(
                                  margin: EdgeInsets.only(bottom: 8),
                                  padding: EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.1),
                                        blurRadius: 5,
                                        offset: Offset(0, 2),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: 8,
                                        height: 8,
                                        decoration: BoxDecoration(
                                          color: Colors.orange,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          style,
                                          style: TextStyle(
                                            fontSize: 16,
                                            color: Colors.black87,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.arrow_forward_ios,
                                        size: 14,
                                        color: Colors.orange.shade400,
                                      ),
                                    ],
                                  ),
                                )).toList(),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}