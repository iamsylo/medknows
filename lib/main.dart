import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medknows/pages/home_screen.dart';
import 'firebase_options.dart';
import 'pages/intro_page.dart';
import 'pages/signup_page.dart';
import 'package:cloud_firestore/cloud_firestore.dart';  // Add this import

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  Future<Map<String, dynamic>> checkInitialRoute() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      if (userId != null && userId.isNotEmpty) {
        // Fetch user data from Firestore
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userData.exists) {
          return {
            'route': '/home',
            'userName': userData.data()?['name'] ?? 'User'
          };
        }
      }
      return {'route': '/', 'userName': null};
    } catch (e) {
      print('Error checking auth state: $e');
      return {'route': '/', 'userName': null};
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'OTICURE',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: FutureBuilder<Map<String, dynamic>>(
        future: checkInitialRoute(),
        builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
            return Scaffold(
              body: Stack(
              children: [
              Positioned.fill(
              child: Image.asset(
                'assets/images/on_board_bg.png',
                fit:BoxFit.fill,
              ),
              ),
              Positioned(
                top: 200, // Adjust this value to move higher or lower
                left: 0,
                right: 0,
                child: Column(
                children: [
                  Text(
                  'OTICURE',
                  style: GoogleFonts.playfairDisplaySc(
                    textStyle: const TextStyle(
                    fontSize: 76,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    height: 1,
                    ),
                  ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                  'Over-The-Counter Medicine Recommender and Tracking Application',
                  style: GoogleFonts.openSans(
                    textStyle: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    fontStyle: FontStyle.italic,
                    height: 1,
                    ),
                  ),
                  textAlign: TextAlign.center,
                  ),
                ],
                ),
              ),
              ],
              ),
            );
            }
          
          if (snapshot.data?['route'] == '/home') {
            return HomeScreen(userName: snapshot.data?['userName'] ?? 'User');
          }
          
          return const IntroPage();
        },
      ),
    );
  }
}