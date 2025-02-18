import 'package:flutter/material.dart';
import 'package:medknows/models/user_data.dart';
import 'package:medknows/utils/active_medicine_manager.dart';  // Add this import

class HealthQuestionnaire extends StatefulWidget {
  final Function(Map<String, dynamic>) onComplete;
  final Map<String, dynamic>? initialData;
  final Map<String, dynamic>? reminderData;  // Add this
  final UserData userData;  // Change this line

  const HealthQuestionnaire({
    Key? key, 
    required this.onComplete, 
    this.initialData, 
    this.reminderData,  // Add this
    required this.userData,  // Change this line
  }) : super(key: key);

  @override
  _HealthQuestionnaireState createState() => _HealthQuestionnaireState();
}

class _HealthQuestionnaireState extends State<HealthQuestionnaire> {
  int _currentStep = 0;
  final _formKey = GlobalKey<FormState>();

  // Health and Symptoms - initialize with null values
  final Map<String, bool> symptoms = {
    'Headache': false,
    'Fever': false,
    'Cough': false,
    'Muscle Pain': false,
    'Colds': false,
    'Other': false,
  };
  final otherSymptomsController = TextEditingController();
  String? symptomsDuration; // Change to nullable
  
  // Health Conditions
  final Map<String, bool> healthConditions = {
    'Diabetes': false,
    'High blood pressure': false,
    'Heart disease': false,
    'Asthma': false,
    'Other': false,
  };
  final otherConditionsController = TextEditingController();

  // Current Medications - initialize with null
  String? takingMedications;
  final currentMedicationsController = TextEditingController();
  String? hasAllergies;
  final allergiesController = TextEditingController();

  // Lifestyle - initialize with null
  String? smoking;
  String? drinking;

  // Add this mapping
  final Map<String, List<String>> symptomToCategoryMap = {
    'Headache': ['Pain Reliever', 'Fever'],
    'Fever': ['Fever', 'Pain Reliever'],
    'Cough': ['Cough', 'Respiratory'],
    'Muscle Pain': ['Pain Reliever', 'Anti-inflammatory'],
    'Colds': ['Cold', 'Flu'],
    'Heartburn': ['Antacid'],
    'Stomach pain': ['Antacid', 'Anti-flatulent'],
    'Gas pain': ['Antacid', 'Anti-flatulent'],
    'Acid reflux': ['Antacid'],
    'Indigestion': ['Antacid'],
    'Bloating': ['Anti-flatulent', 'Antacid'],
    'Sour stomach': ['Antacid'],
    'Diarrhea': ['Antidiarrheal'],
    'Body aches': ['Pain Reliever', 'Anti-inflammatory'],
    'Flu symptoms': ['Cold', 'Flu', 'Fever'],
    // Add these new pain-related symptoms
    'Toothache': ['Pain Reliever'],
    'Joint pain': ['Pain Reliever', 'Anti-inflammatory'],
    'Back pain': ['Pain Reliever', 'Anti-inflammatory'],
    'Menstrual pain': ['Pain Reliever', 'Anti-inflammatory'],
    'Neck pain': ['Pain Reliever', 'Anti-inflammatory'],
    'Ear ache': ['Pain Reliever'],
    'Arthritis pain': ['Pain Reliever', 'Anti-inflammatory'],
    'Dental pain': ['Pain Reliever'],
    'Gum pain': ['Pain Reliever'],
  };

  // Add pregnancy-related state
  bool? isPregnant;
  String trimester = 'First';

  @override
  void initState() {
    super.initState();
    _loadActiveMedicine();
    // Update initial data handling
    if (widget.initialData != null || widget.reminderData != null) {
      takingMedications = 'Yes';
      currentMedicationsController.text = widget.initialData?['currentMedications'] ?? 
        '${widget.reminderData!['medicine']['name']} (${widget.reminderData!['medicine']['genericName']})';
    }
  }

