import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

class HistoryScreen extends StatefulWidget {  // Changed to StatefulWidget
  const HistoryScreen({Key? key}) : super(key: key);

  @override
  _HistoryScreenState createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  DateTime _selectedDate = DateTime.now();

  void _selectDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
      });
    }
  }

  void _changeDate(int days) {
    final newDate = _selectedDate.add(Duration(days: days));
    if (!newDate.isAfter(DateTime.now())) {
      setState(() {
        _selectedDate = newDate;
      });
    }
  }

  Widget _buildDateDisplay() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final selectedDay = DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day);
    
    String dateLabel;
    if (selectedDay == today) {
      dateLabel = 'Today';
    } else if (selectedDay == today.subtract(Duration(days: 1))) {
      dateLabel = 'Yesterday';
    } else {
      dateLabel = DateFormat('MMMM d, y').format(_selectedDate);
    }

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(Icons.chevron_left),
            onPressed: () => _changeDate(-1),
          ),
          Text(
            dateLabel,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: selectedDay == today ? Colors.blue : Colors.black,
            ),
          ),
          IconButton(
            icon: Icon(Icons.chevron_right),
            onPressed: _selectedDate.isBefore(DateTime(today.year, today.month, today.day)) 
                ? () => _changeDate(1) 
                : null,
          ),
        ],
      ),
    );
  }

  Widget _buildDosageSummary(BuildContext context, String userId, Map<String, dynamic> medicine) {
    // Simply return an empty container since we don't want to show totals
    return Container();
  }

  int _extractMaxDailyDose(String directions) {
    RegExp regExp = RegExp(r'maximum daily dose of (\d+)\s*mg|exceed (\d+)\s*mg|max[.\s]+(\d+)\s*mg');
    Match? match = regExp.firstMatch(directions);
    if (match != null) {
      String? value = match.group(1) ?? match.group(2) ?? match.group(3);
      return int.parse(value!);
    }
    return 4000; // Default max daily dose if not specified
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Medicine History'),
        actions: [
          IconButton(
            icon: Icon(Icons.calendar_today),
            onPressed: _selectDate,
          ),
        ],
      ),
      body: Column(
        children: [
          _buildDateDisplay(),
          Expanded(
            child: FutureBuilder<String?>(
              future: SharedPreferences.getInstance()
                  .then((prefs) => prefs.getString('userId')),
              builder: (context, userSnapshot) {
                if (!userSnapshot.hasData) {
                  return Center(child: CircularProgressIndicator());
                }

                final startOfDay = DateTime(
                  _selectedDate.year,
                  _selectedDate.month,
                  _selectedDate.day,
                );
                final endOfDay = startOfDay.add(Duration(days: 1)).subtract(Duration(milliseconds: 1));

                return StreamBuilder<QuerySnapshot>(
                  stream: FirebaseFirestore.instance
                      .collection('users')
                      .doc(userSnapshot.data)
                      .collection('history')
                      .where('takenAt', isGreaterThanOrEqualTo: startOfDay)
                      .where('takenAt', isLessThanOrEqualTo: endOfDay)
                      .orderBy('takenAt', descending: true)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(child: CircularProgressIndicator());
                    }

                    if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                      return Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.history, size: 64, color: Colors.grey[400]),
                            SizedBox(height: 16),
                            Text(
                              'No medicine history for this day',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      );
                    }

                    return ListView.builder(
                      itemCount: snapshot.data!.docs.length,
                      itemBuilder: (context, index) {
                        final doc = snapshot.data!.docs[index];
                        final data = doc.data() as Map<String, dynamic>;
                        // Rest of the card building code...
                        return _buildMedicineCard(data, userSnapshot.data!);
                      },
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

  Widget _buildMedicineCard(Map<String, dynamic> historyData, String userId) {
    final DateTime takenAt = (historyData['takenAt'] as Timestamp).toDate();
    final medicine = historyData['medicine'] as Map<String, dynamic>;
    
    // Check if the entry is from today
    final now = DateTime.now();
    final isToday = takenAt.year == now.year && 
                    takenAt.month == now.month && 
                    takenAt.day == now.day;

    return Card(
      margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: ListTile(
        leading: medicine['isMaintenanceIcon'] == true
          ? Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.medication_rounded,
                color: Colors.blue,
                size: 24,
              ),
            )
          : Image.asset(
              medicine['image'],
              width: 40,
              height: 40,
            ),
        title: Text(
          medicine['name'],
          style: GoogleFonts.openSans(
            fontWeight: FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              medicine['genericName'],
              style: GoogleFonts.openSans(
                fontStyle: FontStyle.italic,
              ),
            ),
            if (historyData['dosages'] != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${historyData['tablets']} tablet(s)',
                    style: GoogleFonts.openSans(),
                  ),
                  ...List.generate(
                    (historyData['dosages'] as List).length,
                    (index) {
                      final dosage = (historyData['dosages'] as List)[index];
                      return Text(
                        '${dosage['amount']} ${dosage['unit']}${dosage['ingredient'].isNotEmpty ? ' ${dosage['ingredient']}' : ''}',
                        style: GoogleFonts.openSans(),
                      );
                    },
                  ),
                ],
              )
            else
              Text(
                '${historyData['tablets']} tablet(s)',
                style: GoogleFonts.openSans(),
              ),
          ],
        ),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              DateFormat('h:mm a').format(takenAt),
              style: GoogleFonts.openSans(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            Text(
              historyData['status'] == 'scheduled' ? 'Scheduled' : 'Taken',
              style: GoogleFonts.openSans(
                color: historyData['status'] == 'scheduled' 
                    ? Colors.orange 
                    : Colors.green,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
