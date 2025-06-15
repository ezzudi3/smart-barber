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
  final List<String> services = ['All', 'Haircut', 'Beard Trim', 'Fade', 'Shave', 'Coloring'];
  String selectedService = 'All';
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

    if (selectedService != 'All') {
      query = query.where('specialtyTypes', arrayContains: selectedService); // ✅ Use flattened field
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
        'image': data['image'], // ✅ Profile picture
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
      appBar: AppBar(
        backgroundColor: Colors.deepOrange,
        title: Text('$selectedService Barbers'),
      ),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : Column(
        children: [
          const SizedBox(height: 8),
          SizedBox(
            height: 50,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: services.length,
              itemBuilder: (context, index) {
                final s = services[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  child: ChoiceChip(
                    label: Text(s),
                    selected: selectedService == s,
                    onSelected: (_) {
                      setState(() {
                        selectedService = s;
                        isLoading = true;
                      });
                      fetchBarbersByService();
                    },
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          const Padding(
            padding: EdgeInsets.all(8.0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text("Popular Artists", style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ),
          SizedBox(
            height: 80,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: barbers.length,
              itemBuilder: (context, index) {
                final barber = barbers[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 10.0),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundImage:
                        barber['image'] != null ? NetworkImage(barber['image']) : null,
                        child: barber['image'] == null ? const Icon(Icons.person) : null,
                      ),
                      const SizedBox(height: 4),
                      Text(barber['name'], style: const TextStyle(fontSize: 12)),
                    ],
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: ListView.builder(
              itemCount: barbers.length,
              itemBuilder: (context, index) {
                final barber = barbers[index];
                return Card(
                  margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  child: InkWell(
                    onTap: () {
                      Navigator.pushNamed(
                        context,
                        '/barberProfile',
                        arguments: barber['uid'],
                      );
                    },
                    child: ListTile(
                      leading: CircleAvatar(
                        radius: 24,
                        backgroundImage:
                        barber['image'] != null ? NetworkImage(barber['image']) : null,
                        child: barber['image'] == null ? const Icon(Icons.person) : null,
                      ),
                      title: Text(barber['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.star, size: 16, color: Colors.orange),
                              const SizedBox(width: 4),
                              Text(barber['rating'].toString()),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              const Icon(Icons.location_on, size: 16),
                              const SizedBox(width: 4),
                              Expanded(
                                child: Text('${barber['address']}  •  ${barber['distance']} km'),
                              ),
                            ],
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
    );
  }
}
