import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingSelectServicePage extends StatefulWidget {
  final String barberId;
  const BookingSelectServicePage({Key? key, required this.barberId}) : super(key: key);

  @override
  State<BookingSelectServicePage> createState() => _BookingSelectServicePageState();
}

class _BookingSelectServicePageState extends State<BookingSelectServicePage> {
  List<Map<String, dynamic>> services = [];
  List<Map<String, dynamic>> selectedServices = [];
  bool isLoading = true;
  bool hasError = false;
  double totalPrice = 0;
  int totalDuration = 0;

  @override
  void initState() {
    super.initState();
    fetchBarberServices();
  }

  Future<void> fetchBarberServices() async {
    try {
      if (widget.barberId.isEmpty) {
        throw Exception("Invalid barber ID");
      }

      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.barberId).get();
      final data = doc.data();
      if (data != null && data.containsKey('specialties')) {
        setState(() {
          services = List<Map<String, dynamic>>.from(data['specialties']);
          isLoading = false;
        });
      } else {
        setState(() {
          isLoading = false;
          hasError = true;
        });
      }
    } catch (e) {
      print("⚠️ Error fetching barber services: $e");
      setState(() {
        isLoading = false;
        hasError = true;
      });
    }
  }

  void toggleServiceSelection(Map<String, dynamic> service) {
    final exists = selectedServices.contains(service);
    setState(() {
      if (exists) {
        selectedServices.remove(service);
        totalPrice -= service['price'];
        totalDuration -= (service['duration'] as num).toInt();


      } else {
        selectedServices.add(service);
        totalPrice += service['price'];
        totalDuration += (service['duration'] as num).toInt();

      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Services'),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : hasError
          ? const Center(child: Text('Failed to load services. Please try again.'))
          : Column(
        children: [
          Expanded(
            child: ListView.builder(
              itemCount: services.length,
              itemBuilder: (context, index) {
                final service = services[index];
                final selected = selectedServices.contains(service);
                return Card(
                  child: ListTile(
                    title: Text(service['type'] ?? 'Service'),
                    subtitle: Text(
                      "Duration: ${service['duration']} mins | RM${service['price']}",
                    ),
                    trailing: selected
                        ? const Icon(Icons.check_circle, color: Colors.green)
                        : const Icon(Icons.circle_outlined),
                    onTap: () => toggleServiceSelection(service),
                  ),
                );
              },
            ),
          ),
          if (selectedServices.isNotEmpty)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: [
                  Text("Total Duration: $totalDuration mins"),
                  Text("Total Price: RM ${totalPrice.toStringAsFixed(2)}"),
                ],
              ),
            ),
          ElevatedButton(
            onPressed: selectedServices.isEmpty
                ? null
                : () {
              Navigator.pushNamed(
                context,
                '/bookingDate',
                arguments: {
                  'barberId': widget.barberId,
                  'selectedServices': selectedServices,
                  'totalPrice': totalPrice,
                  'totalDuration': totalDuration,
                },
              );
            },
            child: const Text('Proceed to Date'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.deepPurple,
              padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 40),
            ),
          ),
          const SizedBox(height: 16),
        ],
      ),
    );
  }
}
