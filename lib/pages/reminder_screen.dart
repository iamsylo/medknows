import 'package:flutter/material.dart';
import 'dart:async';
import 'package:medknows/pages/medicines_screen.dart';
import 'package:medknows/pages/home_screen.dart';  // Add this import
import 'package:cloud_firestore/cloud_firestore.dart'; // Add this import
import 'package:medknows/widgets/maintenance_reminder_form.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medknows/pages/medicines.dart';  // Add this import
import 'package:medknows/utils/medicine_safety.dart';  // Add this import
import 'package:medknows/pages/history_screen.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:app_settings/app_settings.dart'; // Add this import
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tz;
import 'dart:io' show Platform;
import 'dart:typed_data';  // Add this import
import '../utils/active_medicine_manager.dart';

class ReminderScreen extends StatefulWidget {
  final Map<String, dynamic>? reminderData;
  final VoidCallback onDelete;

  ReminderScreen({this.reminderData, required this.onDelete});

  @override
  _ReminderScreenState createState() => _ReminderScreenState();
}

class _ReminderScreenState extends State<ReminderScreen> with WidgetsBindingObserver {
  late Timer _timer;
  Map<String, Duration> _timeRemaining = {};
  Stream<QuerySnapshot>? _remindersStream;
  bool _initialized = false;
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
  final Map<String, DateTime> _lastNotificationTime = {};  // Add this line
  Map<String, bool> _dismissedDialogs = {};  // Add this line
  Map<String, bool> _activeReminders = {}; // Add this line to track active reminders
  Map<int, Timer> _notificationTimers = {}; // Add this line near other class variables

