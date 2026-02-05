import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:medknows/widgets/health_questionnaire.dart';
import '../models/user_data.dart';
import 'home_screen.dart';

class InitialHealthScreen extends StatefulWidget {
  final UserData userData;
  final bool isEditing;  // Add this

  const InitialHealthScreen({
    Key? key,
    required this.userData,
    this.isEditing = false,  // Add this
  }) : super(key: key);

  @override
  _InitialHealthScreenState createState() => _InitialHealthScreenState();
}

class _InitialHealthScreenState extends State<InitialHealthScreen> {
  final _formKey = GlobalKey<FormState>();
  
  // Health Conditions - removed 'Other' option
  final Map<String, bool> healthConditions = {
    'Diabetes': false,
    'High blood pressure': false,
    'Heart disease': false,
    'Asthma': false,
  };

  // Current Medications
  String? takingMedications;
  final currentMedicationsController = TextEditingController();
  String? hasAllergies;
  final allergiesController = TextEditingController();

  // Lifestyle
  String? smoking;
  String? drinking;

  // Pregnancy (for females)
  bool? isPregnant;
  String trimester = 'First';

  @override
  void initState() {
    super.initState();
    if (widget.isEditing) {
      _loadExistingHealthData();
    }
  }

  Future<void> _loadExistingHealthData() async {
    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userData.id)
          .get();

      if (!doc.exists) return;

      final initialHealth = doc.data()?['initialHealth'];
      if (initialHealth == null) return;

