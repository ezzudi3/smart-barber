import 'package:barberapp1/Admin/admin_login.dart';
import 'package:barberapp1/Admin/Admin_Dashboard_Layout.dart';
import 'package:barberapp1/pages/BarberApplicationScreen.dart';
import 'package:barberapp1/pages/BarberRequestScreen.dart';
import 'package:barberapp1/pages/RequestBookingDetailsScreen.dart';
import 'package:barberapp1/pages/UserNotificationsScreen.dart';
import 'package:barberapp1/pages/barber_profile_page.dart';
import 'package:barberapp1/pages/barbers_by_service.dart';
import 'package:barberapp1/pages/booking.dart';
import 'package:barberapp1/pages/booking_step1_select_service.dart';
import 'package:barberapp1/pages/booking_step2_select_date.dart';
import 'package:barberapp1/pages/booking_step3_billing.dart';
import 'package:barberapp1/pages/booking_step4_complete.dart';
import 'package:barberapp1/pages/forgot_password.dart';
import 'package:barberapp1/pages/hairstyle_predict_screen.dart';
import 'package:barberapp1/pages/home.dart';
import 'package:barberapp1/pages/location_page.dart';
import 'package:barberapp1/pages/login.dart';
import 'package:barberapp1/pages/onboarding.dart';
import 'package:barberapp1/pages/signup.dart';
import 'package:barberapp1/Barber/homebarber.dart';
import 'package:barberapp1/Barber/manage_schedule.dart';
import 'package:barberapp1/Barber/edit_profile.dart';
import 'package:barberapp1/pages/user_appointment_list.dart';
import 'package:barberapp1/pages/userprofile.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'Barber/RequestDetailScreen.dart';
import 'Barber/barber_appointment_detail.dart';
import 'Barber/barber_appointment_list.dart';
import 'Barber/barber_notification.dart';
import 'Barber/requestAppointmentDetail.dart';

void main() async{
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // This is the theme of your application.
        //
        // TRY THIS: Try running your application with "flutter run". You'll see
        // the application has a blue toolbar. Then, without quitting the app,
        // try changing the seedColor in the colorScheme below to Colors.green
        // and then invoke "hot reload" (save your changes or press the "hot
        // reload" button in a Flutter-supported IDE, or press "r" if you used
        // the command line to start the app).
        //
        // Notice that the counter didn't reset back to zero; the application
        // state is not lost during the reload. To reset the state, use hot
        // restart instead.
        //
        // This works for code too, not just values: Most code changes can be
        // tested with just a hot reload.
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home:LogIn(),
      routes: {
        '/barb': (context) => const HomeBarber(), // This connects to homebarber.dart
        '/editProfile': (context) => const EditBarberProfileScreen(),
        '/schedule': (context) => const ManageScheduleScreen(),
        '/home': (context) => const Home(),         // user view
        '/login': (context) => const LogIn(),
        '/barbersByService': (context) => const BarbersByServiceScreen(),
        '/location': (context) => const BarberLocationScreen(),
        '/profile' : (context) => const UserProfileScreen(),
        '/barberNotifications': (context) => const BarberNotificationsScreen(),
        '/user appointments' : (context) => UserAppointmentList(),
        '/barberAppointments' : (context) =>  const BarberAppointmentList(),
        '/barberAppointmentDetails': (context) =>  const BarberAppointmentDetailsPage(),
        '/userNotifications': (context) => const UserNotificationsScreen(),
        '/adminLogin': (context) => const AdminLogin(),
        '/barberApplication': (context) => const BarberApplicationScreen(),
        '/requestDetail': (context) => const RequestDetailScreen(),
        '/request': (context) => const BarberRequestScreen(),
        '/requestAppointmentDetail' : (context) => const RequestAppointmentDetail(),








        //'/bookingDate' : (context) => const BookingStep2SelectDate(),
        //'/bookingBilling' : (context) => const BookingStep3Billing(),
        //'/bookingComplete' : (context) => const BookingStep4Complete(),






      },

      onGenerateRoute: (settings) {
        if (settings.name == '/barberProfile') {
          final barberId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => BarberProfilePage(barberId: barberId),
          );
        }
        if (settings.name == '/bookingStep1') {
          final barberId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (_) => BookingSelectServicePage(barberId: barberId),
          );
        }
        if (settings.name == '/bookingDate') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => BookingStep2SelectDate(
              barberId: args['barberId'],
              selectedServices: List<Map<String, dynamic>>.from(args['selectedServices']),
              totalPrice: args['totalPrice'],
              totalDuration: args['totalDuration'],
            ),
          );
        }
        if (settings.name == '/bookingBilling') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => BookingStep3Billing(
              barberId: args['barberId'],
              selectedServices: List<Map<String, dynamic>>.from(args['selectedServices']),
              totalPrice: args['totalPrice'],
              totalDuration: args['totalDuration'],
              selectedDateTime: args['selectedDateTime'],
            ),
          );
        }
        if (settings.name == '/bookingComplete') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (_) => BookingStep4Complete(
              barberId: args['barberId'],
              selectedServices: List<Map<String, dynamic>>.from(args['selectedServices']),
              totalPrice: args['totalPrice'],
              totalDuration: args['totalDuration'],
              selectedDateTime: args['selectedDateTime'],
              paymentMethod: args['paymentMethod'],
            ),
          );
        }


        // Default routes fallback
        return null;
      },


    );
  }
}

