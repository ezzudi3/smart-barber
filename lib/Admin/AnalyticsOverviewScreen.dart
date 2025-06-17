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

  // Theme Colors
  static const Color primaryOrange = Color(0xFFFF8C00);
  static const Color primaryYellow = Color(0xFFFFA500);
  static const Color darkBlack = Color(0xFF2C2C2C);
  static const Color sectionGrey = Color(0xFFF0F0F0);
  static const Color lightGrey = Color(0xFFF8F8F8);

  Map<String, int> bookingStatusData = {
    'complete': 0,
    'confirmed': 0,
    'pending': 0,
    'cancelled': 0,
  };

  List<Map<String, dynamic>> bookingRecords = [];
  Map<String, int> bookingsPerDay = {}; // For line chart

  final List<Map<String, dynamic>> statusSections = [
    {'key': 'complete', 'color': Colors.green.shade600, 'description': 'Successfully completed bookings'},
    {'key': 'confirmed', 'color': Colors.blue.shade600, 'description': 'Confirmed and scheduled bookings'},
    {'key': 'pending', 'color': Colors.orange.shade600, 'description': 'Awaiting confirmation from barber'},
    {'key': 'cancelled', 'color': Colors.red.shade600, 'description': 'Cancelled or rejected bookings'},
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
      print('Error loading analytics: $e');
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

  Widget _buildAdminGreeting() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [primaryOrange, primaryYellow],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(
            Icons.admin_panel_settings,
            size: 28,
            color: Colors.white,
          ),
          const SizedBox(width: 12),
          Text(
            'Hi Admin!',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPieChart() {
    final hasData = bookingStatusData.values.any((value) => value > 0);
    if (!hasData) {
      return Container(
        height: 200,
        child: Center(
          child: Text(
            "No booking status data available.",
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ),
      );
    }

    bool alreadyNavigated = false;

    return Column(
      children: [
        // Pie Chart
        Container(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: statusSections.map((entry) {
                final count = bookingStatusData[entry['key']] ?? 0;
                return PieChartSectionData(
                  value: count.toDouble(),
                  color: entry['color'],
                  title: "$count",
                  titleStyle: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                  radius: 60,
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
        ),
        const SizedBox(height: 20),
        // Legend
        _buildLegend(),
      ],
    );
  }

  Widget _buildLegend() {
    return Column(
      children: statusSections.map((entry) {
        final count = bookingStatusData[entry['key']] ?? 0;
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300, width: 1),
          ),
          child: Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: BoxDecoration(
                  color: entry['color'],
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          entry['key'].toString().toUpperCase(),
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: darkBlack,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '$count',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: entry['color'],
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry['description'],
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionBox({required String title, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: sectionGrey,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: darkBlack,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Scaffold(
        backgroundColor: lightGrey,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(primaryOrange),
              ),
              const SizedBox(height: 16),
              Text(
                'Loading Analytics...',
                style: TextStyle(
                  fontSize: 16,
                  color: darkBlack,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: lightGrey,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Admin Greeting
            _buildAdminGreeting(),
            const SizedBox(height: 20),

            // Overview Statistics
            _buildSectionBox(
              title: "Overview Statistics",
              child: _buildTopMetrics(),
            ),
            const SizedBox(height: 20),

            // Booking Trends
            _buildSectionBox(
              title: "Booking Trends",
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        "Time Range:",
                        style: TextStyle(
                          fontSize: 14,
                          color: darkBlack,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: primaryOrange, width: 1),
                        ),
                        child: DropdownButton<String>(
                          value: selectedRange,
                          underline: Container(),
                          icon: Icon(Icons.keyboard_arrow_down, color: primaryOrange, size: 20),
                          style: TextStyle(color: darkBlack, fontSize: 14),
                          onChanged: (val) {
                            setState(() {
                              selectedRange = val!;
                              isLoading = true;
                            });
                            _loadAnalytics();
                          },
                          items: ['All', 'This Week', 'This Month']
                              .map((e) => DropdownMenuItem(
                            value: e,
                            child: Text(e),
                          ))
                              .toList(),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  _buildLineChart(),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Booking Status Breakdown
            _buildSectionBox(
              title: "Booking Status Breakdown",
              child: _buildPieChart(),
            ),
            const SizedBox(height: 20),

            // Export Data
            _buildSectionBox(
              title: "Export Data",
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _exportCSV,
                      icon: const Icon(Icons.download, color: Colors.white),
                      label: const Text(
                        "Export CSV",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryOrange,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _exportPDF,
                      icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
                      label: const Text(
                        "Export PDF",
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: darkBlack,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopMetrics() {
    return Row(
      children: [
        Expanded(child: _buildMetricCard("Users", totalUserCount.toString(), primaryOrange)),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricCard("Barbers", totalBarberCount.toString(), primaryYellow)),
        const SizedBox(width: 12),
        Expanded(child: _buildMetricCard("Bookings", totalBookingCount.toString(), darkBlack)),
      ],
    );
  }

  Widget _buildMetricCard(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300, width: 1),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLineChart() {
    final spots = _generateTrendSpots();
    if (spots.isEmpty) {
      return Container(
        height: 180,
        child: Center(
          child: Text(
            "No booking trend data available.",
            style: TextStyle(color: Colors.grey[600], fontSize: 16),
          ),
        ),
      );
    }

    return Container(
      height: 180,
      child: LineChart(
        LineChartData(
          lineBarsData: [
            LineChartBarData(
              isCurved: true,
              spots: spots,
              color: primaryOrange,
              barWidth: 3,
              dotData: FlDotData(show: false),
              belowBarData: BarAreaData(
                show: true,
                color: primaryOrange.withOpacity(0.1),
              ),
            )
          ],
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(show: false),
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: Colors.grey.withOpacity(0.3),
              strokeWidth: 1,
            ),
          ),
        ),
      ),
    );
  }
}