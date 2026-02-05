import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class MaintenanceReminderForm extends StatefulWidget {
  final Function(Map<String, dynamic>) onComplete;

  const MaintenanceReminderForm({
    Key? key,
    required this.onComplete,
  }) : super(key: key);

  @override
  _MaintenanceReminderFormState createState() => _MaintenanceReminderFormState();
}

class _MaintenanceReminderFormState extends State<MaintenanceReminderForm> {
  final _formKey = GlobalKey<FormState>();
  final _brandNameController = TextEditingController();
  final _genericNameController = TextEditingController();
  final _quantityController = TextEditingController();
  TimeOfDay _selectedTime = TimeOfDay.now();
  int _tabletCount = 1;

  final Map<String, bool> _selectedDays = {
    'Monday': false,
    'Tuesday': false,
    'Wednesday': false,
    'Thursday': false,
    'Friday': false,
    'Saturday': false,
    'Sunday': false,
  };
  String _repeatOption = 'daily'; // 'daily' or 'custom'

  Widget _buildRepeatSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Repeat',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.blue,
          ),
        ),
        ListTile(
          title: Text('Every day'),
          leading: Radio<String>(
            value: 'daily',
            groupValue: _repeatOption,
            onChanged: (value) {
              setState(() {
                _repeatOption = value!;
                // Reset all days to false when switching to daily
                _selectedDays.updateAll((key, value) => false);
              });
            },
          ),
        ),
        ListTile(
          title: Text('Custom'),
          leading: Radio<String>(
            value: 'custom',
            groupValue: _repeatOption,
            onChanged: (value) {
              setState(() {
                _repeatOption = value!;
              });
            },
          ),
        ),
        if (_repeatOption == 'custom')
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: _selectedDays.entries.map((entry) {
                return CheckboxListTile(
                  title: Text(entry.key),
                  value: entry.value,
                  onChanged: (bool? value) {
                    setState(() {
                      _selectedDays[entry.key] = value!;
                    });
                  },
                  dense: true,
                );
              }).toList(),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: EdgeInsets.all(16),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Maintenance Medicine Details',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _brandNameController,
              decoration: InputDecoration(
                labelText: 'Brand Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter brand name' : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _genericNameController,
              decoration: InputDecoration(
                labelText: 'Generic Name',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter generic name' : null,
            ),
            SizedBox(height: 16),
            TextFormField(
              controller: _quantityController,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(
                labelText: 'Current Quantity (tablets)',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  value?.isEmpty ?? true ? 'Please enter quantity' : null,
            ),
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey.shade300),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tablets per dose',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        icon: Icon(Icons.remove_circle),
                        onPressed: _tabletCount > 1
                            ? () => setState(() => _tabletCount--)
                            : null,
                      ),
                      Text(
                        '$_tabletCount tablet(s)',
                        style: TextStyle(fontSize: 16),
                      ),
                      IconButton(
                        icon: Icon(Icons.add_circle),
                        onPressed: () => setState(() => _tabletCount++),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),
            _buildRepeatSection(),
            SizedBox(height: 16),
            ListTile(
              title: Text('Time to take'),
              subtitle: Text(_selectedTime.format(context)),
              trailing: Icon(Icons.access_time),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              onTap: () async {
                final TimeOfDay? time = await showTimePicker(
                  context: context,
                  initialTime: _selectedTime,
                );
                if (time != null) {
                  setState(() => _selectedTime = time);
                }
              },
            ),
            SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _handleSubmit,
                child: Text('Set Reminder'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleSubmit() {
    if (_formKey.currentState?.validate() ?? false) {
      // Format time in 12-hour format for display
      final formattedTime = '${_selectedTime.hourOfPeriod}:${_selectedTime.minute.toString().padLeft(2, '0')} ${_selectedTime.period == DayPeriod.am ? 'AM' : 'PM'}';

      // Create scheduled days list
      List<String> scheduledDays;
      if (_repeatOption == 'daily') {
        scheduledDays = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      } else {
        scheduledDays = _selectedDays.entries
            .where((entry) => entry.value)
            .map((entry) => entry.key)
            .toList();
      }

      // Validate at least one day is selected for custom option
      if (_repeatOption == 'custom' && scheduledDays.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Please select at least one day'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      final data = {
        'medicine': {
          'name': _brandNameController.text,
          'genericName': _genericNameController.text,
          'isMaintenanceIcon': true,
        },
        'quantity': int.parse(_quantityController.text),
        'tabletCount': _tabletCount,
        'time': formattedTime,
        'hour': _selectedTime.hour,
        'minute': _selectedTime.minute,
        'isMaintenance': true,
        'repeatOption': _repeatOption,
        'scheduledDays': scheduledDays,
        'lowStockThreshold': 10,
        'nextIntake': _calculateNextIntake(),
      };
      widget.onComplete(data);
    }
  }

  DateTime _calculateNextIntake() {
    final now = DateTime.now();
    var scheduledTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    if (_repeatOption == 'daily') {
      // If time has passed today, schedule for tomorrow
      if (scheduledTime.isBefore(now)) {
        scheduledTime = scheduledTime.add(Duration(days: 1));
      }
    } else {
      // Find the next scheduled day
      int daysToAdd = 0;
      bool foundNext = false;
      
      for (int i = 0; i < 7; i++) {
        final checkDate = now.add(Duration(days: i));
        final weekday = _getWeekday(checkDate);
        
        if (_selectedDays[weekday] == true) {
          if (i == 0) {
            // Today is a scheduled day
            if (scheduledTime.isBefore(now)) {
              // Time has passed, look for next day
              continue;
            }
          }
          daysToAdd = i;
          foundNext = true;
          break;
        }
      }
      
      if (!foundNext) {
        // If no upcoming day found, find the first scheduled day next week
        for (int i = 0; i < 7; i++) {
          final weekday = _getWeekday(now.add(Duration(days: i)));
          if (_selectedDays[weekday] == true) {
            daysToAdd = i + 7;
            break;
          }
        }
      }
      
      scheduledTime = DateTime(
        now.year,
        now.month,
        now.day + daysToAdd,
        _selectedTime.hour,
        _selectedTime.minute,
      );
    }

    return scheduledTime;
  }

  String _getWeekday(DateTime date) {
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

  @override
  void dispose() {
    _brandNameController.dispose();
    _genericNameController.dispose();
    _quantityController.dispose();
    super.dispose();
  }
}
