import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:medknows/main.dart';
import 'package:medknows/models/user_data.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medknows/pages/edit_profile_screen.dart';  // Add this import
import 'package:medknows/pages/home_screen.dart'; // Add this import
import 'package:medknows/pages/history_screen.dart';  // Add this import
import 'package:medknows/utils/active_medicine_manager.dart';  // Add this import
import 'package:flutter/services.dart';  // Add this import
import 'package:medknows/pages/add_medicine_screen.dart';  // Add this import

class ProfileScreen extends StatefulWidget {
  final Function(UserData)? onProfileUpdate;
  final Function(String)? onNameUpdate; // Add this

  const ProfileScreen({Key? key, this.onProfileUpdate, this.onNameUpdate}) : super(key: key);

  @override
  _ProfileScreenState createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  UserData? _userData;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      // Get the stored user ID from SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('userId');

      if (userId == null || userId.isEmpty) {
        print('No user ID found');
        setState(() => _isLoading = false);
        return;
      }
      
      final userData = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      if (userData.exists) {
        setState(() {
          _userData = UserData.fromMap(userData.data()!);
          _isLoading = false;
        });
      } else {
        print('No user data found for ID: $userId');
        setState(() => _isLoading = false);
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _handleLogout() async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(
            'Sign Out',
            style: GoogleFonts.openSans(
              fontWeight: FontWeight.bold,
            ),
          ),
          content: Text(
            'Are you sure you want to sign out?',
            style: GoogleFonts.openSans(),
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                'Cancel',
                style: GoogleFonts.openSans(
                  color: Colors.grey,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text(
                'Sign Out',
                style: GoogleFonts.openSans(
                  color: Colors.red,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        );
      },
    );

    if (confirm == true) {
      try {
        // Clear active medicine data
        await ActiveMedicineManager.clearActiveMedicine();
        
        // Clear shared preferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.clear();

        if (!mounted) return;

        // Restart app from scratch
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (context) => const MyApp()),
          (route) => false,
        );
      } catch (e) {
        print('Error during logout: $e');
        if (!mounted) return;
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error signing out. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _navigateToHistory() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => HistoryScreen(),  // You'll need to create this screen
      ),
    );
  }

  void _navigateToEditProfile() async {
    if (_userData != null) {
      final updatedUserData = await Navigator.push<UserData>(
        context,
        MaterialPageRoute(
          builder: (context) => EditProfileScreen(userData: _userData!),
        ),
      );
      
      if (updatedUserData != null) {
        // The EditProfileScreen will handle navigation now
        // No need to do anything here as we'll be rebuilding from scratch
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : ListView(
            children: [
              Container(
                color: Colors.blue,
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      _userData?.name ?? 'User',
                      style: GoogleFonts.openSans(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    Text(
                      '@${_userData?.username ?? 'username'}',
                      style: GoogleFonts.openSans(
                        fontSize: 16,
                        color: Colors.white70,
                      ),
                    ),
                    // Additional user info
                    const SizedBox(height: 8),
                    Text(
                      '${_userData?.age ?? 'N/A'}',
                      style: GoogleFonts.openSans(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                    Text(
                      '${_userData?.sex ?? 'N/A'}',
                      style: GoogleFonts.openSans(
                        fontSize: 14,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(
                  'Edit Profile',
                  style: GoogleFonts.openSans(),
                ),
                onTap: () async {
                  if (_userData != null) {
                    final updated = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => EditProfileScreen(userData: _userData!),
                      ),
                    );
                    
                    // Reload user data if profile was updated
                    if (updated == true) {
                      setState(() => _isLoading = true);
                      await _loadUserData();
                      // Navigate back to HomeScreen with updated name
                      if (!mounted) return;
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(
                          builder: (context) => HomeScreen(
                            userName: _userData?.name ?? 'User',
                            initialIndex: 0,
                          ),
                        ),
                      );
                    }
                  }
                },
              ),
              // ListTile(
              //   leading: const Icon(Icons.medical_services_outlined),
              //   title: Text(
              //     'Add Medicine',
              //     style: GoogleFonts.openSans(),
              //   ),
              //   onTap: () {
              //     Navigator.push(
              //       context,
              //       MaterialPageRoute(
              //         builder: (context) => const AddMedicineScreen(),
              //       ),
              //     );
              //   },
              // ),
              ListTile(
                leading: const Icon(Icons.history),
                title: Text(
                  'History',
                  style: GoogleFonts.openSans(),
                ),
                onTap: _navigateToHistory,
              ),
              const Divider(),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: Text(
                  'Sign Out',
                  style: GoogleFonts.openSans(
                    color: Colors.red,
                  ),
                ),
                onTap: _handleLogout,
              ),
            ],
          );
  }
}
