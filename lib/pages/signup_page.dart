import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart'; // Add this import
import 'package:medknows/pages/initial_health_screen.dart';
import '../models/user_data.dart';  // Updated to lowercase path
import 'package:medknows/pages/home_screen.dart'; // Add this import
import 'package:flutter/services.dart';  // Add this import for TextInputFormatter
import 'package:crypto/crypto.dart';
import 'dart:convert';
import 'dart:math';
import 'package:shared_preferences/shared_preferences.dart'; // Add this import

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
  final TextEditingController _heightFeetController = TextEditingController();
  final TextEditingController _heightInchController = TextEditingController();
  
  bool _isLoading = false;
  String _sex = 'Male';
  String _heightUnit = 'cm';
  String _weightUnit = 'kg';
  bool _passwordVisible = false;
  bool _confirmPasswordVisible = false;

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

  double _convertHeight(String value) {
    if (_heightUnit == 'cm') {
      return double.tryParse(value) ?? 0;
    } else {
      // Convert feet and inches to cm
      double feet = double.tryParse(_heightFeetController.text) ?? 0;
      double inches = double.tryParse(_heightInchController.text) ?? 0;
      return (feet * 30.48) + (inches * 2.54);
    }
  }

  void _updateFeetAndInches(String cmValue) {
    if (cmValue.isEmpty) {
      _heightFeetController.text = '';
      _heightInchController.text = '';
      return;
    }

    double cm = double.tryParse(cmValue) ?? 0;
    double totalInches = cm / 2.54;
    int feet = (totalInches / 12).floor();
    double inches = totalInches % 12;
    
    _heightFeetController.text = feet.toString();
    _heightInchController.text = inches.toStringAsFixed(1);
  }

  double _convertWeight(String value) {
    if (value.isEmpty) return 0;
    double weight = double.tryParse(value) ?? 0;
    if (_weightUnit == 'lbs') {
      // Convert pounds to kilograms
      return weight * 0.453592;
    }
    return weight;
  }

  bool _validatePassword(String password) {
    if (password.length < 8) return false;
    if (!RegExp(r'[A-Z]').hasMatch(password)) return false;
    if (!RegExp(r'[a-z]').hasMatch(password)) return false;
    if (!RegExp(r'[0-9]').hasMatch(password)) return false;
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) return false;
    return true;
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
    if (!_validatePassword(_passwordController.text)) {
      _showError('Password must be at least 8 characters and contain:\n- Upper & lowercase letters\n- Numbers\n- Special characters');
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
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _buildHeightInput(),
                const SizedBox(width: 10),
                _buildUnitToggle(_heightUnit, ['cm', 'ft'], (String? newValue) {
                  setState(() {
                    if (newValue != null) {
                      if (newValue == 'ft' && _heightUnit == 'cm') {
                        // Converting from cm to feet/inches
                        _updateFeetAndInches(_heightController.text);
                      } else if (newValue == 'cm' && _heightUnit == 'ft') {
                        // Already have the cm value in _heightController
                      }
                      _heightUnit = newValue;
                    }
                  });
                }),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 200, // Slightly reduced width to accommodate switch
                  child: _buildTextField(
                    'Weight (${_weightUnit})', 
                    controller: _weightController, 
                    isNumeric: true
                  ),
                ),
                const SizedBox(width: 10),
                _buildUnitToggle(_weightUnit, ['kg', 'lbs'], (String? newValue) {
                  setState(() {
                    if (newValue != null) {
                      String currentValue = _weightController.text;
                      if (currentValue.isNotEmpty) {
                        double value = double.tryParse(currentValue) ?? 0;
                        if (newValue == 'lbs' && _weightUnit == 'kg') {
                          _weightController.text = (value * 2.20462).toStringAsFixed(2);
                        } else if (newValue == 'kg' && _weightUnit == 'lbs') {
                          _weightController.text = (value / 2.20462).toStringAsFixed(2);
                        }
                      }
                      _weightUnit = newValue;
                    }
                  });
                }),
              ],
            ),
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
    bool isNumeric = false,
    ValueChanged<String>? onChanged,
  }) {
    // Special handling for password fields
    if (label == 'Password' || label == 'Confirm Password') {
      bool isVisible = label == 'Password' ? _passwordVisible : _confirmPasswordVisible;
      return SizedBox(
        width: 305,
        child: TextField(
          controller: controller,
          obscureText: !isVisible,
          enabled: enabled,
          decoration: InputDecoration(
            labelText: label,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                isVisible ? Icons.visibility : Icons.visibility_off,
                color: const Color.fromRGBO(66, 96, 208, 1),
              ),
              onPressed: () {
                setState(() {
                  if (label == 'Password') {
                    _passwordVisible = !_passwordVisible;
                  } else {
                    _confirmPasswordVisible = !_confirmPasswordVisible;
                  }
                });
              },
            ),
          ),
          onTap: onTap,
          onChanged: onChanged,
        ),
      );
    }

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
        onChanged: onChanged, // Add this line
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

  Widget _buildUnitToggle(String currentValue, List<String> units, void Function(String?) onChanged) {
    return SizedBox(
      width: 100, // Fixed width
      height: 40,  // Fixed height
      child: Container(
        decoration: BoxDecoration(
          color: Colors.grey.shade200,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Stack(
          children: [
            AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeInOut,
              alignment: currentValue == units[0] 
                  ? Alignment.centerLeft 
                  : Alignment.centerRight,
              child: Container(
                width: 50,
                height: 36,
                margin: const EdgeInsets.symmetric(horizontal: 2),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.max,
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(units[0]),
                    child: Center(
                      child: Text(
                        units[0],
                        style: TextStyle(
                          color: currentValue == units[0] 
                              ? const Color.fromRGBO(66, 96, 208, 1)
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => onChanged(units[1]),
                    child: Center(
                      child: Text(
                        units[1],
                        style: TextStyle(
                          color: currentValue == units[1] 
                              ? const Color.fromRGBO(66, 96, 208, 1)
                              : Colors.grey,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeightInput() {
    if (_heightUnit == 'cm') {
      return SizedBox(
        width: 200,
        child: _buildTextField(
          'Height (cm)', 
          controller: _heightController,
          isNumeric: true
        ),
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 100,
            child: _buildTextField(
              'Feet',
              controller: _heightFeetController,
              isNumeric: true,
              onChanged: (value) {
                if (_heightFeetController.text.isNotEmpty || _heightInchController.text.isNotEmpty) {
                  double totalCm = _convertHeight('');
                  _heightController.text = totalCm.toStringAsFixed(2);
                }
              },
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 100,
            child: _buildTextField(
              'Inches',
              controller: _heightInchController,
              isNumeric: true,
              onChanged: (value) {
                if (_heightFeetController.text.isNotEmpty || _heightInchController.text.isNotEmpty) {
                  double totalCm = _convertHeight('');
                  _heightController.text = totalCm.toStringAsFixed(2);
                }
              },
            ),
          ),
        ],
      );
    }
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

      // Create a new document with auto-generated ID
      final userRef = FirebaseFirestore.instance.collection('users').doc();
      
      // Create UserData instance with the generated ID
      final userData = UserData(
        id: userRef.id, // Use the generated ID
        username: _usernameController.text.trim(),
        name: _nameController.text,
        birthdate: _birthdateController.text,
        age: int.parse(_ageController.text),
        sex: _sex,
        height: _convertHeight(_heightController.text),
        weight: _convertWeight(_weightController.text),
      );

      final Map<String, dynamic> dataToSave = {
        ...userData.toMap(),
        'hashedPassword': hashedPassword,
        'salt': salt,
        'createdAt': FieldValue.serverTimestamp(),
      };

      // Remove any plain text password field
      dataToSave.remove('password');

      // Save to Firestore and store user ID in SharedPreferences
      await userRef.set(dataToSave);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('userId', userRef.id);

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

      // Navigate to initial health questionnaire
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (context) => InitialHealthScreen(
            userData: userData,
          ),
        ),
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
