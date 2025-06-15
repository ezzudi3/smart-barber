import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:csv/csv.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'dart:typed_data';
import 'dart:collection';
import 'BookingStatusDetailsScreen.dart';

class AnalyticsOverviewScreen extends StatefulWidget {
  const AnalyticsOverviewScreen({super.key});

  @override
  State<AnalyticsOverviewScreen> createState() => _AnalyticsOverviewScreenState();
}

class _AnalyticsOverviewScreenState extends State<AnalyticsOverviewScreen> {
  int totalUserCount = 0;
  int totalBarberCount = 0;
  int totalBookingCount = 0;
  bool isLoading = true;
  String selectedRange = 'All';

  Map<String, int> bookingStatusData = {
    'complete': 0,
    'confirmed': 0,
    'pending': 0,
    'cancelled': 0,
  };

  List<Map<String, dynamic>> bookingRecords = [];
  Map<String, int> bookingsPerDay = {}; // For line chart

  final List<Map<String, dynamic>> statusSections = [
    {'key': 'complete', 'color': Colors.green},
    {'key': 'confirmed', 'color': Colors.blue},
    {'key': 'pending', 'color': Colors.orange},
    {'key': 'cancelled', 'color': Colors.red},
  ];

  @override
  void initState() {
    super.initState();
    _loadAnalytics();
  }

  Future<void> _loadAnalytics() async {
    try {
      final usersSnap = await FirebaseFirestore.instance.collection('users').get();
      int userCount = 0;
      int barberCount = 0;

      final userDataMap = <String, Map<String, String>>{};

      for (var doc in usersSnap.docs) {
        final role = doc.data()['role'];
        final name = doc.data()['name'] ?? 'N/A';
        final phone = doc.data()['phone'] ?? 'N/A';
        final userId = doc.id;
        userDataMap[userId] = {'name': name, 'phone': phone};

        if (role == 'user') {
          userCount++;
        } else if (role == 'barber') {
          barberCount++;
        }
      }

      final now = DateTime.now();
      DateTime? filterStart;

      if (selectedRange == 'This Week') {
        filterStart = now.subtract(Duration(days: now.weekday - 1));
      } else if (selectedRange == 'This Month') {
        filterStart = DateTime(now.year, now.month, 1);
      }

      final bookingsSnap = await FirebaseFirestore.instance.collection('bookings').get();
      final personalBookingsSnap = await FirebaseFirestore.instance.collection('barberServiceRequests').get();

      Map<String, int> statusCounts = {
        'complete': 0,
        'confirmed': 0,
        'pending': 0,
        'cancelled': 0,
      };

      List<Map<String, dynamic>> allRecords = [];
      Map<String, int> dateCounts = {}; // yyyy-MM-dd => count

      void countStatus(QuerySnapshot snap) {
        for (var doc in snap.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final status = (data['status']?.toString().toLowerCase() ?? '');
          final dateField = data['scheduledAt'] ?? data['preferredDate'];
          DateTime? scheduledAt;

          if (dateField is Timestamp) {
            scheduledAt = dateField.toDate();
          } else if (dateField is String) {
            scheduledAt = DateTime.tryParse(dateField);
          }

          if (scheduledAt == null || (filterStart != null && scheduledAt.isBefore(filterStart))) {
            continue;
          }

          final dateKey = scheduledAt.toString().split(" ")[0];
          dateCounts[dateKey] = (dateCounts[dateKey] ?? 0) + 1;

          if (statusCounts.containsKey(status)) {
            statusCounts[status] = statusCounts[status]! + 1;
          }

          final userId = data['userId'] ?? '';
          final barberId = data['barberId'] ?? '';

          allRecords.add({
            'date': dateKey,
            'status': status,
            'userName': userDataMap[userId]?['name'] ?? 'N/A',
            'userPhone': userDataMap[userId]?['phone'] ?? 'N/A',
            'barberName': userDataMap[barberId]?['name'] ?? 'N/A',
            'barberPhone': userDataMap[barberId]?['phone'] ?? 'N/A',
          });
        }
      }

      countStatus(bookingsSnap);
      countStatus(personalBookingsSnap);

      setState(() {
        totalUserCount = userCount;
        totalBarberCount = barberCount;
        totalBookingCount = allRecords.length;
        bookingStatusData = statusCounts;
        bookingRecords = allRecords;
        bookingsPerDay = SplayTreeMap.from(dateCounts);
        isLoading = false;
      });
    } catch (e) {
      print('Error loading analytics: \$e');
    }
  }

