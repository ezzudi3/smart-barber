import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'dart:math';

class BarbersByServiceScreen extends StatefulWidget {
  const BarbersByServiceScreen({Key? key}) : super(key: key);

  @override
  State<BarbersByServiceScreen> createState() => _BarbersByServiceScreenState();
}

class _BarbersByServiceScreenState extends State<BarbersByServiceScreen> {
  List<Map<String, dynamic>> barbers = [];
  loc.LocationData? currentLocation;
  final loc.Location location = loc.Location();
  final List<String> services = ['All Services', 'Hair Cut', 'Beard Trim', 'Fade Cut', 'Clean Shave', 'Hair Color'];
  String selectedService = 'All Services';
  bool isLoading = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final String? service = ModalRoute.of(context)!.settings.arguments as String?;
    if (service != null && services.contains(service)) {
      selectedService = service;
    }
    fetchLocationAndBarbers();
  }

  Future<void> fetchLocationAndBarbers() async {
    final locData = await location.getLocation();
    setState(() => currentLocation = locData);
    await fetchBarbersByService();
  }

  Future<void> fetchBarbersByService() async {
    Query query = FirebaseFirestore.instance.collection('users').where('role', isEqualTo: 'barber');

    if (selectedService != 'All Services') {
      // Map display names to database values
      String dbValue = selectedService;
      switch (selectedService) {
        case 'Hair Cut':
          dbValue = 'Haircut';
          break;
        case 'Fade Cut':
          dbValue = 'Fade';
          break;
        case 'Clean Shave':
          dbValue = 'Shave';
          break;
        case 'Hair Color':
          dbValue = 'Coloring';
          break;
      }
      query = query.where('specialtyTypes', arrayContains: dbValue);
    }

    final snapshot = await query.get();

    final fetchedBarbers = await Future.wait(snapshot.docs.map((doc) async {
      final data = doc.data() as Map<String, dynamic>;
      final locationData = data['location'];
      double? distance;
      String address = '';

      if (locationData != null &&
          locationData['lat'] != null &&
          locationData['lng'] != null &&
          currentLocation != null) {
        distance = calculateDistance(
          currentLocation!.latitude!,
          currentLocation!.longitude!,
          locationData['lat'],
          locationData['lng'],
        );

        final placemarks = await placemarkFromCoordinates(
          locationData['lat'],
          locationData['lng'],
        );
        address = '${placemarks.first.street}, ${placemarks.first.locality}';
      }

      return {
        'uid': doc.id,
        'name': data['name'] ?? 'Barber',
        'image': data['image'],
        'rating': 5.0,
        'distance': distance?.toStringAsFixed(1) ?? '--',
        'address': address,
      };
    }));

    fetchedBarbers.sort((a, b) => double.parse(a['distance']).compareTo(double.parse(b['distance'])));

    setState(() {
      barbers = fetchedBarbers;
      isLoading = false;
    });
  }

  double calculateDistance(double lat1, double lon1, double lat2, double lon2) {
    const R = 6371;
    final dLat = _deg2rad(lat2 - lat1);
    final dLon = _deg2rad(lon2 - lon1);
    final a = sin(dLat / 2) * sin(dLat / 2) +
        cos(_deg2rad(lat1)) * cos(_deg2rad(lat2)) * sin(dLon / 2) * sin(dLon / 2);
    final c = 2 * atan2(sqrt(a), sqrt(1 - a));
    return R * c;
  }

  double _deg2rad(double deg) => deg * pi / 180;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
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
        title: Text(
          selectedService == 'All Services' ? 'All Barbers' : '$selectedService Specialists',
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: isLoading
          ? Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.orange, Color(0xFFFF6B35)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
          ),
        ),
      )
          : Column(
        children: [
          // Gradient Header Section
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Colors.orange, Color(0xFFFF6B35)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 16),
                // Service Filter Chips with better spacing
                SizedBox(
                  height: 60,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    itemCount: services.length,
                    itemBuilder: (context, index) {
                      final s = services[index];
                      final isSelected = selectedService == s;
                      return Padding(
                        padding: const EdgeInsets.only(right: 12.0),
                        child: FilterChip(
                          label: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                            child: Text(
                              s,
                              style: TextStyle(
                                color: isSelected ? Colors.white : Colors.black87,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          selected: isSelected,
                          onSelected: (_) {
                            setState(() {
                              selectedService = s;
                              isLoading = true;
                            });
                            fetchBarbersByService();
                          },
                          backgroundColor: isSelected ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.9),
                          selectedColor: const LinearGradient(
                            colors: [Colors.orange, Color(0xFFFF6B35)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ).colors[0],
                          checkmarkColor: Colors.white,
                          side: BorderSide(
                            color: isSelected ? Colors.white : Colors.white.withOpacity(0.9),
                            width: 1.5,
                          ),
                          elevation: isSelected ? 4 : 0,
                          shadowColor: Colors.black.withOpacity(0.3),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(25),
                          ),
                        ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),

          // Main Content
          Expanded(
            child: Container(
              color: Colors.grey[50],
              child: Column(
                children: [
                  const SizedBox(height: 20),

                  // Popular Artists Section
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 16.0),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Popular Artists",
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Horizontal Popular Artists List
                  SizedBox(
                    height: 100,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: barbers.take(6).length,
                      itemBuilder: (context, index) {
                        final barber = barbers[index];
                        return Padding(
                          padding: const EdgeInsets.only(right: 16.0),
                          child: GestureDetector(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/barberProfile',
                                arguments: barber['uid'],
                              );
                            },
                            child: Column(
                              children: [
                                Container(
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    gradient: const LinearGradient(
                                      colors: [Colors.orange, Color(0xFFFF6B35)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.orange.withOpacity(0.3),
                                        blurRadius: 8,
                                        offset: const Offset(0, 4),
                                      ),
                                    ],
                                  ),
                                  padding: const EdgeInsets.all(3),
                                  child: CircleAvatar(
                                    radius: 28,
                                    backgroundColor: Colors.white,
                                    child: CircleAvatar(
                                      radius: 25,
                                      backgroundImage: barber['image'] != null
                                          ? NetworkImage(barber['image'])
                                          : null,
                                      child: barber['image'] == null
                                          ? const Icon(Icons.person, color: Colors.grey)
                                          : null,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                SizedBox(
                                  width: 70,
                                  child: Text(
                                    barber['name'],
                                    style: const TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.black87,
                                    ),
                                    textAlign: TextAlign.center,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  const SizedBox(height: 24),

                  // All Barbers List
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: barbers.length,
                      itemBuilder: (context, index) {
                        final barber = barbers[index];
                        return Container(
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.08),
                                blurRadius: 12,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: InkWell(
                            onTap: () {
                              Navigator.pushNamed(
                                context,
                                '/barberProfile',
                                arguments: barber['uid'],
                              );
                            },
                            borderRadius: BorderRadius.circular(16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  // Profile Picture with Gradient Border
                                  Container(
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      gradient: const LinearGradient(
                                        colors: [Colors.orange, Color(0xFFFF6B35)],
                                        begin: Alignment.topLeft,
                                        end: Alignment.bottomRight,
                                      ),
                                    ),
                                    padding: const EdgeInsets.all(2),
                                    child: CircleAvatar(
                                      radius: 32,
                                      backgroundColor: Colors.white,
                                      child: CircleAvatar(
                                        radius: 30,
                                        backgroundImage: barber['image'] != null
                                            ? NetworkImage(barber['image'])
                                            : null,
                                        child: barber['image'] == null
                                            ? const Icon(Icons.person, size: 30, color: Colors.grey)
                                            : null,
                                      ),
                                    ),
                                  ),

                                  const SizedBox(width: 16),

                                  // Barber Info
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          barber['name'],
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 16,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),

                                        // Rating
                                        Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 8,
                                                vertical: 4,
                                              ),
                                              decoration: BoxDecoration(
                                                gradient: const LinearGradient(
                                                  colors: [Colors.orange, Color(0xFFFF6B35)],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  const Icon(
                                                    Icons.star,
                                                    size: 14,
                                                    color: Colors.white,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    barber['rating'].toString(),
                                                    style: const TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 12,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),

                                        const SizedBox(height: 8),

                                        // Location
                                        Row(
                                          children: [
                                            Icon(
                                              Icons.location_on,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Expanded(
                                              child: Text(
                                                '${barber['address']}  •  ${barber['distance']} km',
                                                style: TextStyle(
                                                  color: Colors.grey[600],
                                                  fontSize: 13,
                                                ),
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),

                                  // Arrow Icon
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: Colors.grey[100],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Icon(
                                      Icons.arrow_forward_ios,
                                      size: 16,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
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