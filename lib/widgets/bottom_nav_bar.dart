import 'package:flutter/material.dart';
import 'package:medknows/utils/active_medicine_manager.dart';
import '../pages/camera_screen.dart';  // Add this import

class BottomNavBar extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final bool isProfileOpen;  // Add this property
  final Map<String, dynamic>? reminderData;  // Add this

  const BottomNavBar({
    super.key,
    required this.currentIndex,
    required this.onTap,
    this.isProfileOpen = false,  // Add this parameter
    this.reminderData,  // Add this
  });

  void _handleTap(BuildContext context, int index) async {
    if (index == 2) {
      if (cameraScreenKey.currentState?.mounted ?? false) {
        onTap(index);
      }
      return;
    }
    
    if (index == 1) { // Prescriptions tab
      // Check for active medicine before navigating
      final activeMedicine = await ActiveMedicineManager.getActiveMedicine();
      if (activeMedicine != null) {
        if (!context.mounted) return;
        
        final shouldContinue = await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber),
                  SizedBox(width: 8),
                  Text('Active Medicine Warning'),
                ],
              ),
              backgroundColor: Colors.amber[50],
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'You currently have an active medicine:',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Image.asset(
                          activeMedicine['medicine']['image'],
                          width: 40,
                          height: 40,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                activeMedicine['medicine']['name'],
                                style: TextStyle(fontWeight: FontWeight.bold),
                              ),
                              Text(
                                activeMedicine['medicine']['genericName'],
                                style: TextStyle(fontStyle: FontStyle.italic),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 12),
                  Text(
                    'Adding another medicine might cause drug interactions.',
                    style: TextStyle(color: Colors.orange[900]),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text(
                    'Continue Anyway',
                    style: TextStyle(color: Colors.orange[900]),
                  ),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        );

        if (shouldContinue != true) return;
      }
    }
    
    onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.bottomCenter,
      children: [
        BottomNavigationBar(
          currentIndex: currentIndex,
          onTap: (index) => _handleTap(context, index),  // Updated this line
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.blue.withOpacity(0.6),
          showSelectedLabels: true,
          showUnselectedLabels: false,
          type: BottomNavigationBarType.fixed,
          selectedFontSize: 12,
          unselectedFontSize: 12,
          items: [
            const BottomNavigationBarItem(
              icon: Icon(Icons.home),
              label: 'Home',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.medical_services),
              label: 'Prescriptions',
            ),
            BottomNavigationBarItem(
              icon: Container(height: 0),
              label: '',
            ),
            const BottomNavigationBarItem(
              icon: Icon(Icons.timer),
              label: 'Reminders',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.person, 
                color: isProfileOpen ? Colors.blue : Colors.blue.withOpacity(0.6),
              ),
              label: 'Profile',
              backgroundColor: isProfileOpen ? Colors.blue : null,
            ),
          ],
        ),
        Positioned(
          top: -25,
          child: Container(
            height: 60,
            width: 60,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: Colors.blue.withOpacity(0.2),
                  spreadRadius: 2,
                  blurRadius: 12,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: currentIndex == 2 
              ? Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.blue.withOpacity(0.5),
                        Colors.blue.withOpacity(0.3),
                      ],
                    ),
                    border: Border.all(
                      color: Colors.blue.withOpacity(0.4),
                      width: 3,
                    ),
                  ),
                  child: FloatingActionButton(
                    elevation: 0,
                    shape: const CircleBorder(),
                    onPressed: () {
                      // Use public method instead of accessing private member
                      if (cameraScreenKey.currentState != null && 
                          cameraScreenKey.currentState!.isCameraReady) {
                        cameraScreenKey.currentState!.takePicture();
                      }
                    },
                    backgroundColor: Colors.white,
                    child: Container(
                      width: 45,
                      height: 45,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: Colors.blue.withOpacity(0.4),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                )
              : FloatingActionButton(
                  elevation: 0,
                  shape: const CircleBorder(),
                  onPressed: () => onTap(2),
                  backgroundColor: Colors.blue,
                  child: const Icon(
                    Icons.camera_alt,
                    color: Colors.white,
                    size: 30,
                  ),
                ),
          ),
        ),
      ],
    );
  }
}

class HomeScreen extends StatefulWidget {
  @override
  _HomeScreenState createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  bool _isProfileOpen = false;
  Map<String, dynamic>? _reminderData;  // Add this

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Home Screen'),
      ),
      body: Center(
        child: Text('Content goes here'),
      ),
      bottomNavigationBar: BottomNavBar(
        currentIndex: _isProfileOpen ? 4 : _currentIndex,
        onTap: (index) {
          if (index == 4) {
            setState(() => _isProfileOpen = true);
          } else {
            setState(() {
              _isProfileOpen = false;
              _currentIndex = index;
            });
          }
        },
        isProfileOpen: _isProfileOpen,  // Pass the new parameter
        reminderData: _reminderData,  // Pass the new parameter
      ),
    );
  }
}