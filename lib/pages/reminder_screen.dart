import 'package:flutter/material.dart';
import 'dart:async';
import 'package:medknows/pages/medicines_screen.dart';
import 'package:medknows/pages/home_screen.dart';  // Add this import
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medknows/pages/medicines.dart';  // Add this import
import 'package:medknows/utils/medicine_safety.dart';  // Add this import
import 'package:medknows/pages/history_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_settings/app_settings.dart'; // Add this import
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:io' show Platform;
import '../utils/active_medicine_manager.dart';

class ReminderScreen extends StatefulWidget {
  final Map<String, dynamic>? reminderData;
  final VoidCallback onDelete;

  ReminderScreen({this.reminderData, required this.onDelete});

  @override
  _ReminderScreenState createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> {
  late Timer _timer;
  Map<String, Duration> _timeRemaining = {};
  // Change from late to nullable and initialize with empty stream
  Stream<QuerySnapshot>? _remindersStream;
  bool _initialized = false;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Add these properties
  bool _notificationsPermissionChecked = false;
  bool _notificationsEnabled = false;

  @override
  void initState() {
    super.initState();
    _checkNotificationPermissions(); // Add this line
    _initializeNotifications();
    _initializeReminders();
    _loadActiveMedicine();
  }

  // Add this new method
  Future<void> _checkNotificationPermissions() async {
    if (_notificationsPermissionChecked) return;
    
    // Fix the method name here
    final status = await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
    
    setState(() {
      _notificationsEnabled = status ?? false;
      _notificationsPermissionChecked = true;
    });

    if (!_notificationsEnabled && mounted) {
      _showNotificationPermissionDialog();
    }
  }

  // Add this new method
  void _showNotificationPermissionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.notifications_active, color:Colors.blue.withOpacity(1)),
              SizedBox(width: 8),
              Text('Enable Notifications'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'MedKnows needs notification permission to:',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text('• Remind you to take medicines on time'),
              Text('• Alert you about medicine schedules'),
              Text('• Ensure you don\'t miss any doses'),
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber, color: Colors.amber[900]),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Without notifications, you might miss your medicine schedule.',
                        style: TextStyle(color: Colors.amber[900]),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Not Now'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: Text('Enable'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.withOpacity(1),
              ),
              onPressed: () async {
                // Fix the method name here too
                final granted = await flutterLocalNotificationsPlugin
                    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                    ?.requestNotificationsPermission();
                
                setState(() => _notificationsEnabled = granted ?? false);
                Navigator.of(context).pop();

                // Show result
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        granted == true 
                          ? 'Notifications enabled successfully'
                          : 'Please enable notifications in system settings'
                      ),
                      backgroundColor: granted == true ? Colors.green : Colors.orange,
                      action: granted == true ? null : SnackBarAction(
                        label: 'Settings',
                        textColor: Colors.white,
                        onPressed: () => AppSettings.openAppSettings(), // Use AppSettings here
                      ),
                    ),
                  );
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _initializeNotifications() async {
    tz.initializeTimeZones();
    
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
        
    final DarwinInitializationSettings initializationSettingsIOS =
        DarwinInitializationSettings(
          requestSoundPermission: true,
          requestBadgePermission: true,
          requestAlertPermission: true,
          notificationCategories: [
            DarwinNotificationCategory(
              'medicine_reminders',
              actions: [
                DarwinNotificationAction.plain('TAKE_NOW', 'Take Now'),
                DarwinNotificationAction.plain('SNOOZE', 'Snooze (15 min)'),
              ],
              options: {
                DarwinNotificationCategoryOption.hiddenPreviewShowTitle,
              },
            ),
          ],
        );

    final InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap
        if (response.payload != null) {
          switch (response.actionId) {
            case 'TAKE_NOW':
              _handleMedicineTaken();
              break;
            case 'SNOOZE':
              _snoozeReminder();
              break;
            default:
              // Just open the app when tapped
              break;
          }
        }
      },
    );

    // Request permissions after initialization
    if (Platform.isAndroid) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();
    } else if (Platform.isIOS) {
      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
          ?.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
    }
  }

  Future<void> _initializeReminders() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      
      // Initialize the stream
      _remindersStream = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reminders')
          .snapshots();

      setState(() {}); // Trigger rebuild with initialized stream

      if (widget.reminderData != null) {
        // Check if reminder already exists
        final existingReminders = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('reminders')
            .where('medicine.name', isEqualTo: widget.reminderData!['medicine']['name'])
            .get();

        if (existingReminders.docs.isEmpty) {
          await _saveReminderToFirestore(widget.reminderData!);
        }
      }

      _startTimer();
    } catch (e) {
      print('Error initializing reminders: $e');
      // Handle initialization error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading reminders'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _loadActiveMedicine() async {
    if (widget.reminderData == null) {
      final activeMedicine = await ActiveMedicineManager.getActiveMedicine();
      if (activeMedicine != null) {
        // Update Firestore with the active medicine if not already present
        final prefs = await SharedPreferences.getInstance();
        final userId = prefs.getString('userId') ?? '';
        
        final existingReminders = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('reminders')
            .where('medicine.name', isEqualTo: activeMedicine['medicine']['name'])
            .get();

        if (existingReminders.docs.isEmpty) {
          await _saveReminderToFirestore(activeMedicine);
        }
      }
    }
  }

  Future<void> _saveReminderToFirestore(Map<String, dynamic> reminderData) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';

    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('reminders')
        .add({
      ...reminderData,
      'createdAt': FieldValue.serverTimestamp(),
      'nextIntake': reminderData['nextIntake']?.toUtc(),
    });
  }

  Future<void> _updateNextIntake(DocumentReference docRef, Map<String, dynamic> reminderData) async {
    // Calculate next intake based on medicine directions
    final directions = reminderData['medicine']['directions of use'];
    final nextIntake = await _calculateNextIntake(directions);
    
    await docRef.update({
      'nextIntake': nextIntake.toUtc(),
    });

    // Schedule notification for next intake
    await _scheduleNotification(reminderData, nextIntake);
  }

  Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId') ?? '';
  }

  Future<DateTime> _calculateNextIntake(String directions) async {
    // Try to find hour interval in directions
    RegExp regExp = RegExp(r'every\s+(\d+)[-\s]*(\d+)?\s*hours?');
    Match? match = regExp.firstMatch(directions);
    
    if (match != null) {
      int minHours = int.parse(match.group(1)!);
      return DateTime.now().add(Duration(hours: minHours));
    }
    
    // Try to find times per day
    regExp = RegExp(r'(\d+)\s*times?\s*(?:per|a)\s*day');
    match = regExp.firstMatch(directions);
    
    if (match != null) {
      int timesPerDay = int.parse(match.group(1)!);
      int hoursInterval = 24 ~/ timesPerDay;
      return DateTime.now().add(Duration(hours: hoursInterval));
    }
    
    // Default to 6 hours if no interval found
    return DateTime.now().add(Duration(hours: 6));
  }

  void _startTimer() {
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      if (!mounted) return;
      
      setState(() {
        _getUserId().then((userId) {
          FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('reminders')
              .get()
              .then((snapshots) {
            for (var doc in snapshots.docs) {
              final data = doc.data();
              if (data['nextIntake'] != null) {
                final nextIntake = (data['nextIntake'] as Timestamp).toDate();
                final remaining = nextIntake.difference(DateTime.now());
                
                _timeRemaining[doc.id] = remaining;
                
                // Check if it's time for notification
                if (remaining.isNegative) {
                  _showNotification(data);
                  // Update next intake time
                  _updateNextIntake(doc.reference, data);
                }
              }
            }
          });
        });
      });
    });
  }

  void _showNotification(Map<String, dynamic> reminderData) {
    // Show system notification first
    _showSystemNotification(reminderData);
    
    // Then show in-app dialog with three buttons
    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.blue.withOpacity(1)),
              SizedBox(width: 8),
              Text('Medicine Reminder'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("It's time to take your medicine:"),
              SizedBox(height: 8),
              Text(
                reminderData['medicine']['name'],
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
              ),
              Text(
                '${reminderData['tablets']} tablet(s) - ${reminderData['dosage']} mg',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.pop(context);
                _handleCloseReminder();
              },
            ),
            TextButton(
              child: Text('Snooze (15 min)'),
              onPressed: () {
                Navigator.pop(context);
                _snoozeReminder();
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
            ),
            ElevatedButton(
              child: Text('Take Now'),
              onPressed: () {
                Navigator.pop(context);
                _handleMedicineTaken();
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromRGBO(66, 96, 208, 1),
              ),
            ),
          ],
        ),
      );
    }
  }

  // Add this new method
  void _handleCloseReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      // Find and delete the reminder
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reminders')
          .where('medicine.name', isEqualTo: widget.reminderData!['medicine']['name'])
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        // Delete the reminder
        await querySnapshot.docs.first.reference.delete();

        // Cancel any scheduled notifications
        await flutterLocalNotificationsPlugin.cancel(
          widget.reminderData!['medicine']['name'].hashCode
        );

        // Add completed record to history
        final historyEntry = {
          'medicine': widget.reminderData!['medicine'],
          'tablets': widget.reminderData!['tablets'],
          'dosage': widget.reminderData!['dosage'],
          'takenAt': Timestamp.fromDate(DateTime.now()),
          'status': 'completed',
          'userId': userId,
          'date': Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)),
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('history')
            .add(historyEntry);

        // Clear from active medicines if present
        await ActiveMedicineManager.clearActiveMedicine();

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reminder ended successfully'),
              duration: Duration(seconds: 2),
              backgroundColor: Colors.green,
            ),
          );

          // Navigate back to home screen
          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (context) => HomeScreen(
                userName: '',
                initialIndex: 2, // History tab
              ),
            ),
            (route) => false,
          );
        }
      }
    } catch (e) {
      print('Error in _handleCloseReminder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error ending reminder'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _showSystemNotification(Map<String, dynamic> reminderData) async {
    try {
      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        'medicine_reminders_immediate', // different channel id for immediate notifications
        'Medicine Reminders',
        channelDescription: 'Immediate notifications for medicine reminders',
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        fullScreenIntent: true,
        styleInformation: BigTextStyleInformation(
          'It\'s time to take your medicine: ${reminderData['medicine']['name']}\n'
          'Dosage: ${reminderData['tablets']} tablet(s) - ${reminderData['dosage']} mg',
        ),
      );

      NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          subtitle: '${reminderData['tablets']} tablet(s) - ${reminderData['dosage']} mg',
        ),
      );

      await flutterLocalNotificationsPlugin.show(
        reminderData['medicine']['name'].hashCode,
        'Medicine Reminder',
        'Time to take ${reminderData['medicine']['name']}',
        platformDetails,
        payload: reminderData['medicine']['name'],
      );
    } catch (e) {
      print('Error showing system notification: $e');
    }
  }

  Future<void> _snoozeReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      final newNextIntake = DateTime.now().add(Duration(minutes: 15));
      
      // Update the reminder in Firestore
      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reminders')
          .where('medicine.name', isEqualTo: widget.reminderData!['medicine']['name'])
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        await querySnapshot.docs.first.reference.update({
          'nextIntake': newNextIntake.toUtc(),
        });

        // Add snooze record to history
        final historyEntry = {
          'medicine': widget.reminderData!['medicine'],
          'tablets': widget.reminderData!['tablets'],
          'dosage': widget.reminderData!['dosage'],
          'takenAt': Timestamp.fromDate(DateTime.now()),
          'status': 'snoozed',
          'nextNotification': Timestamp.fromDate(newNextIntake),
          'userId': userId,
          'date': Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)),
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('history')
            .add(historyEntry);

        // Schedule next notification
        await _scheduleNotification(widget.reminderData!, newNextIntake);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder snoozed for 15 minutes'),
            duration: Duration(seconds: 2),
          ),
        );
      }

    } catch (e) {
      print('Error in _snoozeReminder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error snoozing reminder'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<double> _getTotalDosageIn24Hours(String medicineName) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? 'id';
    
    final now = DateTime.now();
    final yesterday = now.subtract(Duration(hours: 24));
    
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('history')
        .where('medicine.name', isEqualTo: medicineName)
        .where('takenAt', isGreaterThanOrEqualTo: yesterday)
        .where('takenAt', isLessThanOrEqualTo: now)
        .get();

    double totalDosage = 0;
    for (var doc in querySnapshot.docs) {
      totalDosage += (doc.data()['dosage'] as num).toDouble();
    }
    
    return totalDosage;
  }

  Future<bool> _checkDosageSafety(double newDosage, String medicineName) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? 'id';
    
    // Get total active ingredients taken in last 24 hours
    final currentTotals = await MedicineSafety.getTotalActiveIngredientsIn24Hours(userId);
    
    // Check if new dosage would exceed limits for any active ingredient
    final warnings = await MedicineSafety.checkTotalActiveDosage(
      widget.reminderData!['medicine'],
      newDosage,
      currentTotals,
      medicines
    );

    if (warnings.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Safety Warning'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ...warnings.map((warning) => Padding(
                padding: EdgeInsets.only(bottom: 8),
                child: Text(warning),
              )),
            ],
          ),
          actions: [
            TextButton(
              child: Text('OK'),
              onPressed: () => Navigator.pop(context),
            ),
          ],
        ),
      );
      return false;
    }
    return true;
  }

  Future<bool> _checkMedicineSafety(String medicineName) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? 'id';
    
    // Get recently taken medicines
    final recentMedicines = await MedicineSafety.getRecentlyTakenMedicines(userId);
    
    // Check for interactions
    final warnings = MedicineSafety.checkInteractions(
      widget.reminderData!['medicine'],
      recentMedicines,
      medicines
    );
    
    if (warnings.isNotEmpty) {
      final result = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Medicine Interaction Warning'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('The following interactions were detected:'),
              SizedBox(height: 8),
              ...warnings.map((w) => Padding(
                padding: EdgeInsets.only(bottom: 4),
                child: Text('• $w', style: TextStyle(color: Colors.red)),
              )),
              SizedBox(height: 8),
              Text('Do you still want to take this medicine?'),
            ],
          ),
          actions: [
            TextButton(
              child: Text('Cancel'),
              onPressed: () => Navigator.of(context).pop(false),
            ),
            TextButton(
              child: Text('Take Anyway', style: TextStyle(color: Colors.red)),
              onPressed: () => Navigator.of(context).pop(true),
            ),
          ],
        ),
      );
      return result ?? false;
    }
    return true;
  }

  Future<void> _addToHistory({bool isInitialDose = false}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      
      final now = DateTime.now();
      final historyEntry = {
        'medicine': widget.reminderData!['medicine'],
        'tablets': widget.reminderData!['tablets'],
        'dosage': widget.reminderData!['dosage'],
        'takenAt': Timestamp.fromDate(now),  // Change to Timestamp
        'status': 'taken',
        'maxDailyDose': _extractMaxDailyDose(widget.reminderData!['medicine']['directions of use']),
        'userId': userId,
        'date': Timestamp.fromDate(DateTime(now.year, now.month, now.day)),  // Change to Timestamp
        'isOneTime': widget.reminderData!['isOneTime'] ?? false,
      };

      // Get history collection reference
      final historyRef = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('history');

      // Add entry and verify
      final docRef = await historyRef.add(historyEntry);
      print('Adding history entry: ${historyEntry}');
      
      // Verify the document was created
      final docSnapshot = await docRef.get();
      if (!docSnapshot.exists) {
        throw Exception('Failed to create history entry');
      }

      print('Successfully created history entry with ID: ${docRef.id}');
      
      // Return early for one-time medicines
      if (widget.reminderData!['isOneTime'] == true) {
        return;
      }

      // Add next scheduled intake for recurring medicines
      final nextIntake = await _calculateNextIntake(widget.reminderData!['medicine']['directions of use']);
      final scheduledEntry = {
        ...historyEntry,
        'status': 'scheduled',
        'scheduledFor': Timestamp.fromDate(nextIntake),
      };

      final scheduledRef = await historyRef.add(scheduledEntry);
      print('Added scheduled entry with ID: ${scheduledRef.id}');

    } catch (e) {
      print('Error in _addToHistory: $e');
      throw e;
    }
  }

  int _extractMaxDailyDose(String directions) {
    // Try to find explicit maximum daily dose
    RegExp maxDoseRegex = RegExp(r'maximum.+?(\d+)\s*mg|max[.\s]+(\d+)\s*mg|exceed\s+(\d+)\s*mg');
    Match? maxMatch = maxDoseRegex.firstMatch(directions);
    if (maxMatch != null) {
      String? value = maxMatch.group(1) ?? maxMatch.group(2) ?? maxMatch.group(3);
      return int.parse(value!);
    }

    // Try to find tablets per day
    RegExp tabletRegex = RegExp(r'(\d+)[-\s]*(\d+)?\s*tablets?');
    Match? tabletMatch = tabletRegex.firstMatch(directions);
    
    RegExp timesRegex = RegExp(r'(\d+)\s*times?\s*(?:per|a)\s*day');
    Match? timesMatch = timesRegex.firstMatch(directions);
    
    if (tabletMatch != null && timesMatch != null) {
      int maxTablets = int.parse(tabletMatch.group(2) ?? tabletMatch.group(1)!);
      int timesPerDay = int.parse(timesMatch.group(1)!);
      int dosagePerTablet = int.parse(widget.reminderData!['dosage'].toString());
      return maxTablets * timesPerDay * dosagePerTablet;
    }

    // Default based on common dosing
    return int.parse(widget.reminderData!['dosage'].toString()) * 4; // Assume 4 doses per day max
  }

  void _handleMedicineTaken() async {
    try {
      final medicineName = widget.reminderData!['medicine']['name'];
      final newDosage = double.parse(widget.reminderData!['dosage'].toString());
      
      // Safety checks first
      final totalDosage = await _getTotalDosageIn24Hours(medicineName);
      final maxDailyDose = _extractMaxDailyDose(widget.reminderData!['medicine']['directions of use']);
      
      if (totalDosage + newDosage > maxDailyDose) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Warning: Maximum daily dose would be exceeded'),
            backgroundColor: Colors.orange,
          ),
        );
        return;
      }

      // Add current intake to history
      print('Adding current intake to history...');
      await _addToHistory(isInitialDose: false);

      // Calculate and schedule next intake
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      
      if (!widget.reminderData!['isOneTime']) {
        // Cancel existing notification
        await flutterLocalNotificationsPlugin.cancel(
          widget.reminderData!['medicine']['name'].hashCode
        );
        
        final directions = widget.reminderData!['medicine']['directions of use'];
        final nextIntake = await _calculateNextIntake(directions);
        
        // Schedule next notification
        await _scheduleNotification(widget.reminderData!, nextIntake);
        
        // Update the reminder with next intake time
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('reminders')
            .where('medicine.name', isEqualTo: medicineName)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          await querySnapshot.docs.first.reference.update({
            'nextIntake': nextIntake.toUtc(),
          });

          // Add next scheduled intake to history
          final scheduledEntry = {
            'medicine': widget.reminderData!['medicine'],
            'tablets': widget.reminderData!['tablets'],
            'dosage': widget.reminderData!['dosage'],
            'status': 'scheduled',
            'scheduledFor': Timestamp.fromDate(nextIntake),
            'userId': userId,
            'date': Timestamp.fromDate(DateTime(nextIntake.year, nextIntake.month, nextIntake.day)),
          };

          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .collection('history')
              .add(scheduledEntry);
        }
      } else {
        // Delete one-time reminder after taking
        final querySnapshot = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('reminders')
            .where('medicine.name', isEqualTo: medicineName)
            .get();

        if (querySnapshot.docs.isNotEmpty) {
          await querySnapshot.docs.first.reference.delete();
        }
      }

      if (!mounted) return;

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Medicine taken successfully'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 2),
        ),
      );

      // Verify history entry was created
      final historyVerification = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('history')
          .where('medicine.name', isEqualTo: medicineName)
          .where('takenAt', isGreaterThan: Timestamp.fromDate(DateTime.now().subtract(Duration(minutes: 5))))
          .get();

      print('Found ${historyVerification.docs.length} recent history entries');

      // Navigate to history screen
      await Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (context) => HomeScreen(
            userName: '',
            initialIndex: 2, // History tab
          ),
        ),
        (route) => false,
      );

    } catch (e) {
      print('Error in _handleMedicineTaken: $e');
      if (!mounted) return;
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error taking medicine: ${e.toString()}'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 4),
        ),
      );
    }
  }

  Future<void> _scheduleNotification(Map<String, dynamic> reminderData, DateTime nextIntake) async {
    final id = reminderData['medicine']['name'].hashCode;
    
    AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'medicine_reminders',
      'Medicine Reminders',
      channelDescription: 'Notifications for medicine reminders',
      importance: Importance.max,
      priority: Priority.high,
      ongoing: true,
      autoCancel: false,
      showWhen: true,
    );

    DarwinNotificationDetails iOSPlatformChannelSpecifics =
        DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        );

    NotificationDetails platformChannelSpecifics = NotificationDetails(
      android: androidPlatformChannelSpecifics,
      iOS: iOSPlatformChannelSpecifics,
    );

    await flutterLocalNotificationsPlugin.zonedSchedule(
      id,
      'Medicine Reminder',
      'Time to take ${reminderData['medicine']['name']}',
      tz.TZDateTime.from(nextIntake, tz.local),
      platformChannelSpecifics,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: DateTimeComponents.time,
      payload: reminderData['medicine']['name'],
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // Add this line
    );
  }

  void _handleAddMedicine() async {
    try {
      final activeMedicine = await ActiveMedicineManager.getActiveMedicine();
      if (activeMedicine != null && mounted) {
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

        if (shouldContinue == true) {
          if (!mounted) return;
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => MedicinesScreen(
                showBackButton: true,
                reminderData: activeMedicine,
              ),
            ),
          );
        }
        return;
      }

      if (!mounted) return;
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => MedicinesScreen(
            showBackButton: true,
            reminderData: null,
          ),
        ),
      );
    } catch (e) {
      print('Error handling add medicine: $e');
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    flutterLocalNotificationsPlugin.cancelAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        title: Text(
          'Reminders',
          style: TextStyle(
            color: Colors.blue.withOpacity(1),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.add,
              color:Colors.blue.withOpacity(1),
            ),
            onPressed: _handleAddMedicine,
          ),
        ],
      ),
      body: Column(
        children: [
          // Add notification warning if disabled
          if (!_notificationsEnabled)
            Container(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Colors.amber.shade50,
              child: Row(
                children: [
                  Icon(Icons.warning_amber, color: Colors.amber[900]),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Notifications are disabled. You may miss medicine reminders.',
                      style: TextStyle(color: Colors.amber[900]),
                    ),
                  ),
                  TextButton(
                    onPressed: _showNotificationPermissionDialog,
                    child: Text('Enable'),
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.amber[900],
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _remindersStream == null
              ? Center(child: CircularProgressIndicator())
              : StreamBuilder<QuerySnapshot>(
                  stream: _remindersStream,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(child: Text('Something went wrong'));
                    }

                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(child: Text('No reminders'));
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final reminderDoc = snapshot.data!.docs[index];
                        final reminderData = {
                          ...reminderDoc.data() as Map<String, dynamic>,
                          'nextIntake': (reminderDoc.data() as Map<String, dynamic>)['nextIntake']?.toDate(),
                        };

                        return _buildReminderCard(
                          reminderData,
                          reminderDoc.reference,
                          _timeRemaining[reminderDoc.id] ?? Duration.zero
                        );
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildReminderCard(
    Map<String, dynamic> reminderData,
    DocumentReference reference,
    Duration timeRemaining
  ) {
    return Dismissible(
      key: Key(reference.id), // Changed to use document ID instead of medicine name
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        // Remove the item from Firestore
        reference.delete();
        
        // Show a snackbar
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
                // Restore the reminder
                await reference.set(reminderData);
              },
            ),
          ),
        );
      },
      confirmDismiss: (direction) async {
        return await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Text('Confirm Delete'),
              content: Text('Are you sure you want to delete this reminder?'),
              actions: [
                TextButton(
                  child: Text('Cancel'),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
                TextButton(
                  child: Text('Delete', style: TextStyle(color: Colors.red)),
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ],
            );
          },
        );
      },
      background: Container(
        alignment: Alignment.centerRight,
        padding: EdgeInsets.symmetric(horizontal: 20),
        color: Colors.red,
        child: Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: Card(
        margin: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        child: Container(
          padding: EdgeInsets.all(12),
          child: Row(
            children: [
              Image.asset(
                reminderData['medicine']['image'],
                width: 50,
                height: 50,
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      reminderData['medicine']['name'],
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      reminderData['medicine']['genericName'],
                      style: TextStyle(
                        fontSize: 14,
                        fontStyle: FontStyle.italic,
                        color: Colors.grey[600],
                      ),
                    ),
                    Text(
                      '${reminderData['tablets']} tablet/s',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey[800],
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                child: reminderData['isOneTime'] == true
                  ? ElevatedButton(
                      onPressed: () => _handleMedicineTaken(),
                      child: Text('Take'),
                    )
                  : Text(
                      '${timeRemaining.inHours}:${timeRemaining.inMinutes.remainder(60).toString().padLeft(2, '0')}:${timeRemaining.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.grey[800],
                      ),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
