import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:medknows/pages/reminder_screen.dart'; // Import the ReminderScreen
import 'package:medknows/pages/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Import the HomeScreen

class TakeMedicineForm extends StatefulWidget {
  final Map<String, dynamic> selectedMedicine;
  final Function(double) onDosageChecked;
  final bool needsSpecificTiming;  // Add this

  TakeMedicineForm({
    required this.selectedMedicine,
    required this.onDosageChecked,
    this.needsSpecificTiming = true,  // Add this
  });

  @override
  _TakeMedicineFormState createState() => _TakeMedicineFormState();
}

class _TakeMedicineFormState extends State<TakeMedicineForm> {
  final TextEditingController _tabletController = TextEditingController();
  final TextEditingController _dosageController = TextEditingController();
  int _totalDosage = 0;

  // Add new properties
  late int _minTablets;
  late int _maxTablets;

  @override
  void initState() {
    super.initState();
    _parseDirections();
    _tabletController.text = _minTablets.toString();
    _updateDosage();
  }

void _parseDirections() {
  String directions = widget.selectedMedicine['directions of use'].toLowerCase();
  
  // First check for explicit single dose amount
  RegExp singleDoseRegex = RegExp(r'(\d+)(?:\s*-\s*(\d+))?\s*(?:tablet|capsule)s?\s+(?:per dose|at a time|every|each)');
  Match? singleDoseMatch = singleDoseRegex.firstMatch(directions);
  
  if (singleDoseMatch != null) {
    _minTablets = int.parse(singleDoseMatch.group(1)!);
    _maxTablets = int.parse(singleDoseMatch.group(2) ?? singleDoseMatch.group(1)!);
    return;
  }

  // Check for initial dose
  RegExp initialDoseRegex = RegExp(r'initial:\s*(\d+)\s*(?:tablet|capsule)s?');
  Match? initialMatch = initialDoseRegex.firstMatch(directions);
  if (initialMatch != null) {
    _minTablets = 1;  // After initial dose, usually 1 tablet
    _maxTablets = 1;
    return;
  }

  // Check for maximum daily limit to determine per-dose limit
  RegExp maxDailyRegex = RegExp(r'maximum.*?(\d+).*?(?:tablet|capsule)s?.*?(?:daily|24\s*hours|per day)');
  Match? maxDailyMatch = maxDailyRegex.firstMatch(directions);
  
  if (maxDailyMatch != null) {
    int maxDaily = int.parse(maxDailyMatch.group(1)!);
    
    // Look for dosing frequency
    RegExp frequencyRegex = RegExp(r'every\s*(\d+)[-\s]*(\d+)?\s*hours|(\d+)\s*times?\s*(?:per|a)\s*day');
    Match? frequencyMatch = frequencyRegex.firstMatch(directions);
    
    if (frequencyMatch != null) {
      int frequency;
      if (frequencyMatch.group(3) != null) {
        // "X times per day" format
        frequency = int.parse(frequencyMatch.group(3)!);
      } else {
        // "every X hours" format
        int hours = int.parse(frequencyMatch.group(1)!);
        frequency = 24 ~/ hours;
      }
      
      // Set max tablets per dose based on daily max divided by frequency
      _minTablets = 1;
      _maxTablets = 1;  // Default to 1 unless explicitly stated otherwise
      return;
    }
  }

  // If no specific instructions found, default to safe values
  _minTablets = 1;
  _maxTablets = 1;  // Default to 1 tablet per dose to be safe
}

  void _updateDosage() {
    int tablets = int.tryParse(_tabletController.text) ?? 0;
    // Ensure tablets stay within allowed range
    tablets = tablets.clamp(_minTablets, _maxTablets);
    _tabletController.text = tablets.toString();
    
    int dosagePerTablet = int.tryParse(widget.selectedMedicine['dosage'].split(' ')[0]) ?? 0;
    int totalDosage = tablets * dosagePerTablet;
    int maxDailyDose = _extractMaxDailyDose(widget.selectedMedicine['directions of use']);
    
    if (totalDosage > maxDailyDose) {
      totalDosage = maxDailyDose;
      tablets = (maxDailyDose ~/ dosagePerTablet).clamp(_minTablets, _maxTablets);
      _tabletController.text = tablets.toString();
    }
    
    _dosageController.text = '$totalDosage mg';
    _totalDosage = totalDosage;
  }

