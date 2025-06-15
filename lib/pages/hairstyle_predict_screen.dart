import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';

class HairstylePredictScreen extends StatefulWidget {
  final String userId;
  HairstylePredictScreen({required this.userId}); // 👈 pass this from login

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

  final String baseUrl = 'https://1fdb-2001-e68-449b-36a0-84c6-e027-21b3-28b2.ngrok-free.app';

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

  Widget buildDropdown<T>(String label, T value, List<T> items, ValueChanged<T?> onChanged) {
    return DropdownButtonFormField<T>(
      value: value,
      items: items.map((e) => DropdownMenuItem<T>(value: e, child: Text(e.toString()))).toList(),
      onChanged: onChanged,
      decoration: InputDecoration(labelText: label),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text("Hairstyle Predictor")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            TextField(
              controller: ageController,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(labelText: "Age"),
            ),
            buildDropdown("Gender", gender, ['Male', 'Female'], (val) => setState(() => gender = val!)),
            buildDropdown("Facial Shape", facialShape, ['Oval', 'Round', 'Square', 'Heart', 'Diamond'],
                    (val) => setState(() => facialShape = val!)),
            buildDropdown("Hair Texture", hairTexture, ['Straight', 'Wavy', 'Curly'], (val) => setState(() => hairTexture = val!)),
            buildDropdown("Preferred Style", preferredStyle, [
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

            SizedBox(height: 20),
            ElevatedButton(
              onPressed: isLoading ? null : predictHairstyle,
              child: isLoading ? CircularProgressIndicator(color: Colors.white) : Text("Check & Suggest"),
            ),
            SizedBox(height: 30),
            if (result.isNotEmpty)
              Center(
                child: Text(result,
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: result.contains("✅") ? Colors.green : Colors.red)),
              ),
            SizedBox(height: 20),
            if (recommendations.isNotEmpty) ...[
              Text("🎯 Recommended Styles:", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ...recommendations.map((style) => ListTile(
                leading: Icon(Icons.star),
                title: Text(style),
              ))
            ],
          ],
        ),
      ),
    );
  }
}
