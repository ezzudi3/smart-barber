import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:location/location.dart' as loc;
import 'dart:math';

class BarberLocationScreen extends StatefulWidget {
  const BarberLocationScreen({Key? key}) : super(key: key);

  @override
  State<BarberLocationScreen> createState() => _BarberLocationScreenState();
}

class _BarberLocationScreenState extends State<BarberLocationScreen> {
  bool isMapView = false;
  bool isLoading = true;
  loc.LocationData? userLocation;
  final loc.Location location = loc.Location();
  GoogleMapController? mapController;
  List<Map<String, dynamic>> barbers = [];

  int _selectedIndex = 1;

  final List<Map<String, dynamic>> _navItems = [
    {'label': 'Appointments', 'icon': Icons.calendar_today, 'route': '/user appointments'},
    {'label': 'Location', 'icon': Icons.location_on, 'route': '/location'},
    {'label': 'Home', 'icon': Icons.home, 'route': '/home'},
    {'label': 'Profile', 'icon': Icons.person, 'route': '/profile'},
    {'label': 'Request', 'icon': Icons.request_page, 'route': '/request'},
  ];

  void _onTabTapped(int index) {
    if (index != _selectedIndex) {
      setState(() => _selectedIndex = index);
      Navigator.pushNamed(context, _navItems[index]['route']);
    }
  }

  @override
  void initState() {
    super.initState();
    fetchLocationAndBarbers();
  }

  Future<void> fetchLocationAndBarbers() async {
    setState(() => isLoading = true);

    bool serviceEnabled = await location.serviceEnabled();
    if (!serviceEnabled) {
      serviceEnabled = await location.requestService();
      if (!serviceEnabled) return;
    }

    final permission = await location.requestPermission();
    if (permission != loc.PermissionStatus.granted) return;

    userLocation = await location.getLocation();

    final snapshot = await FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: 'barber')
        .get();

    final List<Map<String, dynamic>> loaded = snapshot.docs.map((doc) {
      final locData = doc['location'];
      if (locData != null && locData['lat'] != null && locData['lng'] != null) {
        final distance = calculateDistance(
          userLocation!.latitude!,
          userLocation!.longitude!,
          locData['lat'],
          locData['lng'],
        );

        if (distance <= 10) {
          return {
            'uid': doc.id,
            'name': doc['name'] ?? 'Barber',
            'rating': doc.data().containsKey('rating') ? doc['rating'] : 5.0,
            'experience': doc['experience'] ?? 'New',
            'lat': locData['lat'],
            'lng': locData['lng'],
            'distance': distance,
            'image': doc['image'] ?? '',
          };
        }
      }
      return null;
    }).whereType<Map<String, dynamic>>().toList();

    loaded.sort((a, b) => a['distance'].compareTo(b['distance']));
    setState(() {
      barbers = loaded;
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
    final height = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: const Color(0xFF1A1A1A),
      body: Stack(
        children: [
          if (isLoading)
            const Center(child: CircularProgressIndicator())
          else if (isMapView && userLocation != null)
            SizedBox(
              height: height,
              child: GoogleMap(
                initialCameraPosition: CameraPosition(
                  target: LatLng(userLocation!.latitude!, userLocation!.longitude!),
                  zoom: 14,
                ),
                myLocationEnabled: true,
                myLocationButtonEnabled: true,
                onMapCreated: (controller) => mapController = controller,
                markers: barbers.map((barber) {
                  return Marker(
                    markerId: MarkerId(barber['uid']),
                    position: LatLng(barber['lat'], barber['lng']),
                    infoWindow: InfoWindow(
                      title: barber['name'],
                      snippet: '${barber['distance'].toStringAsFixed(1)} km away',
                      onTap: () {
                        Navigator.pushNamed(context, '/barberProfile', arguments: barber['uid']);
                      },
                    ),
                  );
                }).toSet(),
              ),
            )
          else
            ListView(
              padding: const EdgeInsets.only(top: 140, left: 16, right: 16, bottom: 80),
              children: barbers.map((barber) {
                return Container(
                  margin: const EdgeInsets.symmetric(vertical: 8),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFF2A2A2A), Color(0xFF1A1A1A)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange.withOpacity(0.2)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: barber['image'] != ''
                            ? Image.network(
                          barber['image'],
                          width: 60,
                          height: 60,
                          fit: BoxFit.cover,
                        )
                            : Container(
                          width: 60,
                          height: 60,
                          color: Colors.orange,
                          child: const Icon(Icons.person, color: Colors.white),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              barber['name'],
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rating: ${barber['rating']} ★\nDistance: ${barber['distance'].toStringAsFixed(2)} km',
                              style: const TextStyle(color: Colors.grey, fontSize: 14),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/barberProfile', arguments: barber['uid']);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2A2A2A),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      side: BorderSide(color: Colors.orange.withOpacity(0.5)),
                                    ),
                                  ),
                                  child: const Text('View Profile'),
                                ),
                                const SizedBox(width: 12),
                                ElevatedButton(
                                  onPressed: () {
                                    Navigator.pushNamed(context, '/bookingStep1', arguments: barber['uid']);
                                  },
                                  style: ElevatedButton.styleFrom(
                                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                    backgroundColor: Colors.orange,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  child: const Text('Book Now'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          Positioned(
            top: 60,
            left: 20,
            right: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.orange, Color(0xFFFF6B35)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  ChoiceChip(
                    label: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text(
                        'List',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    selected: !isMapView,
                    selectedColor: Colors.black,
                    backgroundColor: Colors.orange.withOpacity(0.3),
                    onSelected: (_) => setState(() => isMapView = false),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),
                  const SizedBox(width: 10),
                  ChoiceChip(
                    label: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      child: Text(
                        'Map',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    selected: isMapView,
                    selectedColor: Colors.black,
                    backgroundColor: Colors.orange.withOpacity(0.3),
                    onSelected: (_) => setState(() => isMapView = true),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                  ),

                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Colors.black, Color(0xFF2A2A2A)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
          border: Border(
            top: BorderSide(color: Colors.orange, width: 0.5),
          ),
        ),
        child: BottomNavigationBar(
          currentIndex: _selectedIndex,
          selectedItemColor: Colors.orange,
          unselectedItemColor: Colors.grey,
          backgroundColor: Colors.transparent,
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelStyle: TextStyle(color: Colors.grey),

          onTap: _onTabTapped,
          items: _navItems.map((item) => BottomNavigationBarItem(
            icon: Container(
              padding: const EdgeInsets.all(4),
              child: Icon(item['icon']),
            ),
            activeIcon: Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(item['icon']),
            ),
            label: item['label'],
          )).toList(),
        ),
      ),
    );
  }
}