  int _extractMaxDailyDose(String directions) {
    // Try to find maximum daily dose in the directions
    RegExp regExp = RegExp(r'maximum daily dose of (\d+)\s*mg|exceed (\d+)\s*mg|max[.\s]+(\d+)\s*mg');
    Match? match = regExp.firstMatch(directions);
    if (match != null) {
      String? value = match.group(1) ?? match.group(2) ?? match.group(3);
      return int.parse(value!);
    }
    
    // If no max dose found, calculate based on dosage and max tablets
    int dosagePerTablet = int.tryParse(widget.selectedMedicine['dosage'].split(' ')[0]) ?? 0;
    return dosagePerTablet * _maxTablets * 4; // Assume 4 doses per day if not specified
  }

  void _incrementTablets() {
    int currentTablets = int.tryParse(_tabletController.text) ?? 0;
    if (currentTablets < _maxTablets) {
      _tabletController.text = (currentTablets + 1).toString();
      _updateDosage();
    }
  }

  void _decrementTablets() {
    int currentTablets = int.tryParse(_tabletController.text) ?? 0;
    if (currentTablets > _minTablets) {
      _tabletController.text = (currentTablets - 1).toString();
      _updateDosage();
    }
  }

  Future<int> _getTotalDailyDosage(String userId, String medicineName) async {
    // Get today's start and end time
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    final endOfDay = startOfDay.add(Duration(days: 1)).subtract(Duration(microseconds: 1));

    // Query history for today's intake
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('history')
        .where('medicine.name', isEqualTo: medicineName)
        .where('takenAt', isGreaterThanOrEqualTo: startOfDay)
        .where('takenAt', isLessThanOrEqualTo: endOfDay)
        .where('status', isEqualTo: 'taken')
        .get();

    // Calculate total dosage taken today
    int totalDosage = 0;
    for (var doc in querySnapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      totalDosage += (data['dosage'] as num).toInt();
    }

    return totalDosage;
  }

