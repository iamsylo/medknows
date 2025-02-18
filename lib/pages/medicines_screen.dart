import 'package:flutter/material.dart';
import 'package:medknows/models/user_data.dart';  // Add this import
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../utils/active_medicine_manager.dart';
import 'medicines.dart';
import '../widgets/take_medicine_form.dart';
import '../widgets/health_questionnaire.dart';
import '../utils/text_embeddings.dart';

class MedicinesScreen extends StatefulWidget {
  final bool showBackButton;
  final Map<String, dynamic>? reminderData;  // Add this

  MedicinesScreen({
    this.showBackButton = false,
    this.reminderData,  // Add this
  });

  @override
  _MedicinesScreenState createState() => _MedicinesScreenState();
}

class _MedicinesScreenState extends State<MedicinesScreen> {
  // Add the mapping here
  final Map<String, List<String>> symptomToCategoryMap = {
    'Headache': ['Pain Reliever', 'Fever'],
    'Fever': ['Fever', 'Pain Reliever'],
    'Cough': ['Cough', 'Respiratory'],
    'Muscle Pain': ['Pain Reliever', 'Anti-inflammatory'],
    'Colds': ['Cold', 'Flu'],
    'Heartburn': ['Antacid'],
    'Stomach pain': ['Abdominal Pain', 'Anti-flatulent', 'Antacid'],
    'Stomach ache': ['Antacid', 'Anti-flatulent'], // Added this line
    'Gas pain': ['Antacid', 'Anti-flatulent'],
    'Acid reflux': ['Antacid'],
    'Indigestion': ['Antacid'],
    'Bloating': ['Anti-flatulent', 'Antacid'],
    'Sour stomach': ['Antacid'],
    'Diarrhea': ['Antidiarrheal'],
    'Body aches': ['Pain Reliever', 'Anti-inflammatory'],
    'Flu symptoms': ['Cold', 'Flu', 'Fever'],
    'Toothache': ['Pain Reliever'],
    'Joint pain': ['Pain Reliever', 'Anti-inflammatory'],
    'Back pain': ['Pain Reliever', 'Anti-inflammatory'],
    'Menstrual pain': ['Menstrual Pain', 'Abdominal Pain'],
    'Menstrual cramps': ['Menstrual Pain', 'Abdominal Pain'],
    'Period pain': ['Menstrual Pain', 'Abdominal Pain'],
    'Stomach cramps': ['Abdominal Pain'],
    'Abdominal pain': ['Abdominal Pain'],
    'Abdominal cramps': ['Abdominal Pain'],
    'Neck pain': ['Pain Reliever', 'Anti-inflammatory'],
    'Ear ache': ['Pain Reliever'],
    'Arthritis pain': ['Pain Reliever', 'Anti-inflammatory'],
    'Dental pain': ['Pain Reliever'],
    'Gum pain': ['Pain Reliever'],
    'Flu': ['Cold', 'Flu', 'Fever'],
    'Influenza': ['Cold', 'Flu', 'Fever'],
    'Cold symptoms': ['Cold', 'Flu'],
    'Sore throat': ['Cold', 'Flu', 'Fever', 'Pain Reliever'],
    'Throat pain': ['Cold', 'Flu', 'Fever', 'Pain Reliever'],
  };

  bool _showMedicines = false;
  Map<String, dynamic>? _questionnaireData;
  Map<String, dynamic>? _selectedMedicine;
  UserData? _userData;  // Add this
  bool _isLoading = true;  // Add this