  List<FlSpot> _generateTrendSpots() {
    List<FlSpot> spots = [];
    int x = 0;
    for (var entry in bookingsPerDay.entries) {
      spots.add(FlSpot(x.toDouble(), entry.value.toDouble()));
      x++;
    }
    return spots;
  }

  Future<void> _exportCSV() async {
    List<List<String>> csvData = [
      ['Date', 'Status', 'User Name', 'User Phone', 'Barber Name', 'Barber Phone'],
      ...bookingRecords.map((b) => [
        b['date'], b['status'],
        b['userName'], b['userPhone'],
        b['barberName'], b['barberPhone'],
      ]),
    ];
    String csv = const ListToCsvConverter().convert(csvData);
    await Printing.sharePdf(bytes: Uint8List.fromList(csv.codeUnits), filename: 'booking_data.csv');
  }

  Future<void> _exportPDF() async {
    final pdf = pw.Document();
    pdf.addPage(
      pw.Page(
        build: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text('Booking Report', style: pw.TextStyle(fontSize: 24)),
            pw.SizedBox(height: 12),
            pw.Table.fromTextArray(
              headers: ['Date', 'Status', 'User Name', 'User Phone', 'Barber Name', 'Barber Phone'],
              data: bookingRecords.map((e) => [
                e['date'], e['status'],
                e['userName'], e['userPhone'],
                e['barberName'], e['barberPhone'],
              ]).toList(),
            )
          ],
        ),
      ),
    );
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  Widget _buildPieChart() {
    final hasData = bookingStatusData.values.any((value) => value > 0);
    if (!hasData) return const Text("No booking status data available.");

    bool alreadyNavigated = false;

    return SizedBox(
      height: 200,
      child: PieChart(
        PieChartData(
          sections: statusSections.map((entry) {
            final count = bookingStatusData[entry['key']] ?? 0;
            return PieChartSectionData(
              value: count.toDouble(),
              color: entry['color'],
              title: "${entry['key'][0].toUpperCase()}${entry['key'].substring(1)} ($count)",
              titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
            );
          }).toList(),
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          pieTouchData: PieTouchData(
            touchCallback: (event, response) {
              if (!event.isInterestedForInteractions || alreadyNavigated) return;

              final touchedSection = response?.touchedSection;
              if (touchedSection == null) return;

              final touchedIndex = touchedSection.touchedSectionIndex;
              final selectedStatus = statusSections[touchedIndex]['key'];

              alreadyNavigated = true;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => BookingStatusDetailsScreen(
                    status: selectedStatus,
                    bookingRecords: bookingRecords,
                  ),
                ),
              ).then((_) => alreadyNavigated = false);
            },
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeader("Overview Statistics"),
          const SizedBox(height: 10),
          _buildTopMetrics(),
          const SizedBox(height: 30),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildHeader("Booking Trends"),
              DropdownButton<String>(
                value: selectedRange,
                onChanged: (val) {
                  setState(() {
                    selectedRange = val!;
                    isLoading = true;
                  });
                  _loadAnalytics();
                },
                items: ['All', 'This Week', 'This Month']
                    .map((e) => DropdownMenuItem(value: e, child: Text(e)))
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _buildLineChart(),
          const SizedBox(height: 30),
          _buildHeader("Booking Status Breakdown"),
          const SizedBox(height: 10),
          _buildPieChart(),
          const SizedBox(height: 30),
          _buildHeader("Export Data"),
          Row(
            children: [
              ElevatedButton.icon(
                onPressed: _exportCSV,
                icon: const Icon(Icons.download),
                label: const Text("Export CSV"),
              ),
              const SizedBox(width: 10),
              ElevatedButton.icon(
                onPressed: _exportPDF,
                icon: const Icon(Icons.picture_as_pdf),
                label: const Text("Export PDF"),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(String title) => Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold));

  Widget _buildTopMetrics() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _buildMetricCard("Users", totalUserCount.toString()),
        _buildMetricCard("Barbers", totalBarberCount.toString()),
        _buildMetricCard("Bookings", totalBookingCount.toString()),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value) => Expanded(
    child: Card(
      margin: const EdgeInsets.symmetric(horizontal: 5),
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            Text(title, style: const TextStyle(color: Colors.grey))
          ],
        ),
      ),
    ),
  );

  Widget _buildLineChart() {
    final spots = _generateTrendSpots();
    if (spots.isEmpty) return const Text("No booking trend data available.");

    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              spots: spots,
              color: Colors.deepPurple,
              belowBarData: BarAreaData(show: false),
            )
          ],
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(show: false),
          gridData: FlGridData(show: false),
        ),
      ),
    );
  }
}
