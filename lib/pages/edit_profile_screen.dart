import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:medknows/pages/home_screen.dart';
import 'package:medknows/pages/initial_health_screen.dart';  // Add this import
import '../models/user_data.dart';

class EditProfileScreen extends StatefulWidget {
  final UserData userData;

  const EditProfileScreen({Key? key, required this.userData}) : super(key: key);

  @override
  _EditProfileScreenState createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  late TabController _tabController;
  late TextEditingController _nameController;
  late TextEditingController _heightController;
  late TextEditingController _weightController;
  final _oldPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmNewPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _showProfileSection = true; // Add this line

  // Add new state variables for unit conversion
  String _heightUnit = 'cm';
  String _weightUnit = 'kg';
  late TextEditingController _heightFeetController;
  late TextEditingController _heightInchController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);  // Changed from 2 to 3
    _nameController = TextEditingController(text: widget.userData.name);
    _heightController = TextEditingController(text: widget.userData.height.toString());
    _weightController = TextEditingController(text: widget.userData.weight.toString());
    
    // Initialize feet/inches controllers
    double totalInches = widget.userData.height / 2.54;
    int feet = (totalInches / 12).floor();
    double inches = totalInches % 12;
    _heightFeetController = TextEditingController(text: feet.toString());
    _heightInchController = TextEditingController(text: inches.toStringAsFixed(1));
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      // Convert measurements to standard units (cm and kg) before saving
      double heightInCm = _heightUnit == 'cm'
          ? double.parse(_heightController.text)
          : (double.parse(_heightFeetController.text) * 30.48) +
            (double.parse(_heightInchController.text) * 2.54);

      double weightInKg = _weightUnit == 'kg'
          ? double.parse(_weightController.text)
          : double.parse(_weightController.text) / 2.20462;

      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userData.id);

      Map<String, dynamic> updateData = {
        'name': _nameController.text,
        'height': heightInCm,
        'weight': weightInKg,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Handle password change if requested
      if (_oldPasswordController.text.isNotEmpty) {
        final userDoc = await userRef.get();
        final String storedSalt = userDoc.data()?['salt'] ?? '';
        final String storedHash = userDoc.data()?['hashedPassword'] ?? '';
        
        final oldPasswordHash = _hashPasswordWithSalt(_oldPasswordController.text, storedSalt);
        if (oldPasswordHash != storedHash) {
          throw 'Incorrect old password';
        }

        final newSalt = _generateSalt();
        final newHashedPassword = _hashPasswordWithSalt(_newPasswordController.text, newSalt);
        
        updateData.addAll({
          'salt': newSalt,
          'hashedPassword': newHashedPassword,
        });
      }

      // Update main user document
      batch.update(userRef, updateData);

      // Add to update history collection
      batch.set(
        userRef.collection('updates').doc(),
        {
          ...updateData,
          'timestamp': FieldValue.serverTimestamp(),
          'type': 'profile_update',
        },
      );

      // Commit all updates
      await batch.commit();

      // Fetch updated user data
      final updatedDoc = await userRef.get();
      final updatedUserData = UserData.fromMap({
        'id': widget.userData.id,
        ...updatedDoc.data() ?? {},
      });

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Profile updated successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Navigate to HomeScreen with updated data
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            userName: updatedUserData.name,
            initialIndex: 0,
          ),
        ),
        (route) => false, // This removes all previous routes
      );

    } catch (e) {
      print('Error updating profile: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          backgroundColor: Colors.red,
        ),
      );
    }

    setState(() => _isLoading = false);
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

  // Add conversion methods
  void _updateHeightValue(String unit) {
    if (unit == _heightUnit) return;

    if (unit == 'ft') {
      // Convert cm to feet/inches
      double cm = double.tryParse(_heightController.text) ?? 0;
      double totalInches = cm / 2.54;
      int feet = (totalInches / 12).floor();
      double inches = totalInches % 12;
      _heightFeetController.text = feet.toString();
      _heightInchController.text = inches.toStringAsFixed(1);
    } else {
      // Convert feet/inches to cm
      int feet = int.tryParse(_heightFeetController.text) ?? 0;
      double inches = double.tryParse(_heightInchController.text) ?? 0;
      double cm = (feet * 30.48) + (inches * 2.54);
      _heightController.text = cm.toStringAsFixed(1);
    }
    setState(() => _heightUnit = unit);
  }

  void _updateWeightValue(String unit) {
    if (unit == _weightUnit) return;

    double currentWeight = double.tryParse(_weightController.text) ?? 0;
    if (unit == 'lbs') {
      // Convert kg to lbs
      _weightController.text = (currentWeight * 2.20462).toStringAsFixed(1);
    } else {
      // Convert lbs to kg
      _weightController.text = (currentWeight / 2.20462).toStringAsFixed(1);
    }
    setState(() => _weightUnit = unit);
  }

  Widget _buildProfileSection() {
    return Column(
      children: [
        TextFormField(
          initialValue: widget.userData.username,
          enabled: false,
          decoration: InputDecoration(
            labelText: 'Username',
            labelStyle: TextStyle(color: Colors.grey),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            filled: true,
            fillColor: Colors.grey[200],
          ),
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _nameController,
          decoration: InputDecoration(
            labelText: 'Name',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your name';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: _heightUnit == 'cm'
                ? TextFormField(
                    controller: _heightController,
                    decoration: InputDecoration(
                      labelText: 'Height (cm)',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter height';
                      }
                      final height = double.tryParse(value);
                      if (height == null || height <= 0) {
                        return 'Invalid height';
                      }
                      return null;
                    },
                  )
                : Row(
                    children: [
                      Expanded(
                        child: TextFormField(
                          controller: _heightFeetController,
                          decoration: InputDecoration(
                            labelText: 'Feet',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: TextFormField(
                          controller: _heightInchController,
                          decoration: InputDecoration(
                            labelText: 'Inches',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          keyboardType: TextInputType.number,
                        ),
                      ),
                    ],
                  ),
            ),
            SizedBox(width: 8),
            _buildUnitToggle(_heightUnit, ['cm', 'ft'], _updateHeightValue),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _weightController,
                decoration: InputDecoration(
                  labelText: 'Weight (${_weightUnit})',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                keyboardType: TextInputType.number,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter weight';
                  }
                  final weight = double.tryParse(value);
                  if (weight == null || weight <= 0) {
                    return 'Invalid weight';
                  }
                  return null;
                },
              ),
            ),
            SizedBox(width: 8),
            _buildUnitToggle(_weightUnit, ['kg', 'lbs'], _updateWeightValue),
          ],
        ),
      ],
    );
  }

  // Add unit toggle widget
  Widget _buildUnitToggle(String currentUnit, List<String> units, Function(String) onChanged) {
    return Container(
      width: 80,
      height: 56,
      decoration: BoxDecoration(
        color: Colors.blue.shade50,  // Updated from grey
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: units.map((unit) => 
          GestureDetector(
            onTap: () => onChanged(unit),
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: currentUnit == unit ? Colors.blue : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                unit,
                style: TextStyle(
                  color: currentUnit == unit ? Colors.white : Colors.blue.shade700,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        ).toList(),
      ),
    );
  }

  bool _validatePassword(String password) {
    if (password.length < 8) return false;
    if (!RegExp(r'[A-Z]').hasMatch(password)) return false;
    if (!RegExp(r'[a-z]').hasMatch(password)) return false;
    if (!RegExp(r'[0-9]').hasMatch(password)) return false;
    if (!RegExp(r'[!@#\$%^&*(),.?":{}|<>]').hasMatch(password)) return false;
    return true;
  }

  Widget _buildPasswordSection() {
    return Column(
      children: [
        TextFormField(
          controller: _oldPasswordController,
          decoration: InputDecoration(
            labelText: 'Old Password',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _oldPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.blue,
              ),
              onPressed: () => setState(() => _oldPasswordVisible = !_oldPasswordVisible),
            ),
          ),
          obscureText: !_oldPasswordVisible,
          validator: (value) {
            if (value?.isEmpty ?? true) return null;
            if (_newPasswordController.text.isEmpty) {
              return 'Please enter new password';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _newPasswordController,
          decoration: InputDecoration(
            labelText: 'New Password',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _newPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.blue,
              ),
              onPressed: () => setState(() => _newPasswordVisible = !_newPasswordVisible),
            ),
          ),
          obscureText: !_newPasswordVisible,
          validator: (value) {
            if (value?.isEmpty ?? true) return null;
            if (_oldPasswordController.text.isEmpty) {
              return 'Please enter old password';
            }
            if (!_validatePassword(value!)) {
              return 'Password must be at least 8 characters and contain:\n• Upper & lowercase letters\n• Numbers\n• Special characters';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _confirmNewPasswordController,
          decoration: InputDecoration(
            labelText: 'Confirm New Password',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            suffixIcon: IconButton(
              icon: Icon(
                _confirmPasswordVisible ? Icons.visibility : Icons.visibility_off,
                color: Colors.blue,
              ),
              onPressed: () => setState(() => _confirmPasswordVisible = !_confirmPasswordVisible),
            ),
          ),
          obscureText: !_confirmPasswordVisible,
          validator: (value) {
            if (value?.isEmpty ?? true) return null;
            if (value != _newPasswordController.text) {
              return 'Passwords do not match';
            }
            return null;
          },
        ),
      ],
    );
  }

  // Add this new method
  Widget _buildHealthSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Health Information',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        SizedBox(height: 16),
        Text(
          'You can update your health information if there have been any changes.',
          style: TextStyle(
            color: Colors.grey[600],
          ),
        ),
        SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InitialHealthScreen(
                    userData: widget.userData,
                    isEditing: true,  // Add this property to InitialHealthScreen
                  ),
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text('Update Health Information'),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        // Override the default colors to use blue shades
        colorScheme: ColorScheme.light(
          primary: Colors.blue,
          secondary: Colors.blue.shade700,
        ),
        // Update checkbox and radio colors
        checkboxTheme: CheckboxThemeData(
          fillColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.blue;
            }
            return Colors.grey;
          }),
        ),
        radioTheme: RadioThemeData(
          fillColor: MaterialStateProperty.resolveWith<Color>((states) {
            if (states.contains(MaterialState.selected)) {
              return Colors.blue;
            }
            return Colors.grey;
          }),
        ),
        // Update input decoration theme
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue, width: 2),
          ),
          focusColor: Colors.blue,
          labelStyle: TextStyle(color: Colors.blue.shade700),
        ),
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Edit Profile'),
          bottom: PreferredSize(
            preferredSize: Size.fromHeight(48),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: Colors.blue.shade100,
                    width: 1.0,
                  ),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                tabs: [
                  Tab(
                    child: Text(
                      'Profile',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Tab(
                    child: Text(
                      'Password',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                  Tab(
                    child: Text(
                      'Health',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),  // Add this tab
                ],
                indicatorColor: Colors.blue.shade700,
                indicatorWeight: 3,
                indicatorSize: TabBarIndicatorSize.label,
                labelColor: Colors.blue.shade700,
                unselectedLabelColor: Colors.blue.shade200,
                labelStyle: TextStyle(
                  fontWeight: FontWeight.w600,
                ),
                unselectedLabelStyle: TextStyle(
                  fontWeight: FontWeight.normal,
                ),
              ),
            ),
          ),
          actions: [
            if (_isLoading)
              Center(
                child: Padding(
                  padding: EdgeInsets.only(right: 16.0),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ),
          ],
        ),
        body: SafeArea(  // Add SafeArea
          child: Padding(
            padding: EdgeInsets.fromLTRB(16.0, 8.0, 16.0, 16.0),  // Adjusted padding
            child: Form(
              key: _formKey,
              child: Column(
                children: [
                  Expanded(
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        SingleChildScrollView(
                          child: Padding(
                            padding: EdgeInsets.only(top: 16.0),  // Add top padding
                            child: _buildProfileSection(),
                          ),
                        ),
                        SingleChildScrollView(
                          child: Padding(
                            padding: EdgeInsets.only(top: 16.0),  // Add top padding
                            child: _buildPasswordSection(),
                          ),
                        ),
                        SingleChildScrollView(
                          child: Padding(
                            padding: EdgeInsets.only(top: 16.0),  // Add top padding
                            child: _buildHealthSection(),
                          ),
                        ),
                      ],
                    ),
                  ),
                  // Bottom Buttons
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        style: TextButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text('Cancel'),
                      ),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _updateProfile,
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                        ),
                        child: Text('Update Profile'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmNewPasswordController.dispose();
    _heightFeetController.dispose();
    _heightInchController.dispose();
    super.dispose();
  }

  // Add these variables at the top of the class with other state variables
  bool _oldPasswordVisible = false;
  bool _newPasswordVisible = false;
  bool _confirmPasswordVisible = false;
}
