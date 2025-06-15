import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class BookingStep2SelectDate extends StatefulWidget {
  final String barberId;
  final List<Map<String, dynamic>> selectedServices;
  final double totalPrice;
  final int totalDuration;

  const BookingStep2SelectDate({
    Key? key,
    required this.barberId,
    required this.selectedServices,
    required this.totalPrice,
    required this.totalDuration,
  }) : super(key: key);

  @override
  State<BookingStep2SelectDate> createState() => _BookingStep2SelectDateState();
}

class _BookingStep2SelectDateState extends State<BookingStep2SelectDate> {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  DateTime? estimatedEndDateTime;

  Map<String, dynamic>? workingHoursPerDay;
  TimeOfDay? dayStartTime;
  TimeOfDay? dayEndTime;
  bool isLoading = true;
  List<Map<String, DateTime>> bookedSlots = [];

  @override
  void initState() {
    super.initState();
    fetchBarberWorkingHours();
  }

  Future<void> fetchBarberWorkingHours() async {
    try {
      final doc = await FirebaseFirestore.instance.collection('users').doc(widget.barberId).get();
      final data = doc.data();
      if (data != null && data.containsKey('workingHours')) {
        workingHoursPerDay = Map<String, dynamic>.from(data['workingHours']);
      }
    } catch (e) {
      print("⚠️ Error loading schedule: $e");
    }
    setState(() => isLoading = false);
  }

  String? getSelectedDay() {
    if (selectedDate == null) return null;
    return ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday']
    [selectedDate!.weekday % 7];
  }

  Future<void> fetchBookedSlots() async {
    if (selectedDate == null) return;
    final dayStart = DateTime(selectedDate!.year, selectedDate!.month, selectedDate!.day);
    final dayEnd = dayStart.add(const Duration(days: 1));

    final snapshot = await FirebaseFirestore.instance
        .collection('bookings')
        .where('barberId', isEqualTo: widget.barberId)
        .where('scheduledAt', isGreaterThanOrEqualTo: Timestamp.fromDate(dayStart))
        .where('scheduledAt', isLessThan: Timestamp.fromDate(dayEnd))
        .get();

    setState(() {
      bookedSlots = snapshot.docs.map((doc) {
        final data = doc.data();
        final start = (data['scheduledAt'] as Timestamp).toDate();
        final end = (data['estimatedEndAt'] as Timestamp?)?.toDate() ??
            start.add(Duration(minutes: data['totalDuration'] ?? 30));
        return {'start': start, 'end': end};
      }).toList();
    });
  }

