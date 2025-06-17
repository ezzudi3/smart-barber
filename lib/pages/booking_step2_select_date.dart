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

class _BookingStep2SelectDateState extends State<BookingStep2SelectDate> with TickerProviderStateMixin {
  DateTime? selectedDate;
  TimeOfDay? selectedTime;
  DateTime? estimatedEndDateTime;

  Map<String, dynamic>? workingHoursPerDay;
  TimeOfDay? dayStartTime;
  TimeOfDay? dayEndTime;
  bool isLoading = true;
  List<Map<String, DateTime>> bookedSlots = [];

  late AnimationController _pulseController;
  late AnimationController _slideController;
  late Animation<double> _pulseAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _slideController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.2).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _slideController, curve: Curves.elasticOut));

    fetchBarberWorkingHours();
    _slideController.forward();
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _slideController.dispose();
    super.dispose();
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Colors.white,
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 24),
            ),
            const SizedBox(width: 12),
            const Text("Unavailable", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Text(message, style: const TextStyle(color: Colors.black87)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              backgroundColor: Colors.orange.shade50,
              foregroundColor: Colors.orange,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("OK", style: TextStyle(fontWeight: FontWeight.w600)),
          ),
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
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Colors.orange,
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
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

  Widget _buildServiceCard(Map<String, dynamic> service, int index) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.white, Colors.orange.shade50],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.orange.withOpacity(0.15),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.all(16),
        leading: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.orange, Color(0xFFFF6B35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _getServiceIcon(service['type'] ?? 'Service'),
            color: Colors.white,
            size: 24,
          ),
        ),
        title: Text(
          service['type'] ?? 'Service',
          style: const TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
            fontSize: 16,
          ),
        ),
        subtitle: Text(
          "Duration: ${service['duration']} mins | RM${service['price']}",
          style: TextStyle(
            color: Colors.grey.shade600,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  IconData _getServiceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'haircut':
        return Icons.content_cut;
      case 'beard':
      case 'beard trim':
        return Icons.face_retouching_natural;
      case 'shave':
        return Icons.face_6;
      case 'wash':
      case 'hair wash':
        return Icons.water_drop;
      case 'styling':
        return Icons.auto_fix_high;
      default:
        return Icons.cut;
    }
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback? onPressed,
    bool isEnabled = true,
    bool isPrimary = false,
  }) {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: isPrimary && isEnabled ? _pulseAnimation.value : 1.0,
          child: Container(
            width: double.infinity,
            height: 56,
            decoration: BoxDecoration(
              gradient: isEnabled
                  ? const LinearGradient(
                colors: [Colors.orange, Color(0xFFFF6B35)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
                  : LinearGradient(
                colors: [Colors.grey.shade400, Colors.grey.shade500],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: isEnabled
                  ? [
                BoxShadow(
                  color: Colors.orange.withOpacity(0.4),
                  blurRadius: 12,
                  offset: const Offset(0, 6),
                ),
              ]
                  : [],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: onPressed,
                borderRadius: BorderRadius.circular(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(icon, color: Colors.white, size: 24),
                    const SizedBox(width: 12),
                    Text(
                      label,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isNextEnabled = selectedDate != null && selectedTime != null;
    final selectedDay = getSelectedDay();
    final isDayAvailable = workingHoursPerDay?[selectedDay] != null;

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text(
          'Select Date & Time',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.orange, Color(0xFFFF6B35)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.orange, Color(0xFFFF6B35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                shape: BoxShape.circle,
              ),
              child: const CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              "Loading availability...",
              style: TextStyle(color: Colors.black54, fontSize: 16),
            ),
          ],
        ),
      )
          : SlideTransition(
        position: _slideAnimation,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Services Section
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Colors.orange, Color(0xFFFF6B35)],
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                            ),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.list_alt, color: Colors.white, size: 24),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          "Selected Services",
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    ...widget.selectedServices.asMap().entries.map((entry) {
                      return _buildServiceCard(entry.value, entry.key);
                    }),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.orange.shade50, Colors.yellow.shade50],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.orange.shade200),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.timer, color: Colors.orange.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Total Duration: ${widget.totalDuration} mins",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Icon(Icons.payments, color: Colors.orange.shade700, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    "Total Price: RM ${widget.totalPrice.toStringAsFixed(2)}",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                      color: Colors.orange.shade800,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 24),

              // Working Hours & Booked Slots
              if (selectedDate != null)
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.orange.withOpacity(0.1),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (dayStartTime != null && dayEndTime != null) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.access_time, color: Colors.green.shade600, size: 20),
                            ),
                            const SizedBox(width: 12),
                            Text(
                              "Working Hours: ${dayStartTime!.format(context)} - ${dayEndTime!.format(context)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                      ],
                      if (bookedSlots.isNotEmpty) ...[
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.red.shade50,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Icon(Icons.event_busy, color: Colors.red.shade600, size: 20),
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              "Already Booked Slots:",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ...bookedSlots.map((slot) {
                          return Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            decoration: BoxDecoration(
                              color: Colors.red.shade50,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.red.shade200),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.block, color: Colors.red.shade600, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                  "${DateFormat('h:mm a').format(slot['start']!)} → ${DateFormat('h:mm a').format(slot['end']!)}",
                                  style: TextStyle(
                                    color: Colors.red.shade700,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }),
                      ],
                    ],
                  ),
                ),

              const SizedBox(height: 24),

              // Date & Time Selection
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.orange.withOpacity(0.1),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    _buildActionButton(
                      label: selectedDate == null
                          ? "Choose Date"
                          : "Date: ${DateFormat('MMM d, y').format(selectedDate!)}",
                      icon: Icons.calendar_month,
                      onPressed: () => _selectDate(context),
                    ),
                    const SizedBox(height: 16),
                    _buildActionButton(
                      label: selectedTime == null
                          ? "Choose Time"
                          : "Time: ${selectedTime!.format(context)}",
                      icon: Icons.schedule,
                      onPressed: isDayAvailable ? () => _selectTime(context) : null,
                      isEnabled: isDayAvailable,
                    ),
                    if (selectedTime != null && estimatedEndDateTime != null) ...[
                      const SizedBox(height: 20),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.green.shade50, Colors.teal.shade50],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.green.shade200),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.green.shade100,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(Icons.check_circle, color: Colors.green.shade600, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    "Appointment Scheduled",
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    formattedDateTime,
                                    style: TextStyle(
                                      color: Colors.green.shade700,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              const SizedBox(height: 32),

              // Proceed Button
              _buildActionButton(
                label: "Proceed to Billing",
                icon: Icons.payment,
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
                isEnabled: isNextEnabled,
                isPrimary: false,
              ),

              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}