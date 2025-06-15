import 'package:flutter/material.dart';

class BookingStep3Billing extends StatefulWidget {
  final String barberId;
  final List<Map<String, dynamic>> selectedServices;
  final double totalPrice;
  final int totalDuration;
  final DateTime selectedDateTime;

  const BookingStep3Billing({
    Key? key,
    required this.barberId,
    required this.selectedServices,
    required this.totalPrice,
    required this.totalDuration,
    required this.selectedDateTime,
  }) : super(key: key);

  @override
  State<BookingStep3Billing> createState() => _BookingStep3BillingState();
}

class _BookingStep3BillingState extends State<BookingStep3Billing> {
  final TextEditingController paymentController = TextEditingController();

  @override
  void dispose() {
    paymentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formattedDate = "${widget.selectedDateTime.toLocal()}".split('.')[0];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Billing & Payment'),
        backgroundColor: Colors.deepPurple,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Booking Summary", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Expanded(
              child: ListView.builder(
                itemCount: widget.selectedServices.length,
                itemBuilder: (context, index) {
                  final service = widget.selectedServices[index];
                  return ListTile(
                    title: Text(service['type'] ?? 'Service'),
                    subtitle: Text("Duration: ${service['duration']} mins | RM${service['price']}"),
                  );
                },
              ),
            ),
            Text("Total Duration: ${widget.totalDuration} mins"),
            Text("Total Price: RM ${widget.totalPrice.toStringAsFixed(2)}"),
            const SizedBox(height: 10),
            Text("Appointment: $formattedDate"),
            const Divider(height: 32),
            TextFormField(
              controller: paymentController,
              decoration: const InputDecoration(
                labelText: 'Payment Method',
                hintText: 'e.g., Credit Card, Cash, or Bank Transfer',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () {
                if (paymentController.text.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Please enter a payment method")),
                  );
                  return;
                }

                // Simple confirmation without ToyyibPay
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("Payment confirmed!")),
                );

                // You can navigate to a confirmation screen or booking summary screen
                Navigator.pop(context); // Pop the current screen, or navigate as needed
              },
              icon: const Icon(Icons.payment),
              label: const Text("Confirm & Pay"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