  Future<void> _selectDate(BuildContext context) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now,
      firstDate: now,
      lastDate: now.add(const Duration(days: 30)),
    );

    if (picked != null) {
      setState(() {
        selectedDate = picked;
        selectedTime = null;
        estimatedEndDateTime = null;
      });

      final day = getSelectedDay();
      final working = workingHoursPerDay?[day];
      if (working != null) {
        dayStartTime = _parseTime(working['start']);
        dayEndTime = _parseTime(working['end']);
        await fetchBookedSlots();
      } else {
        dayStartTime = null;
        dayEndTime = null;
        bookedSlots = [];
      }
    }
  }

  TimeOfDay _parseTime(String timeStr) {
    final parts = timeStr.split(":");
    int hour = int.parse(parts[0]);
    int minute = int.parse(parts[1].split(" ")[0]);
    final isPM = timeStr.toLowerCase().contains("pm");
    if (isPM && hour < 12) hour += 12;
    return TimeOfDay(hour: hour, minute: minute);
  }

  bool _isWithinWorkingHours(TimeOfDay time) {
    if (dayStartTime == null || dayEndTime == null) return false;
    final selected = time.hour * 60 + time.minute;
    final start = dayStartTime!.hour * 60 + dayStartTime!.minute;
    final end = dayEndTime!.hour * 60 + dayEndTime!.minute;
    return selected >= start && selected + widget.totalDuration <= end;
  }

  void _showUnavailableAlert(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text("Unavailable"),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
        ],
      ),
    );
  }

  Future<void> _selectTime(BuildContext context) async {
    if (dayStartTime == null || dayEndTime == null) {
      _showUnavailableAlert("This day is not available for booking.");
      return;
    }

    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );

    if (picked != null) {
      if (!_isWithinWorkingHours(picked)) {
        _showUnavailableAlert("The selected time is outside the barber's working hours.");
        return;
      }

      final start = DateTime(
        selectedDate!.year,
        selectedDate!.month,
        selectedDate!.day,
        picked.hour,
        picked.minute,
      );
      final end = start.add(Duration(minutes: widget.totalDuration));

      final hasConflict = bookedSlots.any((slot) {
        return start.isBefore(slot['end']!) && end.isAfter(slot['start']!);
      });

      if (hasConflict) {
        _showUnavailableAlert("This time slot is already booked.");
      } else {
        setState(() {
          selectedTime = picked;
          estimatedEndDateTime = end;
        });
      }
    }
  }

  String get formattedDateTime {
    if (selectedDate == null || selectedTime == null || estimatedEndDateTime == null)
      return 'Not selected yet';
    final dt = DateTime(
      selectedDate!.year,
      selectedDate!.month,
      selectedDate!.day,
      selectedTime!.hour,
      selectedTime!.minute,
    );
    return "${DateFormat('MMM d, y – h:mm a').format(dt)} → ${DateFormat('h:mm a').format(estimatedEndDateTime!)}";
  }

  @override
  Widget build(BuildContext context) {
    final isNextEnabled = selectedDate != null && selectedTime != null;
    final selectedDay = getSelectedDay();
    final isDayAvailable = workingHoursPerDay?[selectedDay] != null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Date & Time'),
        backgroundColor: Colors.deepPurple,
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            const Text("Selected Services", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
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
            const SizedBox(height: 20),
            if (dayStartTime != null && dayEndTime != null)
              Text("🕒 Barber Working Hours: ${dayStartTime!.format(context)} - ${dayEndTime!.format(context)}",
                  style: const TextStyle(fontWeight: FontWeight.w500)),
            const SizedBox(height: 8),
            if (bookedSlots.isNotEmpty) ...[
              const Text("📛 Already Booked Slots:", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 6),
              ...bookedSlots.map((slot) {
                return Text(
                  "- ${DateFormat('h:mm a').format(slot['start']!)} → ${DateFormat('h:mm a').format(slot['end']!)}",
                  style: const TextStyle(color: Colors.red),
                );
              }),
              const SizedBox(height: 10),
            ],
            ElevatedButton.icon(
              onPressed: () => _selectDate(context),
              icon: const Icon(Icons.calendar_today),
              label: const Text("Choose Date"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.deepPurple),
            ),
            const SizedBox(height: 8),
            ElevatedButton.icon(
              onPressed: isDayAvailable ? () => _selectTime(context) : null,
              icon: const Icon(Icons.access_time),
              label: const Text("Choose Time"),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDayAvailable ? Colors.deepPurple : Colors.grey,
              ),
            ),
            if (selectedTime != null && estimatedEndDateTime != null)
              Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text("⏱ $formattedDateTime", style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            const Spacer(),
            ElevatedButton(
              onPressed: isNextEnabled
                  ? () {
                final scheduledAt = DateTime(
                  selectedDate!.year,
                  selectedDate!.month,
                  selectedDate!.day,
                  selectedTime!.hour,
                  selectedTime!.minute,
                );
                Navigator.pushNamed(
                  context,
                  '/bookingBilling',
                  arguments: {
                    'barberId': widget.barberId,
                    'selectedServices': widget.selectedServices,
                    'totalPrice': widget.totalPrice,
                    'totalDuration': widget.totalDuration,
                    'selectedDateTime': scheduledAt,
                    'estimatedEndAt': estimatedEndDateTime,
                  },
                );
              }
                  : null,
              child: const Text("Proceed to Billing"),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.deepPurple,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
