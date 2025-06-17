// Enhanced Admin Dashboard with Orange/Yellow Theme and Modern Styling
import 'package:flutter/material.dart';
import 'package:barberapp1/Admin/AnalyticsOverviewScreen.dart';
import 'package:barberapp1/Admin/AdminUserManagementScreen.dart';
import 'package:barberapp1/Admin/AdminReviewBarberApplicationsScreen.dart';
import 'package:barberapp1/Admin/AdminBookingManagementScreen.dart';
import 'package:barberapp1/Admin/AdminFeedbackScreen.dart';
import 'package:barberapp1/Admin/AdminSettingsScreen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  int _selectedIndex = 0;
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;

  // Color palette for orange/yellow theme
  static const Color primaryOrange = Color(0xFFFF6B35);
  static const Color secondaryYellow = Color(0xFFFFC107);
  static const Color accentAmber = Color(0xFFFFB300);
  static const Color darkBackground = Color(0xFF1A1A1A);
  static const Color cardBackground = Color(0xFF2D2D2D);
  static const Color textLight = Color(0xFFFFFBE6);

  final List<Widget> _pages = [
    AnalyticsOverviewScreen(),
    AdminUserManagementScreen(),
    AdminReviewBarberApplicationsScreen(),
    AdminBookingManagementScreen(),
    AdminFeedbackScreen(),
    AdminSettingsScreen(),
  ];

  final List<String> _titles = [
    'Analytics & Overview',
    'User Management',
    'Review Barber Applications',
    'Booking Management',
    'Feedback',
    'Settings'
  ];

  final List<IconData> _icons = [
    Icons.analytics_rounded,
    Icons.people_alt_rounded,
    Icons.how_to_reg_rounded,
    Icons.event_note_rounded,
    Icons.rate_review_rounded,
    Icons.settings_rounded,
  ];

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _scaleAnimation = Tween<double>(
      begin: 0.95,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    ));
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    // Add a subtle animation when switching tabs
    _animationController.reset();
    _animationController.forward();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: darkBackground,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80),
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                primaryOrange,
                secondaryYellow,
                accentAmber,
              ],
              stops: [0.0, 0.5, 1.0],
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: true,
            title: AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              child: Text(
                _titles[_selectedIndex],
                key: ValueKey<int>(_selectedIndex),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                  shadows: [
                    Shadow(
                      offset: Offset(0, 2),
                      blurRadius: 4,
                      color: Colors.black38,
                    ),
                  ],
                ),
              ),
            ),
            leading: Container(
              margin: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(12),
              ),
              child: IconButton(
                icon: const Icon(Icons.menu_rounded, color: Colors.white),
                onPressed: () => Scaffold.of(context).openDrawer(),
              ),
            ),
            actions: [
              Container(
                margin: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.notifications_rounded, color: Colors.white),
                  onPressed: () {
                    // Handle notifications
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.topCenter,
            radius: 1.5,
            colors: [
              Color(0xFF2A2A2A),
              darkBackground,
            ],
          ),
        ),
        child: AnimatedBuilder(
          animation: _scaleAnimation,
          builder: (context, child) {
            return Transform.scale(
              scale: _scaleAnimation.value,
              child: _pages[_selectedIndex],
            );
          },
        ),
      ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF2D2D2D),
              Color(0xFF1A1A1A),
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 15,
              offset: Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(25),
            topRight: Radius.circular(25),
          ),
          child: BottomNavigationBar(
            type: BottomNavigationBarType.fixed,
            backgroundColor: Colors.transparent,
            elevation: 0,
            selectedItemColor: secondaryYellow,
            unselectedItemColor: Colors.grey[600],
            currentIndex: _selectedIndex,
            onTap: _onItemTapped,
            selectedLabelStyle: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 12,
            ),
            unselectedLabelStyle: const TextStyle(
              fontSize: 11,
            ),
            items: List.generate(_icons.length, (index) {
              final isSelected = _selectedIndex == index;
              return BottomNavigationBarItem(
                icon: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeInOut,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                      colors: [primaryOrange, secondaryYellow],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                        : null,
                    borderRadius: BorderRadius.circular(15),
                    boxShadow: isSelected
                        ? [
                      const BoxShadow(
                        color: primaryOrange,
                        blurRadius: 8,
                        offset: Offset(0, 2),
                      ),
                    ]
                        : null,
                  ),
                  child: Icon(
                    _icons[index],
                    color: isSelected ? Colors.white : Colors.grey[600],
                    size: isSelected ? 26 : 24,
                  ),
                ),
                label: _getShortLabel(index),
              );
            }),
          ),
        ),
      ),
    );
  }

  String _getShortLabel(int index) {
    switch (index) {
      case 0:
        return 'Analytics';
      case 1:
        return 'Users';
      case 2:
        return 'Barbers';
      case 3:
        return 'Booking';
      case 4:
        return 'Feedback';
      case 5:
        return 'Settings';
      default:
        return '';
    }
  }
}