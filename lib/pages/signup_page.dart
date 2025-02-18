import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; // Add this import
import '../models/user_data.dart';  // Updated to lowercase path
import 'package:medknows/pages/home_screen.dart'; // Add this import
import 'package:flutter/services.dart';  // Add this import for TextInputFormatter
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  _SignupPageState createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage> {
  final PageController _pageController = PageController();
  final TextEditingController _birthdateController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _usernameController = TextEditingController();  // Changed from email
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  
  bool _isLoading = false;
  String _sex = 'Male';

  @override
  void initState() {
    super.initState();
    _checkFirebaseInitialization();
  }

  Future<void> _checkFirebaseInitialization() async {
    try {
      await Firebase.initializeApp();
      print('Firebase initialized successfully');
    } catch (e) {
      print('Failed to initialize Firebase: $e');
    }
  }

  void _calculateAge(String birthdate) {
    final birthDate = DateFormat('MM/dd/yyyy').parse(birthdate);
    final today = DateTime.now();
    int age = today.year - birthDate.year;
    if (today.month < birthDate.month || (today.month == birthDate.month && today.day < birthDate.day)) {
      age--;
    }
    _ageController.text = age.toString();
  }

  bool _validateFirstPage() {
    if (_usernameController.text.trim().isEmpty) {
      _showError('Please enter a username');
      return false;
    }
    if (_passwordController.text.isEmpty) {
      _showError('Please enter your password');
      return false;
    }
    if (_confirmPasswordController.text.isEmpty) {
      _showError('Please confirm your password');
      return false;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      _showError('Passwords do not match');
      return false;
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: ThemeData(
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
          labelStyle: const TextStyle(
            color: Color.fromRGBO(66, 96, 208, 1),
          ),
          focusColor: const Color.fromRGBO(66, 96, 208, 1),
        ),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            Positioned.fill(
              child: Image.asset(
                'assets/images/on_board_bg.png',
                fit: BoxFit.cover,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0),
              child: PageView(
                controller: _pageController,
                children: [
                  _buildRegisterPage(context),
                  _buildPersonalInfoPage(context),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRegisterPage(BuildContext context) {
    return Column(
      children: [
        const SizedBox(height: 50),
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
        const SizedBox(height: 20),
        Center(
          child: Text(
            'Register',
            style: GoogleFonts.openSans(
              textStyle: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color.fromRGBO(66, 96, 208, 1),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        _buildTextField('Username', controller: _usernameController),  // Changed from email
        const SizedBox(height: 10),
        _buildTextField('Password', controller: _passwordController, obscureText: true),
        const SizedBox(height: 10),
        _buildTextField('Confirm Password', controller: _confirmPasswordController, obscureText: true),
        const SizedBox(height: 50),
        _buildNextButton(),
      ],
    );
  }

  Widget _buildPersonalInfoPage(BuildContext context) {
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 16.0,
        ),
        child: Column(
          children: [
            const SizedBox(height: 50),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.arrow_back, color: Color.fromRGBO(0, 87, 160, 1)),
                  onPressed: () {
                    _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
                  },
                ),
                const Spacer(),
              ],
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Personal Information',
                style: GoogleFonts.openSans(
                  textStyle: const TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color.fromRGBO(66, 96, 208, 1),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 20),
            _buildTextField('Name', controller: _nameController),
            const SizedBox(height: 10),
            _buildTextField('Birthdate', controller: _birthdateController, onTap: () async {
              DateTime? pickedDate = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(1900),
                lastDate: DateTime.now(),
              );
              if (pickedDate != null) {
                String formattedDate = DateFormat('MM/dd/yyyy').format(pickedDate);
                _birthdateController.text = formattedDate;
                _calculateAge(formattedDate);
              }
            }),
            const SizedBox(height: 10),
            _buildTextField('Age', controller: _ageController, enabled: false),
            const SizedBox(height: 10),
            _buildDropdown('Sex', ['Male', 'Female'], (value) {
              setState(() {
                _sex = value!;
                _calculateAge(_birthdateController.text);
              });
            }),
            const SizedBox(height: 10),
            _buildTextField('Height (cm)', controller: _heightController, isNumeric: true),  // Add isNumeric: true
            const SizedBox(height: 10),
            _buildTextField('Weight (kg)', controller: _weightController, isNumeric: true),  // Add isNumeric: true
            const SizedBox(height: 50),
            _buildRegisterButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField(String label, {
    TextEditingController? controller, 
    bool obscureText = false, 
    bool enabled = true, 
    VoidCallback? onTap,
    bool isNumeric = false  // Add this parameter
  }) {
    return SizedBox(
      width: 305,
      child: TextField(
        controller: controller,
        obscureText: obscureText,
        enabled: enabled,
        keyboardType: isNumeric ? TextInputType.number : TextInputType.text,  // Add keyboard type
        inputFormatters: isNumeric ? [
          FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),  // Only allow numbers and decimal point
        ] : null,
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24), // More rounded corners
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, ValueChanged<String?> onChanged) {
    return SizedBox(
      width: 305,
      child: DropdownButtonFormField<String>(
        decoration: InputDecoration(
          labelText: label,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24), // More rounded corners
          ),
        ),
        items: items.map((String value) {
          return DropdownMenuItem<String>(
            value: value,
            child: Text(value),
          );
        }).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildNextButton() {
    return SizedBox(
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
          if (_validateFirstPage()) {
            _pageController.nextPage(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
            );
          }
        },
        child: Center(
          child: Text(
            'Next',
            style: GoogleFonts.roboto(
              textStyle: const TextStyle(
                fontSize: 16,
                color: Color.fromARGB(255, 255, 255, 255),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRegisterButton() {
    return SizedBox(
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
        onPressed: _isLoading ? null : _registerUser,
        child: Center(
          child: _isLoading
              ? Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      'Creating Account...',
                      style: GoogleFonts.roboto(
                        textStyle: const TextStyle(
                          fontSize: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                )
              : Text(
                  'Register',
                  style: GoogleFonts.roboto(
                    textStyle: const TextStyle(
                      fontSize: 16,
                      color: Colors.white,
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  String _generateSalt() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (i) => random.nextInt(256));
    return base64Url.encode(bytes);
  }

  String _hashPasswordWithSalt(String password, String salt) {
    final bytes = utf8.encode(password + salt);
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<void> _registerUser() async {
    if (!mounted) return;

    print('Starting registration process...');
    
    try {
      setState(() {
        _isLoading = true;
      });

      // Verify Firebase initialization
      if (!Firebase.apps.isNotEmpty) {
        print('Firebase not initialized, attempting initialization...');
        await Firebase.initializeApp();
      }

      // Check for existing username
      final usernameCheck = await FirebaseFirestore.instance
          .collection('users')
          .where('username', isEqualTo: _usernameController.text.trim())
          .get();

      if (usernameCheck.docs.isNotEmpty) {
        _showError('Username already exists');
        return;
      }

      // Generate a unique salt for this user
      final salt = _generateSalt();
      final hashedPassword = _hashPasswordWithSalt(_passwordController.text, salt);

      final docRef = FirebaseFirestore.instance.collection('users').doc();
      
      // Create UserData instance
      final userData = UserData(
        id: docRef.id,
        username: _usernameController.text.trim(),
        name: _nameController.text,
        birthdate: _birthdateController.text,
        age: int.parse(_ageController.text),
        sex: _sex,
        height: double.parse(_heightController.text),
        weight: double.parse(_weightController.text),
      );

      final Map<String, dynamic> dataToSave = {
        ...userData.toMap(),
        'hashedPassword': hashedPassword,
        'salt': salt, // Store salt separately
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Remove any plain text password field
      dataToSave.remove('password');

      await docRef.set(dataToSave);
      
      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Account created successfully!'),
          backgroundColor: Colors.green,
        ),
      );

      // Wait for snackbar to show
      await Future.delayed(const Duration(seconds: 1));
      
      if (!mounted) return;

      // Navigate to intro page and clear stack
      Navigator.of(context).pushNamedAndRemoveUntil(
        '/', // Your intro route
        (Route<dynamic> route) => false,
      );

    } catch (e) {
      print('Registration error: $e');
      _showError('Error creating account. Please try again.');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _showError(String message) {
    print('Error: $message');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
