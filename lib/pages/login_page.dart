import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:medknows/models/user_data.dart';
import 'package:medknows/pages/home_screen.dart'; // Ensure this path is correct
import 'package:medknows/pages/initial_health_screen.dart';
import 'package:medknows/pages/signup_page.dart'; // Add this import
import 'package:shared_preferences/shared_preferences.dart'; // Add this import
import 'package:crypto/crypto.dart';
import 'dart:convert'; // for utf8.encode

class LoginPage extends StatefulWidget {  // Changed to StatefulWidget
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _usernameController = TextEditingController();  // Changed from email
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;

  // Move styles to the state class and make them static
  static final TextStyle inputTextStyle = GoogleFonts.openSans(
    textStyle: const TextStyle(
      fontSize: 16,
      color: Color.fromARGB(255, 24, 24, 24),
    ),
  );

  static final TextStyle buttonTextStyle = GoogleFonts.roboto(
    textStyle: const TextStyle(
      fontSize: 16,
      color: Color.fromARGB(255, 255, 255, 255),
    ),
  );

  String _hashPasswordWithSalt(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _handleLogin() async {
    setState(() {
      _isLoading = true;
    });

    try {
      print('Attempting to login...');
      
      final userQuery = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: _usernameController.text.trim())
          .get();

      if (userQuery.docs.isEmpty) {
        _showError('Invalid username or password');
        return;
      }

      final userDoc = userQuery.docs.first;
      final userData = userDoc.data();
      
      // Verify password
      final salt = userData['salt'] as String;
      final hashedPassword = _hashPasswordWithSalt(_passwordController.text, salt);
      
      if (hashedPassword != userData['hashedPassword']) {
        _showError('Invalid username or password');
        return;
      }

      final user = UserData.fromMap(userData);
      final userId = userDoc.id;

      // Store user ID
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userId);

      if (!mounted) return;

      // Check initial health questionnaire completion
      final bool hasCompletedInitialHealth = userData['hasCompletedInitialQuestionnaire'] ?? false;
      final initialHealth = userData['initialHealth'];

      // Redirect based on questionnaire status
      if (!hasCompletedInitialHealth || initialHealth == null) {
        print('Initial health assessment not completed - redirecting to questionnaire');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => InitialHealthScreen(userData: user),
          ),
          (Route<dynamic> route) => false,
        );
      } else {
        print('Initial health assessment completed - redirecting to home');
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => HomeScreen(userName: user.name),
          ),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print('Login error: $e');
      _showError('Login failed. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
        // Add this theme data
        primaryColor: const Color.fromRGBO(66, 96, 208, 1),
        focusColor: const Color.fromRGBO(66, 96, 208, 1),
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24),
            borderSide: const BorderSide(
              color: Color.fromRGBO(66, 96, 208, 1),
              width: 2.0,
            ),
          ),
          focusColor: const Color.fromRGBO(66, 96, 208, 1),
        ),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            _buildBackground(),
            _buildContent(context),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Positioned.fill(
      child: Image.asset(
        'assets/images/on_board_bg.png',
        fit: BoxFit.cover,
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        children: [
          const SizedBox(height: 50), // Add some space at the top
          _buildHeader(context),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  _buildEmailInput(),
                  const SizedBox(height: 10),
                  _buildPasswordInput(),
                  const SizedBox(height: 50),
                  _buildLoginButton(context),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back, color: Color.fromRGBO(0, 87, 160, 1)),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            const Spacer(),
          ],
        ),
        const SizedBox(height: 40), // Increased space from 20 to 40
        Center(
          child: Text(
            'Welcome Back',
            style: GoogleFonts.openSans(
              textStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(66, 96, 208, 1),
                height: 1.5, // Adjusted line height to match input field
              ),
            ),
          ),
        ),
        const SizedBox(height: 30), // Add space between "Welcome Back" and input field
      ],
    );
  }

  Widget _buildEmailInput() {  // Rename but keep method name for now
    return SizedBox(
      width: 305,
      child: TextField(
        controller: _usernameController,
        decoration: InputDecoration(
          labelText: 'Username',  // Changed from Email
          labelStyle: inputTextStyle,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24), // Increased from 12 to 24
          ),
          prefixIcon: const Icon(
            Icons.person,
            color: Color.fromRGBO(90, 155, 213, 1),
          ),
        ),
        style: inputTextStyle,
      ),
    );
  }

  Widget _buildPasswordInput() {
    return PasswordInput(
      controller: _passwordController,
      textStyle: inputTextStyle, // Pass the style
    );
  }

  Widget _buildLoginButton(BuildContext context) {
    return Column(
      children: [
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
            onPressed: _isLoading ? null : _handleLogin,
            child: Center(
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text('Login', style: buttonTextStyle), // Updated reference
            ),
          ),
        ),
        const SizedBox(height: 5),
        TextButton(
          onPressed: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SignupPage()),
            );
          },
          child: Text(
            'New User? Register',
            style: GoogleFonts.roboto(
              textStyle: const TextStyle(
                fontSize: 16,
                color: Color.fromRGBO(66, 96, 208, 1),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class PasswordInput extends StatefulWidget {
  final TextEditingController controller;
  final TextStyle textStyle; // Add textStyle parameter

  const PasswordInput({
    super.key,
    required this.controller,
    required this.textStyle, // Add to constructor
  });

  @override
  _PasswordInputState createState() => _PasswordInputState();
}

class _PasswordInputState extends State<PasswordInput> {
  bool obscureText = true;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 305,
      child: TextField(
        controller: widget.controller,
        decoration: InputDecoration(
          labelText: 'Password',
          labelStyle: widget.textStyle, // Use passed style
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24), // Increased from 12 to 24
          ),
          prefixIcon: const Icon(
            Icons.lock,
            color: Color.fromRGBO(90, 155, 213, 1),
          ),
          suffixIcon: IconButton(
            icon: Icon(
              obscureText ? Icons.visibility : Icons.visibility_off,
              color: const Color.fromARGB(255, 108, 117, 125),
            ),
            onPressed: () {
              setState(() {
                obscureText = !obscureText;
              });
            },
          ),
        ),
        obscureText: obscureText,
        style: widget.textStyle, // Use passed style
      ),
    );
  }
}