  @override
  void initState() {
    super.initState();
    _loadUserData();
    // Use addPostFrameCallback to ensure context is available
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowWarning();
    });
  }

  // Add this new method
  Future<void> _checkAndShowWarning() async {
    try {
      if (widget.reminderData != null) {
        _showActiveWarning(widget.reminderData!);
      } else {
        final activeMedicine = await ActiveMedicineManager.getActiveMedicine();
        if (activeMedicine != null && mounted) {
          _showActiveWarning(activeMedicine);
        }
      }
    } catch (e) {
      print('Error showing active medicine warning: $e');
    }
  }

  // Add this method
  Future<void> _loadUserData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('userId');

      if (userId != null) {
        final userData = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userData.exists) {
          setState(() {
            _userData = UserData.fromMap(userData.data()!);
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
      setState(() => _isLoading = false);
    }
  }

  // Update the _showActiveWarning method
  void _showActiveWarning(Map<String, dynamic> medicineData) {
    if (!mounted) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
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
                        medicineData['medicine']['image'],
                        width: 40,
                        height: 40,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              medicineData['medicine']['name'],
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              medicineData['genericName'],
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
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pop();
                },
              ),
              TextButton(
                child: Text(
                  'Continue Anyway',
                  style: TextStyle(color: Colors.orange[900]),
                ),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        );
      },
    );
  }

  // Combined method for checking active medicine
  Future<bool> _checkActiveMedicine() async {
    // First check for reminderData from widget
    if (widget.reminderData != null) {
      if (!mounted) return false;
      
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
                        widget.reminderData!['medicine']['image'],
                        width: 40,
                        height: 40,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.reminderData!['medicine']['name'],
                              style: TextStyle(fontWeight: FontWeight.bold),
                            ),
                            Text(
                              widget.reminderData!['medicine']['genericName'],
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
                onPressed: () {
                  Navigator.of(context).pop(false);
                  Navigator.of(context).pop();
                },
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
      return shouldContinue ?? false;
    }

    // Then check for active medicine in storage
    try {
      final activeMedicine = await ActiveMedicineManager.getActiveMedicine();
      if (activeMedicine != null && mounted) {
        return await showDialog<bool>(
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
                  onPressed: () {
                    Navigator.of(context).pop(false);
                    Navigator.of(context).pop();
                  },
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
        ) ?? false;
      }
      return true;
    } catch (e) {
      print('Error checking active medicine: $e');
      return true;
    }
  }

  List<Map<String, dynamic>> getFilteredMedicines() {
    if (_questionnaireData == null) return [];

    // First check for active medication interactions
    if (_questionnaireData!['takingMedications'] == 'Yes' && 
        _questionnaireData!['currentMedications'].isNotEmpty) {
      String currentMed = _questionnaireData!['currentMedications'].toLowerCase();
      
      // Filter out medicines that could interact with active medicine
      return medicines.where((medicine) {
        // Extract medicine name from the format "MedicineName (GenericName)"
        String activeMedName = currentMed.split('(')[0].trim().toLowerCase();
        
        // Check if this medicine is in the interactions list
        bool hasInteraction = medicine['interactions'].any((interaction) =>
          interaction.toString().toLowerCase().contains(activeMedName));
        
        // Include medicine only if it doesn't interact with active medicine
        return !hasInteraction && 
               !_hasExclusionCriteria(medicine) && 
               _hasMatchingSymptoms(medicine);
      }).toList();
    }

    // Check symptom duration first
    if (_questionnaireData!['symptomsDuration'] == 'More than 3 days') {
      return []; // Return empty list to trigger the warning message
    }

    // Create vocabulary from medicine descriptions and categories
    List<String> vocabulary = [];
    for (var medicine in medicines) {
      vocabulary.addAll(_processText(medicine['description']));
      vocabulary.addAll(_processText(medicine['contraindication']));
      vocabulary.addAll((medicine['categories'] as List).map((c) => c.toString().toLowerCase()));
      vocabulary.addAll(_processText(medicine['activeIngredient']));
      vocabulary.addAll((medicine['interactions'] as List).map((i) => i.toString().toLowerCase()));
    }
    vocabulary = vocabulary.toSet().toList();

    String userProfile = _createDetailedUserProfile();
    Map<String, double> userEmbedding = TextEmbeddings.getTextEmbedding(userProfile, vocabulary);

    List<Map<String, dynamic>> scoredMedicines = medicines.map((medicine) {
      // Check if medicine is for flu when "flu" is mentioned in other symptoms
      bool isFluMedicine = false;
      if (_questionnaireData!['symptoms']['Other'] == true) {
        String otherSymptoms = _questionnaireData!['otherSymptoms'].toLowerCase();
        if ((otherSymptoms.contains('flu') || otherSymptoms.contains('influenza')) &&
            (medicine['categories'] as List).any((category) => 
                ['Cold', 'Flu', 'Fever'].contains(category.toString()))) {
          isFluMedicine = true;
        }
      }

      // If it's a flu medicine or matches other criteria
      if (isFluMedicine || (!_hasExclusionCriteria(medicine) && _hasMatchingSymptoms(medicine))) {
        double symptomScore = _calculateSymptomScore(medicine);
        double safetyScore = _calculateSafetyScore(medicine);
        double relevanceScore = _calculateRelevanceScore(medicine, userEmbedding, vocabulary);

        return {
          'medicine': medicine,
          'score': (symptomScore * 0.4) + (safetyScore * 0.35) + (relevanceScore * 0.25),
        };
      }

      return {'medicine': medicine, 'score': -1.0};
    }).toList();

    // Filter and sort medicines
    var validMedicines = scoredMedicines
        .where((item) => item['score'] > 0)
        .toList()
      ..sort((a, b) => b['score'].compareTo(a['score']));

    return validMedicines.map((item) => item['medicine'] as Map<String, dynamic>).toList();
  }

  List<String> _processText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
  }

  String _createDetailedUserProfile() {
    List<String> profileElements = [];
    
    // Add symptoms with emphasis
    Map<String, bool> symptoms = Map<String, bool>.from(_questionnaireData!['symptoms']);
    symptoms.forEach((symptom, hasSymptom) {
      if (hasSymptom) {
        profileElements.add(symptom);
        // Add related terms from symptom categories
        List<String>? categories = symptomToCategoryMap[symptom];
        if (categories != null) {
          profileElements.addAll(categories);
        }
      }
    });

    // Add other symptoms
    if (symptoms['Other'] == true) {
      profileElements.add(_questionnaireData!['otherSymptoms']);
    }

    // Add health conditions
    Map<String, bool> conditions = Map<String, bool>.from(_questionnaireData!['healthConditions']);
    conditions.forEach((condition, hasCondition) {
      if (hasCondition) profileElements.add(condition);
    });

    // Add current medications
    if (_questionnaireData!['takingMedications'] == 'Yes') {
      profileElements.add(_questionnaireData!['currentMedications']);
    }

    // Add allergies
    if (_questionnaireData!['hasAllergies'] == 'Yes') {
      profileElements.add(_questionnaireData!['allergies']);
    }

    // Add lifestyle factors
    if (_questionnaireData!['drinking'] == 'Yes') {
      profileElements.add('alcohol interaction risk');
    }

    return profileElements.join(' ');
  }

  bool _hasMatchingSymptoms(Map<String, dynamic> medicine) {
    int matchCount = _countMatchingSymptoms(medicine);
    return matchCount > 0;
  }

  bool _hasExclusionCriteria(Map<String, dynamic> medicine) {
    // Check critical exclusions
    String contraindications = medicine['contraindication'].toString().toLowerCase();
    String ingredients = medicine['activeIngredient'].toString().toLowerCase();
    List<dynamic> interactions = medicine['interactions'] as List;

    // Enhanced health conditions check with detailed warnings
    Map<String, bool> conditions = Map<String, bool>.from(_questionnaireData!['healthConditions']);
    for (var entry in conditions.entries) {
      if (entry.value) {
        String condition = entry.key.toLowerCase();
        
        // Check specific conditions with strict criteria
        switch (condition) {
          case 'diabetes':
            if (contraindications.contains('diabetes') ||
                contraindications.contains('blood sugar') ||
                contraindications.contains('glucose') ||
                contraindications.contains('g6pd')) {
              return true;
            }
            break;
            
          case 'high blood pressure':
            if (contraindications.contains('hypertension') ||
                contraindications.contains('high blood pressure') ||
                contraindications.contains('blood pressure') ||
                ingredients.contains('phenylephrine') ||
                ingredients.contains('pseudoephedrine')) {
              return true;
            }
            break;
            
          case 'heart disease':
            if (contraindications.contains('heart') ||
                contraindications.contains('cardiac') ||
                contraindications.contains('cardiovascular') ||
                medicine['interactions'].any((i) => 
                  i.toString().toLowerCase().contains('blood pressure') ||
                  i.toString().toLowerCase().contains('heart'))) {
              return true;
            }
            break;
            
          case 'asthma':
            if (contraindications.contains('asthma') ||
                contraindications.contains('respiratory') ||
                contraindications.contains('breathing')) {
              return true;
            }
            break;
        }

        // General contraindication check
        if (_hasContraindication(condition, contraindications)) {
          return true;
        }
      }
    }

    // Pregnancy check
    if (_questionnaireData!['isPregnant'] == true) {
      if (contraindications.contains('pregnan') ||
          contraindications.contains('gestation') ||
          contraindications.contains('fetus')) {
        return true;
      }
      
      // Special handling for pregnancy trimesters
      String trimester = _questionnaireData!['pregnancyTrimester'].toLowerCase();
      if (contraindications.contains(trimester) ||
          (trimester == 'third' && contraindications.contains('third trimester'))) {
        return true;
      }
    }

    // Rest of the existing checks
    // ...existing allergy checks...
    // ...existing alcohol checks...
    // ...existing medication interaction checks...

    return false;
  }

  double _calculateSymptomScore(Map<String, dynamic> medicine) {
    int matchingSymptoms = _countMatchingSymptoms(medicine);
    int totalSymptoms = _questionnaireData!['symptoms']
        .values
        .where((v) => v == true)
        .length;

    return totalSymptoms > 0 ? matchingSymptoms / totalSymptoms : 0.0;
  }

  double _calculateSafetyScore(Map<String, dynamic> medicine) {
    double score = 1.0;
    
    // Deduct points for potential risks
    if (medicine['contraindication'].toString().toLowerCase().contains('caution')) {
      score -= 0.1;
    }
    
    if (medicine['interactions'].length > 10) {
      score -= 0.1; // More interactions = higher risk
    }

    // Consider age restrictions
    int ageRestriction = int.parse(medicine['ageRestriction']);
    if (_userData?.age != null && _userData!.age < ageRestriction + 3) {
      score -= 0.2; // Closer to age restriction = lower score
    }

    return score.clamp(0.0, 1.0);
  }

  double _calculateRelevanceScore(Map<String, dynamic> medicine, 
      Map<String, double> userEmbedding, List<String> vocabulary) {
    String medicineProfile = '''
      ${medicine['description']}
      ${medicine['categories'].join(' ')}
      ${medicine['activeIngredient']}
    ''';

    Map<String, double> medicineEmbedding = TextEmbeddings.getTextEmbedding(
      medicineProfile, 
      vocabulary
    );

    return TextEmbeddings.cosineSimilarity(userEmbedding, medicineEmbedding);
  }

  bool _shouldExcludeMedicine(Map<String, dynamic> medicine) {
    // Check health conditions
    Map<String, bool> conditions = Map<String, bool>.from(_questionnaireData!['healthConditions']);
    for (var entry in conditions.entries) {
      if (entry.value) {
        String condition = entry.key.toLowerCase();
        String contraindications = medicine['contraindication'].toString().toLowerCase();
        
        if (_hasContraindication(condition, contraindications)) {
          return true;
        }
      }
    }

    // Check allergies
    if (_questionnaireData!['hasAllergies'] == 'Yes') {
      List<String> allergyTerms = _questionnaireData!['allergies']
          .toLowerCase()
          .split(',')
          .map((term) => term.trim())
          .where((term) => term.isNotEmpty)
          .toList();

      String medicineIngredients = '''
        ${medicine['activeIngredient']} 
        ${medicine['genericName']}
      '''.toLowerCase();

      if (allergyTerms.any((allergy) => medicineIngredients.contains(allergy))) {
        return true;
      }
    }

    // Check alcohol interactions
    if (_questionnaireData!['drinking'] == 'Yes') {
      bool hasAlcoholInteraction = medicine['interactions']?.any((interaction) =>
        interaction.toString().toLowerCase().contains('alcohol')
      ) ?? false;

      if (hasAlcoholInteraction) {
        return true;
      }
    }

    return false;
  }

  // Add this method after the _shouldExcludeMedicine method
  bool _hasContraindication(String condition, String contraindications) {
    // Common condition keywords mapping
    Map<String, List<String>> conditionKeywords = {
      'high blood pressure': ['hypertension', 'high blood pressure', 'blood pressure'],
      'diabetes': ['diabetes', 'blood sugar', 'glucose', 'G6PD'],
      'heart disease': ['heart', 'cardiac', 'cardiovascular'],
      'asthma': ['asthma', 'respiratory', 'breathing', 'breathing difficulties'],
      'liver disease': ['liver', 'hepatic'],
      'kidney disease': ['kidney', 'renal'],
      'allergies': ['allergy', 'allergic'],
      'pregnant': ['pregnancy', 'pregnant', 'gestation', 'fetus', 'childbearing'],
      'ulcer': ['ulcer', 'gastric', 'stomach bleeding'],
      'bleeding disorder': ['bleeding', 'blood clotting', 'coagulation'],
    };

    // Get keywords for the condition
    List<String> keywords = conditionKeywords[condition] ?? [condition];

    // Check if any keyword matches in contraindications
    return keywords.any((keyword) => contraindications.contains(keyword));
  }

  int _countMatchingSymptoms(Map<String, dynamic> medicine) {
    int count = 0;
    Map<String, bool> symptoms = Map<String, bool>.from(_questionnaireData!['symptoms']);
    
    symptoms.forEach((symptom, hasSymptom) {
      if (hasSymptom && symptom != 'Other') {
        List<String>? categories = symptomToCategoryMap[symptom];
        if (categories != null && 
            medicine['categories'].any((category) => 
              categories.any((c) => c.toLowerCase() == category.toString().toLowerCase()))) {
          count++;
        }
      }
    });

    return count;
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: widget.showBackButton,
          title: Text(
            'Health Questionnaire',
            style: TextStyle(
              color:  Colors.blue.withOpacity(1),
              fontWeight: FontWeight.bold,
              fontSize: 20,  // Added for better visibility
            ),
          ),
        ),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        title: Text(
          'Health Questionnaire',
          style: TextStyle(
            color:  Colors.blue.withOpacity(1),
            fontWeight: FontWeight.bold,
            fontSize: 20,  // Added for better visibility
          ),
        ),
      ),
      body: !_showMedicines
        ? _userData == null
          ? Center(child: Text('Unable to load user data'))
          : HealthQuestionnaire(
              onComplete: (data) {
                setState(() {
                  _questionnaireData = data;
                  _showMedicines = true;
                });
              },
              initialData: widget.reminderData != null ? {
                'takingMedications': 'Yes',
                'currentMedications': '${widget.reminderData!['medicine']['name']} (${widget.reminderData!['medicine']['genericName']})',
              } : null,
              reminderData: widget.reminderData,  // Add this line
              userData: _userData!,
            )
        : _buildMedicinesList(),
    );
  }

  Widget _buildMedicinesList() {
    List<Map<String, dynamic>> filteredMedicines = getFilteredMedicines();
    
    return SingleChildScrollView(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Add OTC disclaimer
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
              color: Colors.yellow.shade50,
              borderRadius: BorderRadius.circular(8),
              ),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                'Over-the-Counter Medicines Only',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.yellow.shade900,
                ),
                ),
                SizedBox(height: 4),
                Text(
                'These recommendations are limited to OTC medicines. If symptoms persist and for serious conditions, please consult a healthcare professional.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.yellow.shade900,
                ),
                ),
              ],
              ),
            ),
            SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
              Text('Recommended Medicines', 
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              TextButton(
                onPressed: () => setState(() => _showMedicines = false),
                child: Text('Edit Questionnaire'),
              ),
              ],
            ),
            SizedBox(height: 8),
            Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
              color: Colors.yellow.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.yellow.shade700),
              ),
              child: Row(
              children: [
                Icon(Icons.warning_amber, color: Colors.yellow.shade900),
                SizedBox(width: 8),
                Expanded(
                child: Text(
                  'Please choose and take only ONE medicine from the recommendations to avoid potential drug interactions.',
                  style: TextStyle(
                  color: Colors.yellow.shade900,
                  fontWeight: FontWeight.w500,
                  ),
                ),
                ),
              ],
              ),
            ),
            SizedBox(height: 16),
            if (filteredMedicines.isEmpty)
              Center(
                child: Column(
                  children: [
                    Icon(Icons.warning, size: 48, color: Colors.red),
                    SizedBox(height: 16),
                    if (_questionnaireData!['symptomsDuration'] == 'More than 3 days')
                      Column(
                        children: [
                          Text(
                            'Symptoms persisting for more than 3 days',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            'Please consult a healthcare professional immediately. Prolonged symptoms may indicate a condition that requires medical attention.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      )
                    else if (_hasHealthConditions())
                      Column(
                        children: [
                          Text(
                            'Based on your health conditions:',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.red,
                            ),
                          ),
                          SizedBox(height: 8),
                          ..._getHealthConditionsWarnings(),
                          SizedBox(height: 16),
                          Text(
                            'Please consult a healthcare professional for appropriate medication.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16),
                          ),
                        ],
                      )
                    else
                      Text(
                        'No suitable medicines found based on your health profile.\nPlease consult a healthcare professional.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                  ],
                ),
              )
            else
              ListView.builder(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                itemCount: filteredMedicines.length,
                itemBuilder: (context, index) {
                  final medicine = filteredMedicines[index];
                  return Card(
                    margin: EdgeInsets.only(bottom: 12),
                    child: ListTile(
                      leading: Image.asset(medicine['image'], width: 50, height: 50),
                      title: Text(medicine['name']),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(medicine['genericName']),
                          Text(
                            'Matches your symptoms: ${_getMatchingSymptoms(medicine)}',
                            style: TextStyle(fontSize: 12, color: Colors.green),
                          ),
                        ],
                      ),
                      onTap: () => _showDosageForm(medicine),
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  bool _hasHealthConditions() {
    return (_questionnaireData?['healthConditions'] as Map<String, bool>?)
        ?.values
        ?.any((condition) => condition) ?? false;
  }

  List<Widget> _getHealthConditionsWarnings() {
    List<Widget> warnings = [];
    Map<String, bool> conditions = Map<String, bool>.from(_questionnaireData!['healthConditions']);
    
    conditions.forEach((condition, hasCondition) {
      if (hasCondition) {
        warnings.add(
          Padding(
            padding: EdgeInsets.symmetric(vertical: 4, horizontal: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.warning_amber, color: Colors.orange, size: 20),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _getConditionWarning(condition),
                    style: TextStyle(color: Colors.red[700]),
                  ),
                ),
              ],
            ),
          ),
        );
      }
    });
    
    return warnings;
  }

  String _getConditionWarning(String condition) {
    switch (condition.toLowerCase()) {
      case 'diabetes':
        return 'Some medications may affect blood sugar levels';
      case 'high blood pressure':
        return 'Many cold and pain medications can increase blood pressure';
      case 'heart disease':
        return 'Several common medications may affect heart conditions';
      case 'asthma':
        return 'Some pain relievers may trigger asthma symptoms';
      default:
        return '$condition may affect medication choices';
    }
  }

  String _getMatchingSymptoms(Map<String, dynamic> medicine) {
    Set<String> matchingSymptoms = {};
    Map<String, bool> symptoms = Map<String, bool>.from(_questionnaireData!['symptoms']);

    // Handle regular symptoms first
    symptoms.entries
        .where((e) => e.value == true && e.key != 'Other')
        .forEach((e) {
          List<String> mappedCategories = symptomToCategoryMap[e.key] ?? [];
          if (medicine['categories'].any((category) => 
              mappedCategories.any((mapped) => 
                mapped.toLowerCase() == category.toString().toLowerCase()
              ))) {
            matchingSymptoms.add(e.key);
          }
        });

    // Enhanced handling of "Other" symptoms
    if (symptoms['Other'] == true && _questionnaireData!['otherSymptoms'].isNotEmpty) {
      String otherSymptom = _questionnaireData!['otherSymptoms'].toLowerCase();
      
      // First try exact matches
      symptomToCategoryMap.forEach((symptom, categories) {
        if (otherSymptom.contains(symptom.toLowerCase())) {
          if (categories.any((category) => 
            medicine['categories'].any((medCategory) => 
              medCategory.toString().toLowerCase() == category.toLowerCase()
            ))) {
            matchingSymptoms.add(symptom);
          }
        }
      });

      // Special handling for flu/influenza keywords
      if (otherSymptom.contains('flu') || otherSymptom.contains('influenza')) {
        if (medicine['categories'].any((category) => 
            ['Cold', 'Flu', 'Fever'].contains(category.toString()))) {
          matchingSymptoms.add('Flu symptoms');
        }
      }
    }

    return matchingSymptoms.isEmpty ? 'No matching symptoms' : matchingSymptoms.join(', ');
  }

  bool _hasCheckedSymptoms() => _questionnaireData!['symptoms'].values.any((checked) => checked);

  void _showDosageForm(Map<String, dynamic> medicine) {
    // Update the needsSpecificTiming logic
    bool needsSpecificTiming = true;
    String directions = medicine['directions of use'].toString().toLowerCase();
    
    // Only set to false if it's purely "as needed" without specific timing
    if ((directions.contains('as needed') || 
         directions.contains('when needed')) &&
        !directions.contains('every') &&
        !directions.contains('times per day') &&
        !directions.contains('times daily') &&
        !directions.contains('hrs') &&
        !directions.contains('hours')) {
      needsSpecificTiming = false;
    }

    // Also respect explicit setting if present
    if (medicine.containsKey('needsSpecificTiming')) {
      needsSpecificTiming = medicine['needsSpecificTiming'];
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            color: Colors.amber.shade50,
            child: Text(
              needsSpecificTiming 
                ? 'This medicine needs to be taken at specific intervals.'
                : 'Take this medicine as needed according to instructions.',
              style: TextStyle(
                color: Colors.amber.shade900,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
            ),
            child: TakeMedicineForm(
              selectedMedicine: medicine,
              needsSpecificTiming: needsSpecificTiming,
              onDosageChecked: (dosage) {},
            ),
          ),
        ],
      ),
    );
    setState(() => _selectedMedicine = medicine);
  }
  
  @override
  void dispose() {
    super.dispose();
  }
}