  void _takeMedicine() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Confirm Medicine Intake'),
          content: Text('Are you sure you want to record taking this medicine?'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                try {
                  final prefs = await SharedPreferences.getInstance();
                  final userId = prefs.getString('userId');
                  
                  // Validate userId
                  if (userId == null || userId.isEmpty) {
                    throw Exception('User ID not found');
                  }

                  // Check if all required data is present
                  if (_totalDosage == 0 || _tabletController.text.isEmpty) {
                    throw Exception('Invalid dosage or tablet count');
                  }

                  // Prepare history data
                  final historyData = {
                    'medicine': widget.selectedMedicine,
                    'tablets': int.tryParse(_tabletController.text) ?? 0,
                    'dosage': _totalDosage,
                    'takenAt': Timestamp.now(),
                    'status': 'taken',
                    'maxDailyDose': _extractMaxDailyDose(widget.selectedMedicine['directions of use']),
                    'userId': userId,
                    'date': Timestamp.fromDate(DateTime(
                      DateTime.now().year,
                      DateTime.now().month,
                      DateTime.now().day,
                    )),
                    'isOneTime': true,
                  };

                  // Save to history collection with error checking
                  final docRef = await FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId)
                      .collection('history')
                      .add(historyData);

                  // Verify the document was created
                  final doc = await docRef.get();
                  if (!doc.exists) {
                    throw Exception('Failed to create history document');
                  }

                  // Close dialogs
                  Navigator.of(context).pop();
                  Navigator.pop(context);

                  // Navigate based on whether medicine needs timing
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(
                      builder: (context) => HomeScreen(
                        userName: '',
                        initialIndex: widget.needsSpecificTiming ? 3 : 0,
                        reminderData: widget.needsSpecificTiming ? {
                          'medicine': widget.selectedMedicine,
                          'nextIntake': _calculateNextIntake(widget.selectedMedicine['directions of use']),
                          'tablets': int.tryParse(_tabletController.text) ?? 0,
                          'dosage': _totalDosage,
                          'isOneTime': false,
                        } : null,
                      ),
                    ),
                    (route) => false,
                  );

                } catch (e, stackTrace) {
                  print('Error saving medicine history: $e');
                  print('Stack trace: $stackTrace'); // Add stack trace for debugging
                  
                  // Show detailed error message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error recording medicine intake: ${e.toString()}'),
                        backgroundColor: Colors.red,
                        duration: Duration(seconds: 5),
                        action: SnackBarAction(
                          label: 'Dismiss',
                          onPressed: () {},
                          textColor: Colors.white,
                        ),
                      ),
                    );
                  }
                }
              },
              child: Text('Confirm'),
            ),
          ],
        );
      },
    );
  }

  DateTime _calculateNextIntake(String directions) {
    directions = directions.toLowerCase();
    
    // First check for specific intervals with numbers
    RegExp intervalRegex = RegExp(r'every\s+(\d+)[-\s]*(\d+)?\s*(?:hours?|hrs?)');
    Match? intervalMatch = intervalRegex.firstMatch(directions);
    
    if (intervalMatch != null) {
      // If range given (e.g., "4-6 hours"), use minimum
      int hours = int.parse(intervalMatch.group(1)!);
      return DateTime.now().add(Duration(hours: hours));
    }

    // Check for times per day
    RegExp timesPerDayRegex = RegExp(r'(\d+)\s*times?\s*(?:per|a)\s*day|(\d+)\s*times?\s*daily');
    Match? timesMatch = timesPerDayRegex.firstMatch(directions);
    
    if (timesMatch != null) {
      int timesPerDay = int.parse(timesMatch.group(1) ?? timesMatch.group(2)!);
      int hoursInterval = 24 ~/ timesPerDay;
      return DateTime.now().add(Duration(hours: hoursInterval));
    }

    // Extract dosing interval from max daily dose
    RegExp maxDailyRegex = RegExp(r'(?:maximum|max|not to exceed)[^.]*?(\d+).*?(?:tablet|capsule)s?[^.]*?(?:24\s*hours?|daily|per day)');
    Match? maxDailyMatch = maxDailyRegex.firstMatch(directions);
    
    if (maxDailyMatch != null) {
      int maxTablets = int.parse(maxDailyMatch.group(1)!);
      // Calculate minimum interval to stay under max daily dose
      int minHours = 24 ~/ maxTablets;
      return DateTime.now().add(Duration(hours: minHours));
    }

    // Default to 6 hours if no clear interval found
    return DateTime.now().add(Duration(hours: 6));
  }

  @override
  void dispose() {
    _tabletController.dispose();
    _dosageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min, // Make the column wrap its content
        children: [
          Text(
            'Selected Medicine: ${widget.selectedMedicine['name']}',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 16.0),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _tabletController,
                  keyboardType: TextInputType.number,
                  readOnly: _minTablets == _maxTablets, // Make read-only if fixed tablet count
                  decoration: InputDecoration(
                    labelText: _minTablets == _maxTablets 
                        ? 'Number of tablets (${_minTablets})' 
                        : 'Number of tablets (${_minTablets}-${_maxTablets})',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                  ),
                  onChanged: (value) {
                    int? tablets = int.tryParse(value);
                    if (tablets != null) {
                      if (tablets < _minTablets) {
                        _tabletController.text = _minTablets.toString();
                      } else if (tablets > _maxTablets) {
                        _tabletController.text = _maxTablets.toString();
                      }
                    }
                    _updateDosage();
                  },
                ),
              ),
              if (_minTablets != _maxTablets) ...[
                IconButton(
                  icon: Icon(Icons.remove),
                  onPressed: _decrementTablets,
                ),
                IconButton(
                  icon: Icon(Icons.add),
                  onPressed: _incrementTablets,
                ),
              ],
            ],
          ),
          SizedBox(height: 16.0),
          TextField(
            controller: _dosageController,
            readOnly: true,
            decoration: InputDecoration(
              labelText: 'Total dosage',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ),
          SizedBox(height: 16.0),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.grey[300]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Directions of Use:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(widget.selectedMedicine['directions of use']),
                SizedBox(height: 12),
                Text(
                  'Administration:',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(widget.selectedMedicine['administration']),
                SizedBox(height: 12),
                // Add Contraindications section
                Text(
                  'Contraindications:',
                  style: TextStyle(
                    fontWeight: FontWeight.bold, 
                    fontSize: 16, 
                    color: Colors.red[700]
                  ),
                ),
                SizedBox(height: 4),
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red[100]!),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.warning_amber, 
                            color: Colors.red[700], 
                            size: 20
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Do not take this medicine if:',
                            style: TextStyle(
                              fontWeight: FontWeight.w500,
                              color: Colors.red[700]
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 4),
                      Text(
                        widget.selectedMedicine['contraindication'],
                        style: TextStyle(color: Colors.red[700]),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: _takeMedicine,
                  child: Text('Take Now'),
                  style: ElevatedButton.styleFrom(
                    minimumSize: Size(double.infinity, 48), // Make button wider
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 16.0), // Add bottom padding
        ],
      ),
    );
  }
}