      setState(() {
        healthConditions.forEach((key, _) {
          healthConditions[key] = initialHealth['healthConditions'][key] ?? false;
        });
        
        takingMedications = initialHealth['takingMedications'];
        currentMedicationsController.text = initialHealth['currentMedications'] ?? '';
        
        hasAllergies = initialHealth['hasAllergies'];
        allergiesController.text = initialHealth['allergies'] ?? '';
        
        smoking = initialHealth['smoking'];
        drinking = initialHealth['drinking'];
        
        if (widget.userData.sex == 'Female' && widget.userData.age >= 12) {
          isPregnant = initialHealth['isPregnant'];
          if (isPregnant == true) {
            trimester = initialHealth['pregnancyTrimester'];
          }
        }
      });
    } catch (e) {
      print('Error loading health data: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error loading existing health data'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _saveQuestionnaireData(BuildContext context, Map<String, dynamic> data) async {
    try {
      // Save to Firebase
      await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userData.id)
          .update({
        'healthQuestionnaire': data,
        'hasCompletedInitialQuestionnaire': true,
      });

      if (context.mounted) {
        // Navigate to home screen and remove all previous routes
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => HomeScreen(
              userName: widget.userData.name,
            ),
          ),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print('Error saving questionnaire data: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving health information. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
              children: [
                // Medical History Section
                if (title == 'Medical History') ...[
                  Text('Do you have any of these conditions?'),
                  ...healthConditions.entries.map((entry) => CheckboxListTile(
                    title: Text(entry.key),
                    value: entry.value,
                    onChanged: (bool? value) {
                      setState(() => healthConditions[entry.key] = value!);
                    },
                  )).toList(),
                ],

                // Pregnancy Section
                if (title == 'Pregnancy Information') ...[
                  RadioListTile<bool>(
                    title: Text('Yes'),
                    value: true,
                    groupValue: isPregnant,
                    onChanged: (value) => setState(() => isPregnant = value),
                  ),
                  RadioListTile<bool>(
                    title: Text('No'),
                    value: false,
                    groupValue: isPregnant,
                    onChanged: (value) => setState(() => isPregnant = value),
                  ),
                  if (isPregnant == true) ...[
                    Text('Which trimester are you in?'),
                    ...['First', 'Second', 'Third'].map((t) => RadioListTile<String>(
                      title: Text(t),
                      value: t,
                      groupValue: trimester,
                      onChanged: (value) => setState(() => trimester = value!),
                    )).toList(),
                  ],
                ],

                // Current Medications Section
                if (title == 'Current Medications') ...[
                  Text('Are you taking any medications?'),
                  RadioListTile(
                    title: Text('Yes'),
                    value: 'Yes',
                    groupValue: takingMedications,
                    onChanged: (value) => setState(() => takingMedications = value.toString()),
                  ),
                  RadioListTile(
                    title: Text('No'),
                    value: 'No',
                    groupValue: takingMedications,
                    onChanged: (value) => setState(() => takingMedications = value.toString()),
                  ),
                  if (takingMedications == 'Yes')
                    TextFormField(
                      controller: currentMedicationsController,
                      decoration: InputDecoration(labelText: 'List your current medications'),
                      validator: (value) => takingMedications == 'Yes' && value!.isEmpty
                          ? 'Please list your medications'
                          : null,
                    ),
                ],

                // Allergies Section
                if (title == 'Allergies') ...[
                  Text('Do you have any medication allergies?'),
                  RadioListTile(
                    title: Text('Yes'),
                    value: 'Yes',
                    groupValue: hasAllergies,
                    onChanged: (value) => setState(() => hasAllergies = value.toString()),
                  ),
                  RadioListTile(
                    title: Text('No'),
                    value: 'No',
                    groupValue: hasAllergies,
                    onChanged: (value) => setState(() => hasAllergies = value.toString()),
                  ),
                  if (hasAllergies == 'Yes')
                    TextFormField(
                      controller: allergiesController,
                      decoration: InputDecoration(labelText: 'List your medication allergies'),
                      validator: (value) => hasAllergies == 'Yes' && value!.isEmpty
                          ? 'Please list your allergies'
                          : null,
                    ),
                ],

                // Lifestyle Section
                if (title == 'Lifestyle') ...[
                  Text('Do you smoke?'),
                  RadioListTile(
                    title: Text('Yes'),
                    value: 'Yes',
                    groupValue: smoking,
                    onChanged: (value) => setState(() => smoking = value.toString()),
                  ),
                  RadioListTile(
                    title: Text('No'),
                    value: 'No',
                    groupValue: smoking,
                    onChanged: (value) => setState(() => smoking = value.toString()),
                  ),
                  SizedBox(height: 16),
                  Text('Do you drink alcohol?'),
                  RadioListTile(
                    title: Text('Yes'),
                    value: 'Yes',
                    groupValue: drinking,
                    onChanged: (value) => setState(() => drinking = value.toString()),
                  ),
                  RadioListTile(
                    title: Text('No'),
                    value: 'No',
                    groupValue: drinking,
                    onChanged: (value) => setState(() => drinking = value.toString()),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bool showPregnancyQuestions = widget.userData.sex == 'Female' && 
                                      widget.userData.age >= 12;

    return Theme(
      data: Theme.of(context).copyWith(
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
      ),
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.isEditing,  // Show back button if editing
          leading: widget.isEditing 
            ? IconButton(
                icon: Icon(Icons.arrow_back),
                onPressed: () => Navigator.of(context).pop(),
              )
            : null,
          title: Text(
            widget.isEditing ? 'Update Health Information' : 'Initial Health Assessment',
            style: TextStyle(
              color: Colors.blue.withOpacity(1),
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        body: WillPopScope(
          onWillPop: () async => widget.isEditing, // Allow back navigation only in editing mode
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Medical disclaimer
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
                              'Medical Information',
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
                          'This information helps us provide safer recommendations and avoid potential drug interactions.',
                          style: TextStyle(color: Colors.yellow.shade900),
                        ),
                      ],
                    ),
                  ),

                  _buildStepperSection(
                    'Medical History',
                    [
                      // ...existing medical history content...
                    ],
                  ),

                  if (showPregnancyQuestions)
                    _buildStepperSection(
                      'Pregnancy Information',
                      [
                        // ...existing pregnancy questions content...
                      ],
                    ),

                  _buildStepperSection(
                    'Current Medications',
                    [
                      // ...existing medications content...
                    ],
                  ),

                  _buildStepperSection(
                    'Allergies',
                    [
                      // ...existing allergies content...
                    ],
                  ),

                  _buildStepperSection(
                    'Lifestyle',
                    [
                      // ...existing lifestyle content...
                    ],
                  ),

                  // Submit Button
                  Padding(
                    padding: EdgeInsets.all(16),
                    child: SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _saveInitialHealth,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: EdgeInsets.symmetric(vertical: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        child: Text('Complete Assessment'),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Update save method to save initial health data
  Future<void> _saveInitialHealth() async {
    if (!_formKey.currentState!.validate()) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    try {
      // Create base structure for health data
      final initialHealthData = {
        'healthConditions': Map<String, bool>.from(healthConditions),
        'takingMedications': takingMedications ?? 'No',
        'currentMedications': currentMedicationsController.text,
        'hasAllergies': hasAllergies ?? 'No',
        'allergies': allergiesController.text,
        'smoking': smoking ?? 'No',
        'drinking': drinking ?? 'No',
        'vitals': {
          'temperature': '37.0',
          'temperatureUnit': '°C',
          'bloodPressure': '120/80',
        },
        'symptoms': {
          'Headache': false,
          'Fever': false,
          'Cough': false,
          'Muscle Pain': false,
          'Colds': false,
          'Other': false,
        },
        'otherSymptoms': '',
        'symptomsDuration': 'Less than a day',
      };

      // Add pregnancy data if applicable
      if (widget.userData.sex == 'Female' && widget.userData.age >= 12) {
        initialHealthData['isPregnant'] = isPregnant ?? false;
        if (isPregnant == true) {
          initialHealthData['pregnancyTrimester'] = trimester;
        }
      }

      // Get a reference to the user's document
      final userDocRef = FirebaseFirestore.instance
          .collection('users')
          .doc(widget.userData.id);

      // Update the user document with initial health data and questionnaire completion status
      await userDocRef.update({
        'initialHealth': initialHealthData,
        'hasCompletedInitialQuestionnaire': true,
      });

      if (mounted) {
        // Store user ID in SharedPreferences
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('userId', widget.userData.id);

        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (context) => HomeScreen(userName: widget.userData.name),
          ),
          (Route<dynamic> route) => false,
        );
      }
    } catch (e) {
      print('Error saving initial health data: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error saving health information. Please try again.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}
