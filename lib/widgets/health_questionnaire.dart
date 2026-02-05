import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:medknows/models/user_data.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'dart:io';

class HealthQuestionnaire extends StatefulWidget {
  final Function(Map<String, dynamic>) onComplete;
  final UserData userData;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic>? reminderData;

  const HealthQuestionnaire({
    Key? key, 
    required this.onComplete, 
    required this.userData,
    this.initialData, 
    this.reminderData,
  }) : super(key: key);

  @override
  _HealthQuestionnaireState createState() => _HealthQuestionnaireState();
}

class _HealthQuestionnaireState extends State<HealthQuestionnaire> {
  final _formKey = GlobalKey<FormState>();

  // Symptoms only
  final Map<String, bool> symptoms = {
    'Headache': false,
    'Fever': false,
    'Cough': false,
    'Muscle Pain': false,
    'Colds': false,
    'Other': false,
  };
  final otherSymptomsController = TextEditingController();
  String? symptomsDuration;

  // Add new controllers for vitals
  final TextEditingController _temperatureController = TextEditingController();
  final TextEditingController _systolicController = TextEditingController();
  final TextEditingController _diastolicController = TextEditingController();
  String _temperatureUnit = '°C'; // or '°F'

  // Update the unit toggle for temperature
  Widget _buildTemperatureToggle() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: ['°C', '°F'].map((unit) => 
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(unit),
              selected: _temperatureUnit == unit,
              selectedColor: Colors.blue,
              backgroundColor: Colors.blue.shade50,
              side: BorderSide(color: Colors.blue.shade200),
              labelStyle: TextStyle(
                color: _temperatureUnit == unit ? Colors.white : Colors.blue.shade700,
              ),
              onSelected: (selected) {
                if (selected && unit != _temperatureUnit) {
                  _convertTemperature(unit);
                }
              },
            ),
          ),
        ).toList(),
      ),
    );
  }

  // Update the temperature conversion method
  void _convertTemperature(String unit) {
    if (unit == _temperatureUnit) return;
    
    String currentValue = _temperatureController.text;
    if (currentValue.isEmpty) {
      setState(() => _temperatureUnit = unit);
      return;
    }

    try {
      double temp = double.parse(currentValue);
      double convertedTemp;

      if (unit == '°F') {
        // Convert Celsius to Fahrenheit
        convertedTemp = (temp * 9/5) + 32;
      } else {
        // Convert Fahrenheit to Celsius
        convertedTemp = (temp - 32) * 5/9;
      }

      setState(() {
        _temperatureController.text = convertedTemp.toStringAsFixed(1);
        _temperatureUnit = unit;
      });
    } catch (e) {
      print('Error converting temperature: $e');
    }
  }

  Widget _buildStepperSection(String title, List<Widget> children) {
    return Container(
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.vertical(top: Radius.circular(11)),
            ),
            child: Text(
              title,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.blue,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: children,
            ),
          ),
        ],
      ),
    );
  }

  // Update the Vitals Section in the build method
  Widget _buildVitalsSection() {
    return _buildStepperSection(
      'Vital Signs',
      [
        Text(
          'Temperature',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _temperatureController,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Temperature (${_temperatureUnit})',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: _temperatureUnit == '°C' ? '' : '',
                ),
              ),
            ),
            SizedBox(width: 8),
            _buildTemperatureToggle(),
          ],
        ),
        SizedBox(height: 16),
        Text(
          'Blood Pressure',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
        ),
        SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: _systolicController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Systolic',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  hintText: '',
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('/', style: TextStyle(fontSize: 24)),
            ),
            Expanded(
              child: TextFormField(
                controller: _diastolicController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Diastolic',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(8)),
                  hintText: '',
                ),
              ),
            ),
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: Text('mmHg', style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ],
    );
  }

  Future<Map<String, dynamic>?> _getHealthData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userData.id)
          .get();

      if (!doc.exists) return null;

      final initialHealth = doc.data()?['initialHealth'];
      return initialHealth;
    } catch (e) {
      print('Error loading health data: $e');
      return null;
    }
  }

  Future<void> _generateAndSavePDF() async {
    final healthData = await _getHealthData();
    if (healthData == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading health data'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return;
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        build: (context) => [
          pw.Header(
            level: 0,
            text: 'Health Assessment Report', // Changed from child to text
            textStyle: pw.TextStyle(
              fontSize: 24,
              fontWeight: pw.FontWeight.bold,
            ),
          ),
          pw.SizedBox(height: 20),

          // Personal Information
          _buildPDFSection('Personal Information', [
            _buildPDFRow('Name', widget.userData.name),
            _buildPDFRow('Birthdate', widget.userData.birthdate),
            _buildPDFRow('Age', '${widget.userData.age} years'),
            _buildPDFRow('Height', '${widget.userData.height} cm'),
            _buildPDFRow('Weight', '${widget.userData.weight} kg'),
          ]),

          // Vital Signs
          _buildPDFSection('Vital Signs', [
            _buildPDFRow('Temperature', 
              '${_temperatureController.text} ${_temperatureUnit}'),
            _buildPDFRow('Blood Pressure', 
              '${_systolicController.text}/${_diastolicController.text} mmHg'),
          ]),

          // Medical History
          _buildPDFSection('Medical History', [
            ...(healthData['healthConditions'] as Map<String, dynamic>)
                .entries
                .where((e) => e.value == true)
                .map((e) => _buildPDFRow('Condition', e.key)),
          ]),

          // Current Medications
          _buildPDFSection('Current Medications', [
            _buildPDFRow('Taking Medications', 
              healthData['takingMedications'] ?? 'No'),
            if (healthData['takingMedications'] == 'Yes')
              _buildPDFRow('Medications List', 
                healthData['currentMedications'] ?? ''),
          ]),

          // Allergies
          _buildPDFSection('Allergies', [
            _buildPDFRow('Has Allergies', 
              healthData['hasAllergies'] ?? 'No'),
            if (healthData['hasAllergies'] == 'Yes')
              _buildPDFRow('Allergies List', 
                healthData['allergies'] ?? ''),
          ]),

          // Lifestyle
          _buildPDFSection('Lifestyle', [
            _buildPDFRow('Smoking', healthData['smoking'] ?? 'No'),
            _buildPDFRow('Alcohol Consumption', healthData['drinking'] ?? 'No'),
          ]),

          // Current Symptoms
          _buildPDFSection('Current Symptoms', [
            ...symptoms.entries
              .where((e) => e.value)
              .map((e) => _buildPDFRow('Symptom', e.key)),
            if (symptoms['Other'] == true)
              _buildPDFRow('Other Symptoms', otherSymptomsController.text),
            _buildPDFRow('Duration', symptomsDuration ?? ''),
          ]),

          // Pregnancy Information (if applicable)
          if (widget.userData.sex == 'Female' && 
              widget.userData.age >= 12 && 
              healthData['isPregnant'] == true)
            _buildPDFSection('Pregnancy Information', [
              _buildPDFRow('Pregnant', 'Yes'),
              _buildPDFRow('Trimester', healthData['pregnancyTrimester'] ?? ''),
            ]),

          // Footer with timestamp and page numbers
          pw.Container(
            alignment: pw.Alignment.centerRight,
            margin: const pw.EdgeInsets.only(top: 20),
            child: pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Generated: ${DateTime.now().toString().split('.')[0]}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
                pw.Text(
                  'Page ${context.pageNumber} of ${context.pagesCount}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColors.grey),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    // Save the PDF
    try {
      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/health_assessment_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      
      // Open the PDF
      await OpenFile.open(file.path);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('PDF saved successfully'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      print('Error saving PDF: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error saving PDF'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  pw.Widget _buildPDFSection(String title, List<pw.Widget> content) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Header(
          level: 1,
          text: title, // Changed from child to text
          textStyle: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.SizedBox(height: 10),
        ...content,
        pw.SizedBox(height: 20),
      ],
    );
  }

  pw.Widget _buildPDFRow(String label, String value) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: 4),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 150,
            child: pw.Text(
              label,
              style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
            ),
          ),
          pw.Expanded(
            child: pw.Text(value),
          ),
        ],
      ),
    );
  }

  void _handleContinue() {
    if (!_hasSelectedSymptoms()) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.amber),
                SizedBox(width: 8),
                Text('Missing Information'),
              ],
            ),
            content: Text('Please select at least one symptom.'),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
      return;
    }

    if (symptomsDuration == null) {
      showDialog(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.amber),
                SizedBox(width: 8),
                Text('Missing Information'),
              ],
            ),
            content: Text('Please select the duration of your symptoms.'),
            actions: [
              TextButton(
                child: Text('OK'),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          );
        },
      );
      return;
    }

    if (_formKey.currentState!.validate()) {
      // Ensure all required fields are included with default values
      Map<String, Object> questionnaireData = {
        'vitals': {
          'temperature': _temperatureController.text.isEmpty ? '37.0' : _temperatureController.text,
          'temperatureUnit': _temperatureUnit,
          'bloodPressure': _systolicController.text.isEmpty || _diastolicController.text.isEmpty 
              ? '120/80' 
              : '${_systolicController.text}/${_diastolicController.text}',
        },
        'symptoms': Map<String, bool>.from(symptoms),
        'otherSymptoms': otherSymptomsController.text,
        'symptomsDuration': symptomsDuration ?? 'Less than a day',
        'healthConditions': {
          'diabetes': false,
          'high blood pressure': false,
          'heart disease': false,
          'asthma': false,
        },
        'takingMedications': 'No',
        'currentMedications': '',
        'hasAllergies': 'No',
        'allergies': '',
        'isPregnant': false,
        'pregnancyTrimester': '',
        'smoking': 'No',
        'drinking': 'No',
      } as Map<String, Object>;

      // Merge with initialData if it exists
      if (widget.initialData != null) {
        // Convert initialData to non-nullable Map
        final Map<String, Object> safeInitialData = Map<String, Object>.from(
          widget.initialData!.map((key, value) => MapEntry(
            key,
            value ?? '',  // Replace null values with empty string
          )),
        );
        questionnaireData.addAll(safeInitialData);
      }

      widget.onComplete(questionnaireData);
    }
  }

  // Add this method to check if any symptoms are selected
  bool _hasSelectedSymptoms() {
    return symptoms.entries.any((entry) => entry.value);
  }

  // Update the continue button widget
  Widget _buildButtons() {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
      child: SizedBox(
        width: double.infinity,
        height: 56,
        child: ElevatedButton(
          onPressed: _handleContinue,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: Text(
            'Continue',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: ColorScheme.light(
          primary: Colors.blue,
          secondary: Colors.blue.shade700,
        ),
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
        inputDecorationTheme: InputDecorationTheme(
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.blue, width: 2),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(8),
            borderSide: BorderSide(color: Colors.blue.shade200),
          ),
          focusColor: Colors.blue,
          labelStyle: TextStyle(color: Colors.blue.shade700),
        ),
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Updated medical disclaimer
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.yellow.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.yellow.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.medical_services, color: Colors.yellow.shade900),
                        SizedBox(width: 8),
                        Text(
                          'Health Assessment',  // Updated title
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 16,
                            color: Colors.yellow.shade900,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Please record your vital signs and check all symptoms you are currently experiencing.',  // Updated description
                      style: TextStyle(color: Colors.yellow.shade900),
                    ),
                  ],
                ),
              ),

              // Add Vitals Section
              _buildVitalsSection(),

              // Symptoms Section
              _buildStepperSection(
                'Current Symptoms',
                [
                  ...symptoms.entries.map((entry) => CheckboxListTile(
                    title: Text(entry.key),
                    value: entry.value,
                    onChanged: (bool? value) {
                      setState(() => symptoms[entry.key] = value!);
                    },
                  )).toList(),
                  if (symptoms['Other']!)
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 16),
                      child: TextFormField(
                        controller: otherSymptomsController,
                        decoration: InputDecoration(
                          labelText: 'Specify other symptoms',
                          hintText: 'e.g., stomach pain, dizziness',
                        ),
                        validator: (value) => symptoms['Other']! && value!.isEmpty
                            ? 'Please specify other symptoms'
                            : null,
                      ),
                    ),
                ],
              ),

              // Duration Section
              _buildStepperSection(
                'Symptoms Duration',
                [
                  ...['Less than a day', '1-3 days', 'More than 3 days'].map((duration) =>
                    RadioListTile(
                      title: Text(duration),
                      value: duration,
                      groupValue: symptomsDuration,
                      onChanged: (value) => setState(() => symptomsDuration = value.toString()),
                    ),
                  ).toList(),
                ],
              ),

              // Replace the old button section with the new one
              _buildButtons(),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _temperatureController.dispose();
    _systolicController.dispose();
    _diastolicController.dispose();
    otherSymptomsController.dispose();
    super.dispose();
  }
}
