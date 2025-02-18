import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:medknows/pages/home_screen.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController = TextEditingController(text: widget.userData.name);
    _heightController = TextEditingController(text: widget.userData.height.toString());
    _weightController = TextEditingController(text: widget.userData.weight.toString());
  }

  Future<void> _updateProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final batch = FirebaseFirestore.instance.batch();
      final userRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userData.id);

      Map<String, dynamic> updateData = {
        'name': _nameController.text,
        'height': double.parse(_heightController.text),
        'weight': double.parse(_weightController.text),
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
        TextFormField(
          controller: _heightController,
          decoration: InputDecoration(
            labelText: 'Height (cm)',
            suffixText: 'cm',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your height';
            }
            final height = double.tryParse(value);
            if (height == null || height <= 0) {
              return 'Please enter a valid height';
            }
            return null;
          },
        ),
        SizedBox(height: 16),
        TextFormField(
          controller: _weightController,
          decoration: InputDecoration(
            labelText: 'Weight (kg)',
            suffixText: 'kg',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          keyboardType: TextInputType.number,
          validator: (value) {
            if (value == null || value.isEmpty) {
              return 'Please enter your weight';
            }
            final weight = double.tryParse(value);
            if (weight == null || weight <= 0) {
              return 'Please enter a valid weight';
            }
            return null;
          },
        ),
      ],
    );
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
          ),
          obscureText: true,
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
          ),
          obscureText: true,
          validator: (value) {
            if (value?.isEmpty ?? true) return null;
            if (_oldPasswordController.text.isEmpty) {
              return 'Please enter old password';
            }
            if (value!.length < 6) {
              return 'Password must be at least 6 characters';
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
          ),
          obscureText: true,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    super.dispose();
  }
}
