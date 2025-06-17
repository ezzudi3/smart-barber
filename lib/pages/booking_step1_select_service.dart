import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class BookingSelectServicePage extends StatefulWidget {
  final String barberId;
  const BookingSelectServicePage({Key? key, required this.barberId}) : super(key: key);

  @override
  State<BookingSelectServicePage> createState() => _BookingSelectServicePageState();
}

class _BookingSelectServicePageState extends State<BookingSelectServicePage> with TickerProviderStateMixin {
  List<Map<String, dynamic>> services = [];
  List<Map<String, dynamic>> selectedServices = [];
  bool isLoading = true;
  bool hasError = false;
  double totalPrice = 0;
  int totalDuration = 0;
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: Duration(milliseconds: 300),
      vsync: this,
    );
    fetchBarberServices();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
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
        _animationController.forward().then((_) {
          _animationController.reverse();
        });
      }
    });
  }

  IconData getServiceIcon(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'haircut':
      case 'cut':
        return Icons.content_cut;
      case 'beard':
      case 'beard trim':
        return Icons.face_retouching_natural;
      case 'shave':
        return Icons.face_retouching_off;
      case 'wash':
      case 'hair wash':
        return Icons.water_drop;
      case 'styling':
      case 'hair styling':
        return Icons.auto_fix_high;
      case 'coloring':
      case 'hair color':
        return Icons.palette;
      case 'massage':
        return Icons.spa;
      case 'treatment':
        return Icons.healing;
      case 'undercut':
        return Icons.flash_on;
      case 'fade':
        return Icons.gradient;
      case 'mustache':
        return Icons.face_6;
      case 'eyebrow':
        return Icons.visibility;
      default:
        return Icons.cut;
    }
  }

  Color getServiceColor(String serviceType) {
    switch (serviceType.toLowerCase()) {
      case 'haircut':
      case 'cut':
        return Colors.orange.shade600;
      case 'beard':
      case 'beard trim':
        return Colors.brown.shade600;
      case 'shave':
        return Colors.blue.shade600;
      case 'wash':
      case 'hair wash':
        return Colors.cyan.shade600;
      case 'styling':
      case 'hair styling':
        return Colors.purple.shade600;
      case 'coloring':
      case 'hair color':
        return Colors.pink.shade600;
      case 'massage':
        return Colors.green.shade600;
      case 'treatment':
        return Colors.teal.shade600;
      default:
        return Colors.orange.shade600;
    }
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
                        "Select Services",
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
                      child: Icon(Icons.shopping_cart, color: Colors.white, size: 28),
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
                  child: isLoading
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.orange.withOpacity(0.3),
                                blurRadius: 20,
                                offset: Offset(0, 10),
                              ),
                            ],
                          ),
                          child: CircularProgressIndicator(
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.orange),
                            strokeWidth: 3,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          "Loading Services...",
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.grey.shade600,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  )
                      : hasError
                      ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade50,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.red.shade200),
                          ),
                          child: Icon(
                            Icons.error_outline,
                            size: 50,
                            color: Colors.red.shade600,
                          ),
                        ),
                        SizedBox(height: 20),
                        Text(
                          'Failed to load services',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.red.shade700,
                          ),
                        ),
                        Text(
                          'Please try again later',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  )
                      : Column(
                    children: [
                      // Header Section
                      Container(
                        padding: EdgeInsets.all(20),
                        margin: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Colors.orange.shade100, Colors.white],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.orange.shade200, width: 1),
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.orange.shade100,
                                borderRadius: BorderRadius.circular(15),
                              ),
                              child: Icon(
                                Icons.content_cut,
                                size: 30,
                                color: Colors.orange.shade700,
                              ),
                            ),
                            SizedBox(width: 15),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Choose Your Services",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  ),
                                  Text(
                                    "Select multiple services for your booking",
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      // Services List
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          itemCount: services.length,
                          itemBuilder: (context, index) {
                            final service = services[index];
                            final selected = selectedServices.contains(service);
                            final serviceType = service['type'] ?? 'Service';
                            final serviceIcon = getServiceIcon(serviceType);
                            final serviceColor = getServiceColor(serviceType);

                            return AnimatedContainer(
                              duration: Duration(milliseconds: 300),
                              margin: EdgeInsets.only(bottom: 12),
                              decoration: BoxDecoration(
                                gradient: selected
                                    ? LinearGradient(
                                  colors: [Colors.orange.shade50, Colors.white],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                                    : LinearGradient(
                                  colors: [Colors.white, Colors.white],
                                ),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(
                                  color: selected ? Colors.orange.shade300 : Colors.grey.shade200,
                                  width: selected ? 2 : 1,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: selected
                                        ? Colors.orange.withOpacity(0.2)
                                        : Colors.grey.withOpacity(0.1),
                                    blurRadius: selected ? 15 : 8,
                                    offset: Offset(0, selected ? 8 : 4),
                                  ),
                                ],
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(15),
                                  onTap: () => toggleServiceSelection(service),
                                  child: Padding(
                                    padding: EdgeInsets.all(16),
                                    child: Row(
                                      children: [
                                        // Service Icon
                                        Container(
                                          padding: EdgeInsets.all(12),
                                          decoration: BoxDecoration(
                                            color: serviceColor.withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: Icon(
                                            serviceIcon,
                                            size: 28,
                                            color: serviceColor,
                                          ),
                                        ),
                                        SizedBox(width: 15),

                                        // Service Details
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                serviceType,
                                                style: TextStyle(
                                                  fontSize: 17,
                                                  fontWeight: FontWeight.bold,
                                                  color: Colors.black87,
                                                ),
                                              ),
                                              SizedBox(height: 4),
                                              Row(
                                                children: [
                                                  Icon(
                                                    Icons.access_time,
                                                    size: 16,
                                                    color: Colors.grey.shade600,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    "${service['duration']} mins",
                                                    style: TextStyle(
                                                      fontSize: 13,
                                                      color: Colors.grey.shade600,
                                                    ),
                                                  ),
                                                  SizedBox(width: 15),
                                                  Icon(
                                                    Icons.payments,
                                                    size: 16,
                                                    color: Colors.orange.shade600,
                                                  ),
                                                  SizedBox(width: 4),
                                                  Text(
                                                    "RM${service['price']}",
                                                    style: TextStyle(
                                                      fontSize: 15,
                                                      fontWeight: FontWeight.bold,
                                                      color: Colors.orange.shade700,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ],
                                          ),
                                        ),

                                        // Selection Indicator
                                        AnimatedContainer(
                                          duration: Duration(milliseconds: 300),
                                          padding: EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: selected ? Colors.orange : Colors.transparent,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: selected ? Colors.orange : Colors.grey.shade400,
                                              width: 2,
                                            ),
                                          ),
                                          child: Icon(
                                            selected ? Icons.check : Icons.add,
                                            size: 20,
                                            color: selected ? Colors.white : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),

                      // Bottom Summary & Button
                      Container(
                        padding: EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(25),
                            topRight: Radius.circular(25),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.grey.withOpacity(0.1),
                              blurRadius: 10,
                              offset: Offset(0, -5),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            if (selectedServices.isNotEmpty) ...[
                              // Summary Row
                              Container(
                                padding: EdgeInsets.all(16),
                                margin: EdgeInsets.only(bottom: 15),
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [Colors.orange.shade50, Colors.white],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(color: Colors.orange.shade200),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                                  children: [
                                    Column(
                                      children: [
                                        Icon(Icons.timer, color: Colors.orange.shade700, size: 20),
                                        SizedBox(height: 4),
                                        Text(
                                          "$totalDuration mins",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          "Duration",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Container(
                                      height: 40,
                                      width: 1,
                                      color: Colors.orange.shade200,
                                    ),
                                    Column(
                                      children: [
                                        Icon(Icons.attach_money, color: Colors.orange.shade700, size: 20),
                                        SizedBox(height: 4),
                                        Text(
                                          "RM ${totalPrice.toStringAsFixed(2)}",
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          "Total Price",
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],

                            // Proceed Button
                            Container(
                              width: double.infinity,
                              height: 55,
                              decoration: BoxDecoration(
                                gradient: selectedServices.isEmpty
                                    ? LinearGradient(colors: [Colors.grey.shade300, Colors.grey.shade400])
                                    : LinearGradient(
                                  colors: [Colors.orange, Color(0xFFFF6B35)],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(15),
                                boxShadow: selectedServices.isEmpty
                                    ? []
                                    : [
                                  BoxShadow(
                                    color: Colors.orange.withOpacity(0.3),
                                    blurRadius: 15,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: ElevatedButton(
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
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.transparent,
                                  shadowColor: Colors.transparent,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(15),
                                  ),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.calendar_today,
                                      color: selectedServices.isEmpty ? Colors.grey.shade600 : Colors.white,
                                    ),
                                    SizedBox(width: 10),
                                    Text(
                                      selectedServices.isEmpty
                                          ? "Select Services First"
                                          : "Proceed to Date Selection",
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: selectedServices.isEmpty ? Colors.grey.shade600 : Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
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
        ),
      ),
    );
  }
}