  bool _notificationsPermissionChecked = false;
  bool _notificationsEnabled = false;
  bool _openedFromNotification = false;  // Add this line

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);  // Add this line
    _checkNotificationPermissions();
    _initializeNotifications();
    _initializeReminders();
    _loadActiveMedicine();
  }

  Future<void> _checkNotificationPermissions() async {
    if (_notificationsPermissionChecked) return;
    
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
                final granted = await flutterLocalNotificationsPlugin
                    .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
                    ?.requestNotificationsPermission();
                
                setState(() => _notificationsEnabled = granted ?? false);
                Navigator.of(context).pop();

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
                        onPressed: () => AppSettings.openAppSettings(),
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
        AndroidInitializationSettings('@mipmap/oticure');
        
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
                DarwinNotificationAction.plain('SNOOZE', 'Snooze'),
                DarwinNotificationAction.plain('CLOSE', 'Close'),
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
        _openedFromNotification = true;  // Set flag when opened from notification
        if (response.payload != null) {
          final reminderData = await _getReminderByName(response.payload!);
          if (reminderData != null) {
            final isMaintenance = reminderData['data']['isMaintenance'] ?? false;
            
            switch (response.actionId) {
              case 'TAKE_NOW':
                _handleMedicineTaken(reminderData['data'], reminderData['reference']);
                break;
              case 'SNOOZE':
                _snoozeReminder(reminderData['data'], reminderData['reference']);
                break;
              case 'CLOSE':
                if (!isMaintenance) {
                  reminderData['reference'].delete();
                  _addSkippedHistory(reminderData['data']);
                }
                break;
              default:
                if (_openedFromNotification) {
                  _showActionDialog(reminderData['data'], reminderData['reference']);
                }
                break;
            }
          }
        }
      },
    );
  }

  Future<Map<String, dynamic>?> _getReminderByName(String medicineName) async {
    final prefs = await SharedPreferences.getInstance();
    final userId = prefs.getString('userId') ?? '';
    
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('reminders')
        .where('medicine.name', isEqualTo: medicineName)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      return {
        'data': querySnapshot.docs.first.data(),
        'reference': querySnapshot.docs.first.reference,
      };
    }
    return null;
  }

  Future<void> _initializeReminders() async {
    if (_initialized) return;
    _initialized = true;

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';
      
      _remindersStream = FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reminders')
          .snapshots();

      setState(() {});

      if (widget.reminderData != null) {
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
    final directions = reminderData['medicine']['directions of use'];
    final nextIntake = await _calculateNextIntake(directions);
    
    await docRef.update({
      'nextIntake': nextIntake.toUtc(),
    });

    await _scheduleNotification(reminderData, nextIntake);
  }

  Future<String> _getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('userId') ?? '';
  }

  Future<DateTime> _calculateNextIntake(String directions) async {
    RegExp regExp = RegExp(r'every\s+(\d+)[-\s]*(\d+)?\s*hours?');
    Match? match = regExp.firstMatch(directions);
    
    if (match != null) {
      int minHours = int.parse(match.group(1)!);
      return DateTime.now().add(Duration(hours: minHours));
    }
    
    regExp = RegExp(r'(\d+)\s*times?\s*(?:per|a)\s*day');
    match = regExp.firstMatch(directions);
    
    if (match != null) {
      int timesPerDay = int.parse(match.group(1)!);
      int hoursInterval = 24 ~/ timesPerDay;
      return DateTime.now().add(Duration(hours: hoursInterval));
    }
    
    return DateTime.now().add(Duration(hours: 6));
  }

  DateTime _calculateNextScheduledDay(Map<String, dynamic> reminderData) {
    final now = DateTime.now();
    final repeatOption = reminderData['repeatOption'] as String;
    final List<String> scheduledDays = List<String>.from(reminderData['scheduledDays']);
    final hour = reminderData['hour'] as int;
    final minute = reminderData['minute'] as int;

    var scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      hour,
      minute,
    );

    if (repeatOption == 'daily') {
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(Duration(days: 1));
      }
      return scheduledTime;
    }

    String getCurrentWeekday(DateTime date) {
      switch (date.weekday) {
        case 1: return 'Monday';
        case 2: return 'Tuesday';
        case 3: return 'Wednesday';
        case 4: return 'Thursday';
        case 5: return 'Friday';
        case 6: return 'Saturday';
        case 7: return 'Sunday';
        default: return '';
      }
    }

    int daysToAdd = 0;
    bool foundNext = false;

    for (int i = 0; i < 7; i++) {
      final checkDate = now.add(Duration(days: i));
      final weekday = getCurrentWeekday(checkDate);

      if (scheduledDays.contains(weekday)) {
        if (i == 0) {
          if (scheduledTime.isBefore(now)) {
            continue;
          }
        }
        daysToAdd = i;
        foundNext = true;
        break;
      }
    }

    if (!foundNext) {
      for (int i = 0; i < 7; i++) {
        final weekday = getCurrentWeekday(now.add(Duration(days: i)));
        if (scheduledDays.contains(weekday)) {
          daysToAdd = i + 7;
          break;
        }
      }
    }

    return DateTime(
      now.year,
      now.month,
      now.day + daysToAdd,
      hour,
      minute,
    );
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
                
                // Only update time remaining if reminder is not active
                if (!(_activeReminders[doc.id] == true)) {
                  _timeRemaining[doc.id] = remaining;
                }
                
                if (remaining.isNegative) {
                  final lastShown = _lastNotificationTime[doc.id];
                  final now = DateTime.now();
                  if ((lastShown == null || now.difference(lastShown) > Duration(minutes: 1)) 
                      && !(_activeReminders[doc.id] == true)) {
                    _lastNotificationTime[doc.id] = now;
                    _activeReminders[doc.id] = true; // Mark reminder as active
                    _showSystemNotification(data);
                    if (mounted && !_openedFromNotification) {
                      _showActionDialog(data, doc.reference);
                    }
                  }
                  
                  if (data['isMaintenance'] == true && !(_activeReminders[doc.id] == true)) {
                    final nextScheduledTime = _calculateNextScheduledDay(data);
                    doc.reference.update({
                      'nextIntake': nextScheduledTime.toUtc(),
                      'lastNotificationTime': Timestamp.now(),
                    });
                    _scheduleNotification(data, nextScheduledTime);
                  }
                }
              }
            }
          });
        });
      });
    });
  }

  void _showActionDialog(Map<String, dynamic> reminderData, DocumentReference reference) {
    final docId = reference.id;
    if (_dismissedDialogs[docId] == true) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => WillPopScope( // Add WillPopScope to prevent back button
        onWillPop: () async => false,
        child: AlertDialog(
          title: Row(
            children: [
              Icon(Icons.notifications_active, color: Colors.blue),
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
                reminderData['isMaintenance'] == true
                    ? '${reminderData['tabletCount']} tablet(s)'
                    : '${reminderData['tablets']} tablet(s) - ${reminderData['dosage']} mg',
                style: TextStyle(color: Colors.grey[600]),
              ),
            ],
          ),
          actions: [
            if (reminderData['isMaintenance'] != true)
              TextButton(
                child: Text('Close'),
                onPressed: () {
                  Navigator.pop(context);
                  _dismissedDialogs[docId] = true;
                  _activeReminders[docId] = false; // Reset active state
                  reference.delete();
                  _addSkippedHistory({...reminderData, 'id': docId});
                },
                style: TextButton.styleFrom(
                  foregroundColor: Colors.red,
                ),
              ),
            TextButton(
              child: Text('Snooze (15 min)'),
              onPressed: () {
                Navigator.pop(context);
                _dismissedDialogs[docId] = true;
                _activeReminders[docId] = false; // Reset active state
                _snoozeReminder(reminderData, reference);
              },
              style: TextButton.styleFrom(
                foregroundColor: Colors.orange,
              ),
            ),
            ElevatedButton(
              child: Text('Take Now'),
              onPressed: () {
                Navigator.pop(context);
                _dismissedDialogs[docId] = true;
                _activeReminders[docId] = false; // Reset active state
                _handleMedicineTaken(reminderData, reference);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: Color.fromRGBO(66, 96, 208, 1),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addSkippedHistory(Map<String, dynamic> reminderData) async {
    try {
      final docId = reminderData['id'] ?? '';  // Get document ID
      _dismissedDialogs[docId] = true;  // Mark dialog as dismissed
      final notificationId = reminderData['medicine']['name'].hashCode;
      await flutterLocalNotificationsPlugin.cancel(notificationId);

      final historyEntry = {
        'medicine': reminderData['medicine'],
        'tablets': reminderData['tablets'],
        'dosage': reminderData['dosage'],
        'takenAt': Timestamp.fromDate(DateTime.now()),
        'status': 'skipped',
        'userId': await _getUserId(),
        'date': Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(await _getUserId())
          .collection('history')
          .add(historyEntry);
          
      if (mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Reminder removed'), backgroundColor: Colors.orange),
        );
      }
    } catch (e) {
      print('Error adding skipped history: $e');
    }
  }

  Future<void> _showSystemNotification(Map<String, dynamic> reminderData) async {
    try {
      final id = reminderData['medicine']['name'].hashCode;
      final vibrationPattern = Int64List.fromList([0, 1000, 500, 1000, 500, 1000]);
      
      final androidChannel = AndroidNotificationChannel(
        'medicine_reminders_high_importance',
        'Medicine Reminders',
        description: 'Important notifications for medicine reminders',
        importance: Importance.max,
        enableVibration: true,
        playSound: true,
        showBadge: true,
        vibrationPattern: vibrationPattern,
      );

      await flutterLocalNotificationsPlugin
          .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(androidChannel);

      AndroidNotificationDetails androidDetails = AndroidNotificationDetails(
        androidChannel.id,
        androidChannel.name,
        channelDescription: androidChannel.description,
        importance: Importance.max,
        priority: Priority.high,
        showWhen: true,
        enableVibration: true,
        playSound: true,
        ongoing: true, // Make notification persistent
        autoCancel: false, // Prevent auto-cancellation
        vibrationPattern: vibrationPattern,
        icon: '@mipmap/oticure',
        fullScreenIntent: true,
        category: AndroidNotificationCategory.alarm,
        visibility: NotificationVisibility.public,
      );

      NotificationDetails platformDetails = NotificationDetails(
        android: androidDetails,
        iOS: DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
          sound: 'notification_sound.wav',
          interruptionLevel: InterruptionLevel.timeSensitive,
        ),
      );

      await flutterLocalNotificationsPlugin.show(
        id,
        'Medicine Reminder',
        'Time to take ${reminderData['medicine']['name']}',
        platformDetails,
        payload: reminderData['medicine']['name'],
      );

      // Cancel any existing timer for this notification
      _notificationTimers[id]?.cancel();
      
      // Create new periodic timer
      _notificationTimers[id] = Timer.periodic(Duration(seconds: 2), (timer) {
        if (!(_activeReminders[reminderData['medicine']['name'].hashCode] == true)) {
          flutterLocalNotificationsPlugin.show(
            id,
            'Medicine Reminder',
            'Time to take ${reminderData['medicine']['name']}',
            platformDetails,
            payload: reminderData['medicine']['name'],
          );
        } else {
          timer.cancel();
          _notificationTimers.remove(id);
        }
      });

    } catch (e) {
      print('Error showing system notification: $e');
    }
  }

  Future<void> _handleMedicineTaken(Map<String, dynamic> reminderData, DocumentReference reference) async {
    try {
      final docId = reference.id;
      final notificationId = reminderData['medicine']['name'].hashCode;
      
      // Cancel notification timer
      _notificationTimers[notificationId]?.cancel();
      _notificationTimers.remove(notificationId);
      
      // Cancel the notification
      await flutterLocalNotificationsPlugin.cancel(notificationId);
      
      _dismissedDialogs[docId] = true;  // Mark dialog as dismissed
      _activeReminders[docId] = false; // Reset active state

      final isMaintenance = reminderData['isMaintenance'] ?? false;
      
      if (isMaintenance) {
        final quantity = reminderData['quantity'] ?? 0;
        final tabletCount = reminderData['tabletCount'] ?? 1;
        
        if (quantity - tabletCount < 0) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Not enough tablets remaining'), backgroundColor: Colors.red),
            );
          }
          return;
        }

        await reference.update({
          'quantity': quantity - tabletCount,
          'nextIntake': _calculateNextScheduledDay(reminderData).toUtc(),
        });

      } else {
        await reference.delete();
      }

      final historyEntry = {
        'medicine': reminderData['medicine'],
        'tablets': isMaintenance ? reminderData['tabletCount'] : reminderData['tablets'],
        'dosage': reminderData['dosage'],
        'takenAt': Timestamp.fromDate(DateTime.now()),
        'status': 'taken',
        'userId': await _getUserId(),
        'date': Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(await _getUserId())
          .collection('history')
          .add(historyEntry);

      if (mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Medicine taken successfully'), backgroundColor: Colors.green),
        );
      }

    } catch (e) {
      print('Error handling medicine taken: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error handling reminder'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _snoozeReminder(Map<String, dynamic> reminderData, DocumentReference reference) async {
    try {
      final docId = reference.id;
      final notificationId = reminderData['medicine']['name'].hashCode;
      
      // Cancel notification timer
      _notificationTimers[notificationId]?.cancel();
      _notificationTimers.remove(notificationId);
      
      // Cancel the notification
      await flutterLocalNotificationsPlugin.cancel(notificationId);

      _dismissedDialogs[docId] = true;
      _activeReminders[docId] = false;

      final newNextIntake = DateTime.now().add(Duration(minutes: 15));
      final isMaintenance = reminderData['isMaintenance'] ?? false;
      
      if (isMaintenance) {
        // For maintenance medicine, just update the nextIntake
        await reference.update({
          'nextIntake': newNextIntake.toUtc(),
          'snoozedFrom': reminderData['nextIntake'],
          'lastSnoozedAt': Timestamp.now(),
        });

        // Schedule the next notification
        await _scheduleNotification(
          reminderData,
          newNextIntake,
        );
      } else {
        // For regular medicine
        await reference.update({
          'nextIntake': newNextIntake.toUtc(),
        });

        // Only add to history for non-maintenance medicines
        final historyEntry = {
          'medicine': reminderData['medicine'],
          'tablets': reminderData['tablets'],
          'dosage': reminderData['dosage'],
          'takenAt': Timestamp.fromDate(DateTime.now()),
          'status': 'snoozed',
          'nextNotification': Timestamp.fromDate(newNextIntake),
          'userId': await _getUserId(),
          'date': Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)),
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(await _getUserId())
            .collection('history')
            .add(historyEntry);

        await _scheduleNotification(reminderData, newNextIntake);
      }

      if (mounted) {
        Navigator.of(context, rootNavigator: true).popUntil((route) => route.isFirst);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder snoozed for 15 minutes'),
            backgroundColor: Colors.orange, // Changed from blue to orange for consistency
          ),
        );
      }

    } catch (e) {
      print('Error in _snoozeReminder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error snoozing reminder: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _scheduleNotification(Map<String, dynamic> reminderData, DateTime nextIntake) async {
    try {
      final id = reminderData['medicine']['name'].hashCode;
      
      if (reminderData['isMaintenance'] == true) {
        final hour = reminderData['hour'] as int?;
        final minute = reminderData['minute'] as int?;
        
        if (hour != null && minute != null) {
          var scheduledTime = DateTime(
            nextIntake.year,
            nextIntake.month,
            nextIntake.day,
            hour,
            minute,
          );
          
          if (scheduledTime.isBefore(DateTime.now())) {
            scheduledTime = scheduledTime.add(Duration(days: 1));
          }

          nextIntake = scheduledTime;
        }
      }

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
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      print('Error scheduling notification: $e');
    }
  }

  void _handleAddMedicine() async {
    try {
      final activeMedicine = await ActiveMedicineManager.getActiveMedicine();
      
      final result = await showDialog<String>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Text(
              'Add Reminder',
              style: TextStyle(
                color: Colors.blue[700],
                fontWeight: FontWeight.bold,
              ),
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  tileColor: Colors.blue[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: Icon(Icons.healing, color: Colors.blue[700]),
                  title: Text(
                    'Health Assessment',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                  subtitle: Text(
                    'Get medicine recommendations based on symptoms',
                    style: TextStyle(color: Colors.blue[500]),
                  ),
                  onTap: () => Navigator.pop(context, 'health'),
                ),
                SizedBox(height: 8),
                ListTile(
                  tileColor: Colors.blue[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  leading: Icon(Icons.calendar_today, color: Colors.blue[700]),
                  title: Text(
                    'Maintenance Medicine',
                    style: TextStyle(color: Colors.blue[700]),
                  ),
                  subtitle: Text(
                    'Set reminder for regular medication',
                    style: TextStyle(color: Colors.blue[500]),
                  ),
                  onTap: () => Navigator.pop(context, 'maintenance'),
                ),
              ],
            ),
          );
        },
      );

      if (result == null) return;

      if (result == 'maintenance') {
        _showMaintenanceForm();
        return;
      }

      if (activeMedicine != null && mounted) {
      } else {
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
      }
    } catch (e) {
      print('Error handling add medicine: $e');
    }
  }

  void _showMaintenanceForm() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: MaintenanceReminderForm(
          onComplete: _handleMaintenanceSubmit,
        ),
      ),
    );
  }

  void _handleMaintenanceSubmit(Map<String, dynamic> data) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      String timeStr = data['time'] as String;
      List<String> parts = timeStr.split(' ');
      List<String> timeParts = parts[0].split(':');
      int hour = int.parse(timeParts[0]);
      int minute = int.parse(timeParts[1]);
      
      if (parts[1] == 'PM' && hour < 12) {
        hour += 12;
      } else if (parts[1] == 'AM' && hour == 12) {
        hour = 0;
      }

      var scheduledTime = DateTime(
        DateTime.now().year,
        DateTime.now().month,
        DateTime.now().day,
        hour,
        minute,
      );
      
      if (scheduledTime.isBefore(DateTime.now())) {
        scheduledTime = scheduledTime.add(Duration(days: 1));
      }

      final updatedData = {
        ...data,
        'hour': hour,
        'minute': minute,
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reminders')
          .add({
        ...updatedData,
        'createdAt': FieldValue.serverTimestamp(),
        'nextIntake': scheduledTime.toUtc(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder set for ${scheduledTime.hour}:${scheduledTime.minute.toString().padLeft(2, '0')}${scheduledTime.day != DateTime.now().day ? ' tomorrow' : ' today'}'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error setting maintenance reminder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error setting reminder'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Widget _buildReminderCard(
    Map<String, dynamic> reminderData,
    DocumentReference reference,
    Duration timeRemaining
  ) {
    final bool isMaintenance = reminderData['isMaintenance'] ?? false;
    final int quantity = reminderData['quantity'] ?? 0;
    final int tabletCount = reminderData['tabletCount'] ?? 1;
    final int lowStockThreshold = reminderData['lowStockThreshold'] ?? 10;

    if (isMaintenance && quantity <= 0) {
      reference.delete();
      return SizedBox.shrink();
    }

    return Dismissible(
      key: Key(reference.id),
      direction: DismissDirection.endToStart,
      onDismissed: (direction) {
        reference.delete();
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Reminder deleted'),
            action: SnackBarAction(
              label: 'Undo',
              onPressed: () async {
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
          child: Column(
            children: [
              Row(
                children: [
                  if (reminderData['medicine']['isMaintenanceIcon'] == true)
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: Colors.blue.shade50,
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: Icon(
                        Icons.medication_rounded,
                        color: Colors.blue,
                        size: 30,
                      ),
                    )
                  else
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
                          (reminderData['medicine']['classification'] as List<dynamic>).join(', '),
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.blue[600],
                          ),
                        ),
                        if (isMaintenance) ...[
                          Text(
                            'Stock: $quantity tablets',
                            style: TextStyle(
                              fontSize: 14,
                              color: quantity <= lowStockThreshold 
                                ? Colors.red 
                                : Colors.grey[800],
                            ),
                          ),
                          if (quantity <= lowStockThreshold)
                            Text(
                              'Low stock! Please refill soon.',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                        ] else
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
                    child: Column(
                      children: [
                        Text(
                          '${timeRemaining.inHours}:${timeRemaining.inMinutes.remainder(60).toString().padLeft(2, '0')}:${timeRemaining.inSeconds.remainder(60).toString().padLeft(2, '0')}',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey[800],
                          ),
                        ),
                        if (timeRemaining.isNegative)
                          ElevatedButton(
                            onPressed: () => _handleMedicineTaken(reminderData, reference),
                            child: Text('Take'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.blue.withOpacity(1),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
              if (isMaintenance)
                Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Column(
                    children: [
                      Text(
                        'Daily at ${reminderData['time']}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.blue,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (reminderData['repeatOption'] == 'custom')
                        Text(
                          'On: ${(reminderData['scheduledDays'] as List).join(', ')}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      if (quantity <= lowStockThreshold)
                        Padding(
                          padding: EdgeInsets.only(top: 4),
                          child: Text(
                            '$quantity tablets remaining',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.red,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _handleCloseReminder() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId') ?? '';

      final querySnapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('reminders')
          .where('medicine.name', isEqualTo: widget.reminderData!['medicine']['name'])
          .get();

      if (querySnapshot.docs.isNotEmpty) {
        final reminderData = querySnapshot.docs.first.data();
        
        final historyEntry = {
          'medicine': reminderData['medicine'],
          'tablets': reminderData['tablets'],
          'dosage': reminderData['dosage'],
          'takenAt': Timestamp.fromDate(DateTime.now()),
          'status': 'skipped',
          'userId': userId,
          'date': Timestamp.fromDate(DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day)),
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('history')
            .add(historyEntry);

        final nextIntake = await _calculateNextIntake(reminderData['medicine']['directions of use']);
        await querySnapshot.docs.first.reference.update({
          'nextIntake': nextIntake.toUtc(),
        });

        await _scheduleNotification(reminderData, nextIntake);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Reminder skipped. Next reminder scheduled.'),
              backgroundColor: Colors.orange,
            ),
          );
        }
      }
    } catch (e) {
      print('Error in _handleCloseReminder: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error handling reminder'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    _dismissedDialogs.clear();  // Clean up
    _activeReminders.clear(); // Add this line
    WidgetsBinding.instance.removeObserver(this);  // Add this line
    _timer.cancel();
    flutterLocalNotificationsPlugin.cancelAll();
    // Cancel all notification timers
    _notificationTimers.values.forEach((timer) => timer.cancel());
    _notificationTimers.clear();
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
}
