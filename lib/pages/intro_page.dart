import 'package:flutter/material.dart';
import 'package:lottie/lottie.dart';
import 'package:medknows/pages/signup_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_page.dart';

class IntroPage extends StatelessWidget {
  const IntroPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background image
          Positioned.fill(
            child: Image.asset(
              'assets/images/on_board_bg.png',
              fit: BoxFit.cover,
            ),
          ),
          // Centered content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Title
                Text(
                  'OTICURE',
                  style: GoogleFonts.playfairDisplaySc(
                  textStyle: const TextStyle(
                    fontSize: 90,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                    height: 1, // Adjusted line height
                  ),
                  ),
                ),
                const SizedBox(height: 20),
                // Phrase
                Text(
                  'Over-The-Counter Medicine Recommender and Tracking Application',
                  style: GoogleFonts.openSans(
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.bold,
                    height: 1, // Adjusted line height
                  ),
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                // Logo
                Lottie.network(
                  'https://lottie.host/48e5f1f7-2e93-43dc-869a-98d36ba1064d/FAgElaJWbC.json',
                  width: 350,
                  height: 350,
                ),
                const SizedBox(height: 80),
                // Get Started Button
                SizedBox(
                  width: 305,
                  height: 58,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(66, 96, 208, 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      shadowColor: const Color.fromRGBO(0, 122, 204, 1),
                      elevation: 16,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LoginPage()),
                      );
                    },
                    child: Center(
                      child: Text(
                        'Login',
                        style: GoogleFonts.roboto(
                          textStyle: const TextStyle(
                            fontSize: 16,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Sign Up Button
                SizedBox(
                  width: 305,
                  height: 58,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color.fromRGBO(241, 246, 251, 1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(24),
                      ),
                      shadowColor: const Color.fromRGBO(217, 227, 236, 1),
                      elevation: 16,
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const SignupPage()),
                      );
                    },
                    child: Center(
                      child: Text(
                        'Register',
                        style: GoogleFonts.roboto(
                          textStyle: const TextStyle(
                            fontSize: 16,
                            color: Color.fromRGBO(0, 87, 160, 1),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