  Future<void> _loadActiveMedicine() async {
    try {
      final activeMedicine = await ActiveMedicineManager.getActiveMedicine();
      if (activeMedicine != null && mounted) {
        setState(() {
          takingMedications = 'Yes';
          currentMedicationsController.text = 
            '${activeMedicine['medicine']['name']} (${activeMedicine['medicine']['genericName']})';
        });
      }
    } catch (e) {
      print('Error loading active medicine: $e');
    }
  }

  Widget _buildSymptomsStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('What symptoms are you experiencing?'),
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
                decoration: InputDecoration(labelText: 'Specify other symptoms'),
              ),
            ),
          SizedBox(height: 20),
          _buildSectionTitle('How long have you been experiencing symptoms?'),
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
    );
  }

  Widget _buildMedicalHistoryStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Do you have any of the following health conditions?'),
          ...healthConditions.entries.map((entry) => CheckboxListTile(
            title: Text(entry.key),
            value: entry.value,
            onChanged: (bool? value) {
              setState(() => healthConditions[entry.key] = value!);
            },
          )).toList(),
          if (healthConditions['Other']!)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextFormField(
                controller: otherConditionsController,
                decoration: InputDecoration(labelText: 'Specify other conditions'),
              ),
            ),
          
          // Modify this condition to use userData
          if (widget.userData.sex == 'Female' && widget.userData.age >= 12) ...[
            SizedBox(height: 20),
            _buildSectionTitle('Are you pregnant?'),
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
              _buildSectionTitle('Which trimester are you in?'),
              ...['First', 'Second', 'Third'].map((t) => RadioListTile<String>(
                title: Text(t),
                value: t,
                groupValue: trimester,
                onChanged: (value) => setState(() => trimester = value!),
              )).toList(),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMedicationsStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Are you taking any medications right now?'),
          RadioListTile(
            title: Text('Yes'),
            value: 'Yes',
            groupValue: takingMedications,
            // Disable radio buttons if there's an active medicine
            onChanged: currentMedicationsController.text.isNotEmpty ? null : 
              (value) => setState(() => takingMedications = value.toString()),
          ),
          RadioListTile(
            title: Text('No'),
            value: 'No',
            groupValue: takingMedications,
            // Disable radio buttons if there's an active medicine
            onChanged: currentMedicationsController.text.isNotEmpty ? null :
              (value) => setState(() => takingMedications = value.toString()),
          ),
          if (takingMedications == 'Yes')
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                controller: currentMedicationsController,
                readOnly: true, // Always read-only since it's auto-filled
                decoration: InputDecoration(
                  labelText: 'Current medications',
                  helperText: currentMedicationsController.text.isNotEmpty 
                      ? 'Active medicine from reminders'
                      : null,
                  helperStyle: TextStyle(color: Colors.blue),
                ),
              ),
            ),
          SizedBox(height: 20),
          _buildSectionTitle('Do you have any allergies to medications?'),
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
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: TextFormField(
                controller: allergiesController,
                decoration: InputDecoration(labelText: 'Specify your allergies'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLifestyleStep() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildSectionTitle('Do you smoke?'),
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
          SizedBox(height: 20),
          _buildSectionTitle('Do you drink alcohol?'),
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
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Text(
        title,
        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
      ),
    );
  }

  void _completeQuestionnaire() {
    // Add validation before completing
    if (symptomsDuration == null ||
        takingMedications == null ||
        hasAllergies == null ||
        smoking == null ||
        drinking == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Please answer all questions')),
      );
      return;
    }

    Map<String, dynamic> processedSymptoms = {...symptoms};
    
    // Process other symptoms if specified
    if (symptoms['Other']! && otherSymptomsController.text.isNotEmpty) {
      String otherSymptom = otherSymptomsController.text.trim().toLowerCase();
      
      // Check for matching keywords in the mapping
      symptomToCategoryMap.forEach((symptom, categories) {
        if (otherSymptom.contains(symptom.toLowerCase())) {
          processedSymptoms[symptom] = true;
        }
      });
    }

    final questionnaireData = {
      'symptoms': processedSymptoms,
      'otherSymptoms': otherSymptomsController.text,
      'symptomsDuration': symptomsDuration,
      'healthConditions': healthConditions,
      'otherConditions': otherConditionsController.text,
      'takingMedications': takingMedications,
      'currentMedications': currentMedicationsController.text,
      'hasAllergies': hasAllergies,
      'allergies': allergiesController.text,
      'smoking': smoking,
      'drinking': drinking,
      // Modify this condition to use userData
      if (widget.userData.sex == 'Female' && widget.userData.age >= 12)
        'isPregnant': isPregnant ?? false,
      if (isPregnant == true)
        'pregnancyTrimester': trimester,
    };
    widget.onComplete(questionnaireData);
  }

  @override
  Widget build(BuildContext context) {
    final bool showPregnancyQuestions = widget.userData.sex == 'Female' && 
                                      widget.userData.age >= 12;
    return Form(
      key: _formKey,
      child: Theme(
        data: Theme.of(context).copyWith(
          colorScheme: ColorScheme.light(
            primary: Colors.blue.withOpacity(1),
          ),
          textTheme: Theme.of(context).textTheme.copyWith(
            titleMedium: TextStyle(
              color: Colors.blue.withOpacity(1),
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
        child: Column(
          children: [
            // Update medical disclaimer colors
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
                        'Medical Disclaimer',
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
                    'This questionnaire is intended for basic first aid guidance only. It does not replace professional medical advice or diagnosis. If symptoms continue or get worse, please seek immediate consultation with a qualified healthcare professional.',
                    style: TextStyle(
                      color: Colors.yellow.shade900,
                      height: 1.4,
                    ),
                    textAlign: TextAlign.justify,
                  ),
                ],
              ),
            ),
            Expanded(
              child: Stepper(
                currentStep: _currentStep,
                onStepContinue: () {
                  if (_currentStep < 3) {
                    setState(() => _currentStep += 1);
                  } else {
                    _completeQuestionnaire();
                  }
                },
                onStepCancel: () {
                  if (_currentStep > 0) {
                    setState(() => _currentStep -= 1);
                  }
                },
                steps: [
                  Step(
                    title: Text('Symptoms', 
                      style: TextStyle(
                        color: Colors.blue.withOpacity(1),
                        fontWeight: FontWeight.bold
                      )
                    ),
                    content: _buildSymptomsStep(),
                    isActive: _currentStep >= 0,
                  ),
                  Step(
                    title: Text('Medical History', 
                      style: TextStyle(
                        color: Colors.blue.withOpacity(1),
                        fontWeight: FontWeight.bold
                      )
                    ),
                    content: _buildMedicalHistoryStep(),
                    isActive: _currentStep >= 1,
                  ),
                  Step(
                    title: Text('Current Medications', 
                      style: TextStyle(
                        color: Colors.blue.withOpacity(1),
                        fontWeight: FontWeight.bold
                      )
                    ),
                    content: _buildMedicationsStep(),
                    isActive: _currentStep >= 2,
                  ),
                  Step(
                    title: Text('Lifestyle', 
                      style: TextStyle(
                        color: Colors.blue.withOpacity(1),
                        fontWeight: FontWeight.bold
                      )
                    ),
                    content: _buildLifestyleStep(),
                    isActive: _currentStep >= 3,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Update the bullet point color
  Widget _bulletPoint(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: Colors.yellow.shade900)),
          Expanded(
            child: Text(
              text,
              style: TextStyle(color: Colors.yellow.shade900),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    otherSymptomsController.dispose();
    otherConditionsController.dispose();
    currentMedicationsController.dispose();
    allergiesController.dispose();
    super.dispose();
  }
}