class RequestBookingDetailsScreen {
  const RequestBookingDetailsScreen({required Map<String, dynamic> bookingData});
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  // This widget is the home page of your application. It is stateful, meaning
  // that it has a State object (defined below) that contains fields that affect
  // how it looks.

  // This class is the configuration for the state. It holds the values (in this
  // case the title) provided by the parent (in this case the App widget) and
  // used by the build method of the State. Fields in a Widget subclass are
  // always marked "final".

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  int _counter = 0;

  void _incrementCounter() {
    setState(() {
      // This call to setState tells the Flutter framework that something has
      // changed in this State, which causes it to rerun the build method below
      // so that the display can reflect the updated values. If we changed
      // _counter without calling setState(), then the build method would not be
      // called again, and so nothing would appear to happen.
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    // This method is rerun every time setState is called, for instance as done
    // by the _incrementCounter method above.
    //
    // The Flutter framework has been optimized to make rerunning build methods
    // fast, so that you can just rebuild anything that needs updating rather
    // than having to individually change instances of widgets.
    return Scaffold(
      appBar: AppBar(
        // TRY THIS: Try changing the color here to a specific color (to
        // Colors.amber, perhaps?) and trigger a hot reload to see the AppBar
        // change color while the other colors stay the same.
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        // Here we take the value from the MyHomePage object that was created by
        // the App.build method, and use it to set our appbar title.
        title: Text(widget.title),
      ),
      body: Center(
        // Center is a layout widget. It takes a single child and positions it
        // in the middle of the parent.
        child: Column(
          // Column is also a layout widget. It takes a list of children and
          // arranges them vertically. By default, it sizes itself to fit its
          // children horizontally, and tries to be as tall as its parent.
          //
          // Column has various properties to control how it sizes itself and
          // how it positions its children. Here we use mainAxisAlignment to
          // center the children vertically; the main axis here is the vertical
          // axis because Columns are vertical (the cross axis would be
          // horizontal).
          //
          // TRY THIS: Invoke "debug painting" (choose the "Toggle Debug Paint"
          // action in the IDE, or press "p" in the console), to see the
          // wireframe for each widget.
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text(
              'You have pushed the button this many times:',
            ),
            Text(
              '$_counter',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _incrementCounter,
        tooltip: 'Increment',
        child: const Icon(Icons.add),
      ), // This trailing comma makes auto-formatting nicer for build methods.
    );
  }
}
