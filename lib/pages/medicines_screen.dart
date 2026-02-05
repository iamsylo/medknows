import 'package:flutter/material.dart';
import 'package:medknows/models/user_data.dart';  // Add this import
import 'package:medknows/utils/medicine_safety.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:open_file/open_file.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../utils/active_medicine_manager.dart';
import 'medicines.dart';
import '../widgets/take_medicine_form.dart';
import '../widgets/health_questionnaire.dart';
import '../utils/text_embeddings.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';

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
    _loadUserDataAndInitialize();  // Replace _loadUserData() with this
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowWarning();
    });
  }

  // Add this new method
  Future<void> _loadUserDataAndInitialize() async {
    try {
      setState(() => _isLoading = true);

      final prefs = await SharedPreferences.getInstance();
      final String? userId = prefs.getString('userId');

      if (userId != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final userData = UserData.fromMap({
            'id': userId,  // Add the ID explicitly
            ...userDoc.data() ?? {},
          });

          if (mounted) {
            setState(() {
              _userData = userData;
              _isLoading = false;
            });
          }
        }
      }
    } catch (e) {
      print('Error loading user data: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
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

  // Update to async method
  Future<List<Map<String, dynamic>>> getFilteredMedicines() async {
    if (_questionnaireData == null) return [];

    if (_questionnaireData!['symptomsDuration'] == 'More than 3 days') {
      return [];
    }

    try {
      final healthData = await _getHealthData();
      final activeMedicines = await _getAllActiveMedicines();
      final vocabulary = await _buildVocabulary();
      final userProfile = _createDetailedUserProfile(healthData!);
      final userEmbedding = TextEmbeddings.getTextEmbedding(userProfile, vocabulary);
      
      if (healthData == null) return [];

      List<Map<String, dynamic>> eligibleMedicines = [];

      for (var medicine in medicines) {
        // First check if medicine matches any symptoms
        if (_countMatchingSymptoms(medicine) == 0) continue;

        bool shouldExclude = false;
        
        // Check against active medicines
        for (var activeMedicine in activeMedicines) {
          if (_isSimilarMedicine(medicine, activeMedicine) ||
              MedicineSafety.hasIngredientOverlap(medicine, activeMedicine) ||
              _hasInteractionRisk(medicine, activeMedicine)) {
            shouldExclude = true;
            break;
          }
        }

        if (!shouldExclude && !_hasExclusionCriteria(medicine, healthData)) {
          double symptomScore = _calculateSymptomScore(medicine) * 0.40;
          double safetyScore = _calculateSafetyScore(medicine, healthData) * 0.35;
          double relevanceScore = _calculateRelevanceScore(medicine, userEmbedding, vocabulary) * 0.25;
          
          double totalScore = symptomScore + safetyScore + relevanceScore;
          
          var scoredMedicine = Map<String, dynamic>.from(medicine);
          scoredMedicine['totalScore'] = totalScore;
          scoredMedicine['symptomScore'] = symptomScore;
          scoredMedicine['safetyScore'] = safetyScore;
          scoredMedicine['relevanceScore'] = relevanceScore;
          
          eligibleMedicines.add(scoredMedicine);
        }
      }

      eligibleMedicines.sort((a, b) => (b['totalScore']).compareTo(a['totalScore']));
      return eligibleMedicines;

    } catch (e) {
      print('Error in getFilteredMedicines: $e');
      return [];
    }
  }

  Future<List<String>> _buildVocabulary() async {
    Set<String> vocabulary = {};
    
    // Add symptoms vocabulary
    symptomToCategoryMap.keys.forEach((symptom) {
      vocabulary.addAll(_processText(symptom));
    });
    
    // Add medicine-related terms
    for (var medicine in medicines) {
      vocabulary.addAll(_processText(medicine['description']));
      vocabulary.addAll(_processText(medicine['activeIngredient']));
      vocabulary.addAll(List<String>.from(medicine['categories']));
    }
    
    return vocabulary.toList();
  }

  String _createDetailedUserProfile(Map<String, dynamic> healthData) {
    List<String> profileElements = [];
    
    // Add current symptoms with emphasis
    Map<String, bool> symptoms = Map<String, bool>.from(_questionnaireData!['symptoms']);
    symptoms.forEach((symptom, hasSymptom) {
      if (hasSymptom) {
        profileElements.add(symptom);
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

    // Add vital signs context
    Map<String, dynamic> vitals = _questionnaireData!['vitals'];
    String temp = vitals['temperature'];
    if (double.tryParse(temp) != null) {
      double tempValue = double.parse(temp);
      if (tempValue > 37.5) profileElements.add('fever high_temperature');
    }

    // Add health conditions from initial health data
    Map<String, bool> conditions = Map<String, bool>.from(healthData['healthConditions']);
    conditions.forEach((condition, hasCondition) {
      if (hasCondition) profileElements.add('condition_$condition');
    });

    // Add current medications context
    if (healthData['takingMedications'] == 'Yes') {
      profileElements.add('taking_medications');
      profileElements.add(healthData['currentMedications']);
    }

    // Add allergies context
    if (healthData['hasAllergies'] == 'Yes') {
      profileElements.add('has_allergies');
      profileElements.add(healthData['allergies']);
    }

    // Add lifestyle factors
    if (healthData['smoking'] == 'Yes') profileElements.add('smoker smoking_risk');
    if (healthData['drinking'] == 'Yes') profileElements.add('alcohol alcohol_interaction_risk');

    // Add pregnancy context if applicable
    if (healthData['isPregnant'] == true) {
      profileElements.add('pregnant pregnancy_risk');
      profileElements.add(healthData['pregnancyTrimester']);
    }

    return profileElements.join(' ');
  }

  double _calculateSafetyScore(Map<String, dynamic> medicine, Map<String, dynamic> healthData) {
    double score = 1.0;
    
    // Check contraindications against health conditions
    Map<String, bool> conditions = Map<String, bool>.from(healthData['healthConditions']);
    for (var entry in conditions.entries) {
      if (entry.value && 
          medicine['contraindication'].toString().toLowerCase().contains(entry.key.toLowerCase())) {
        score -= 0.3;
      }
    }

    // Check medication interactions
    if (healthData['takingMedications'] == 'Yes') {
      String currentMeds = healthData['currentMedications'].toLowerCase();
      for (var interaction in medicine['interactions']) {
        if (interaction.toString().toLowerCase().contains(currentMeds)) {
          score -= 0.4;
        }
      }
    }

    // Check allergies
    if (healthData['hasAllergies'] == 'Yes') {
      String allergies = healthData['allergies'].toLowerCase();
      if (medicine['activeIngredient'].toString().toLowerCase().contains(allergies)) {
        score -= 0.5;
      }
    }

    // Pregnancy considerations
    if (healthData['isPregnant'] == true && 
        medicine['contraindication'].toString().toLowerCase().contains('pregnan')) {
      score -= 0.6;
    }

    return score.clamp(0.0, 1.0);
  }

  double _calculateSymptomScore(Map<String, dynamic> medicine) {
    int matchingSymptoms = _countMatchingSymptoms(medicine);
    int totalSymptoms = _questionnaireData!['symptoms']
        .values
        .where((v) => v == true)
        .length;

    return totalSymptoms > 0 ? matchingSymptoms / totalSymptoms : 0.0;
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

  List<String> _processText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((word) => word.isNotEmpty)
        .toList();
  }

  int _countMatchingSymptoms(Map<String, dynamic> medicine) {
    int count = 0;
    Map<String, bool> symptoms = Map<String, bool>.from(_questionnaireData!['symptoms']);
    List<String> medicineCategories = List<String>.from(medicine['categories'])
        .map((c) => c.toString().toLowerCase())
        .toList();
    List<String> medicineIndications = List<String>.from(medicine['indications'] ?? [])
        .map((i) => i.toString().toLowerCase())
        .toList();
    
    symptoms.forEach((symptom, hasSymptom) {
      if (hasSymptom && symptom != 'Other') {
        // First check exact symptom match in indications
        if (medicineIndications.any((indication) => 
            indication.toLowerCase().contains(symptom.toLowerCase()))) {
          count++;
          return;
        }

        // Then check category match through symptom map
        List<String>? categories = symptomToCategoryMap[symptom]
            ?.map((c) => c.toLowerCase())
            .toList();
        
        if (categories != null) {
          // Check if ANY of the medicine's categories match ANY of the symptom's categories
          if (medicineCategories.any((medicineCategory) =>
              categories.any((mappedCategory) => 
                mappedCategory.toLowerCase() == medicineCategory))) {
            count++;
          }
        }
      }
    });

    // Handle 'Other' symptoms
    if (symptoms['Other'] == true && 
        _questionnaireData!['otherSymptoms'].isNotEmpty) {
      String otherSymptom = _questionnaireData!['otherSymptoms'].toLowerCase();
      
      // First check direct indication match
      if (medicineIndications.any((indication) => 
          indication.contains(otherSymptom))) {
        count++;
      } else {
        // Then check through symptom map for known similar symptoms
        symptomToCategoryMap.forEach((knownSymptom, categories) {
          if (knownSymptom.toLowerCase().contains(otherSymptom) || 
              otherSymptom.contains(knownSymptom.toLowerCase())) {
            if (categories.any((category) => 
                medicineCategories.contains(category.toLowerCase()))) {
              count++;
            }
          }
        });
      }
    }

    return count;
  }

  void _handleComplete(Map<String, dynamic> data) {
    setState(() {
      // Ensure all required fields are present with default values
      _questionnaireData = {
        'vitals': {
          'temperature': data['vitals']?['temperature'] ?? '37.0',
          'temperatureUnit': data['vitals']?['temperatureUnit'] ?? '°C',
          'bloodPressure': data['vitals']?['bloodPressure'] ?? '120/80',
        },
        'symptoms': data['symptoms'] ?? {'Other': false},
        'otherSymptoms': data['otherSymptoms'] ?? '',
        'symptomsDuration': data['symptomsDuration'] ?? 'Less than a day',
        'healthConditions': data['healthConditions'] ?? {
          'diabetes': false,
          'high blood pressure': false,
          'heart disease': false,
          'asthma': false,
        },
        'takingMedications': data['takingMedications'] ?? 'No',
        'currentMedications': data['currentMedications'] ?? '',
        'hasAllergies': data['hasAllergies'] ?? 'No',
        'allergies': data['allergies'] ?? '',
        'smoking': data['smoking'] ?? 'No',
        'drinking': data['drinking'] ?? 'No',
        'isPregnant': data['isPregnant'] ?? false,
        'pregnancyTrimester': data['pregnancyTrimester'] ?? '',
      };
      _showMedicines = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: widget.showBackButton,
        title: Text(
          'Health Questionnaire',
          style: TextStyle(
            color: Colors.blue.withOpacity(1),
            fontWeight: FontWeight.bold,
            fontSize: 20,
          ),
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (!_showMedicines) {
      // Always show questionnaire even if userData is null
      return HealthQuestionnaire(
        onComplete: _handleComplete,
        initialData: widget.reminderData != null ? {
          'takingMedications': 'Yes',
          'currentMedications': '${widget.reminderData!['medicine']['name']} (${widget.reminderData!['medicine']['genericName']})',
        } : null,
        reminderData: widget.reminderData,
        userData: _userData ?? _getDefaultUserData(),  // Add fallback
      );
    }

    return _buildMedicinesList();
  }

  // Add this helper method for default user data
  UserData _getDefaultUserData() {
    return UserData(
      id: '',
      username: '',
      name: 'New User',
      birthdate: DateTime.now().toString(),
      age: 0,
      sex: 'Male',
      height: 0,
      weight: 0,
    );
  }

  Widget _buildMedicinesList() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: getFilteredMedicines(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Center(
            child: Text('Error loading recommendations: ${snapshot.error}'),
          );
        }

        final filteredMedicines = snapshot.data ?? [];
        bool showWarningMessage = _questionnaireData != null && 
                                _questionnaireData!['symptomsDuration'] == 'More than 3 days';

        if (filteredMedicines.isEmpty) {
          return _buildEmptyState(showWarningMessage);
        }

        // Group medicines by classification
        final groupedMedicines = _groupMedicinesByClassification(filteredMedicines);

        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildOTCDisclaimer(),
                SizedBox(height: 16),
                _buildHeader(),
                SizedBox(height: 8),
                _buildWarningMessage(),
                SizedBox(height: 16),
                // Add current medicine warning
                _buildCurrentMedicineWarning(),
                // Show classifications
                ...groupedMedicines.entries.map((entry) => 
                  Column(
                    children: [
                      _buildClassificationMedicines(entry.key, entry.value),
                      SizedBox(height: 8),
                    ],
                  ),
                ).toList(),
              ],
            ),
          ),
        );
      },
    );
  }

  Map<String, List<Map<String, dynamic>>> _groupMedicinesByClassification(List<Map<String, dynamic>> medicines) {
    Map<String, List<Map<String, dynamic>>> grouped = {};
    
    for (var medicine in medicines) {
      List<String> classifications = List<String>.from(medicine['classification']);
      for (var classification in classifications) {
        if (!grouped.containsKey(classification)) {
          grouped[classification] = [];
        }
        if (!grouped[classification]!.contains(medicine)) {
          grouped[classification]!.add(medicine);
        }
      }
    }

    // Sort medicines within each classification by total score
    grouped.forEach((classification, medicineList) {
      medicineList.sort((a, b) => (b['totalScore']).compareTo(a['totalScore']));
    });

    // Sort classifications alphabetically
    Map<String, List<Map<String, dynamic>>> sortedGrouped = Map.fromEntries(
      grouped.entries.toList()..sort((a, b) => a.key.compareTo(b.key))
    );

    return sortedGrouped;
  }

  Widget _buildClassificationMedicines(String classification, List<Map<String, dynamic>> medicines) {
    return ExpansionTile(
      title: Text(
        '$classification (${medicines.length})',
        style: TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.blue.shade700,
        ),
      ),
      children: medicines.map((medicine) => Card(
        margin: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        child: ListTile(
          leading: Image.asset(medicine['image'], width: 50, height: 50),
          title: Text(
            medicine['name'],
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
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
      )).toList(),
    );
  }

  Widget _buildEmptyState(bool showWarningMessage) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.warning, size: 48, color: Colors.red),
          SizedBox(height: 16),
          if (showWarningMessage) ...[
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
              'Please consult a healthcare professional immediately.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          ] else
            Text(
              'No suitable medications found for your symptoms.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
          SizedBox(height: 24),
          Container(
            width: 200, // Set fixed width for button
            child: ElevatedButton.icon(
              onPressed: _generateHealthReport,
              icon: Icon(Icons.picture_as_pdf, color: Colors.white),
              label: Text('Save Health Report', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red,
          padding: EdgeInsets.symmetric(vertical: 16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOTCDisclaimer() {
    return Container(
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
    );
  }

  Widget _buildHeader() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Recommended Medicines',
          style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
        TextButton(
          onPressed: () => setState(() => _showMedicines = false),
          child: Text('Edit Questionnaire'),
        ),
      ],
    );
  }

  Widget _buildWarningMessage() {
    return Container(
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
    );
  }

  Widget _buildCurrentMedicineWarning() {
    if (widget.reminderData == null) return SizedBox.shrink();

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue.shade50,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade700),
              SizedBox(width: 8),
              Text(
                'Current Medicine',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blue.shade700,
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Text(
            'You are currently taking ${widget.reminderData!['medicine']['name']} (${widget.reminderData!['medicine']['genericName']}). '
            'Only medicines that are safe to take together are shown below.',
            style: TextStyle(color: Colors.blue.shade700),
          ),
        ],
      ),
    );
  }

  void _showDosageForm(Map<String, dynamic> medicine) {
    bool needsSpecificTiming = true;
    String directions = medicine['directions of use'].toString().toLowerCase();
    
    if ((directions.contains('as needed') || 
         directions.contains('when needed')) &&
        !directions.contains('every') &&
        !directions.contains('times per day') &&
        !directions.contains('times daily') &&
        !directions.contains('hrs') &&
        !directions.contains('hours')) {
      needsSpecificTiming = false;
    }

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
  
  Future<Map<String, dynamic>?> _getHealthData() async {
    try {
      if (_userData == null) return null;
      
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_userData!.id)
          .get();

      if (!doc.exists) return null;

      final Map<String, dynamic> data = Map<String, dynamic>.from(doc.data()?['initialHealth'] ?? {});
      
      if (data['healthConditions'] != null) {
        data['healthConditions'] = Map<String, bool>.from(data['healthConditions']);
      }

      return data;
    } catch (e) {
      print('Error loading health data: $e');
      return null;
    }
  }

  Future<void> _generateHealthReport() async {
    try {
      final healthData = await _getHealthData();
      if (healthData == null) {
        throw Exception('Could not load health data');
      }

      final pdf = pw.Document(
        theme: pw.ThemeData.base(),
      );
    
      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4,
          margin: pw.EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          header: (context) {
            return pw.Container(
              padding: pw.EdgeInsets.only(bottom: 10),
              child: pw.Column(
                children: [
                  pw.Text(
                    'HEALTH ASSESSMENT REPORT',
                    style: pw.TextStyle(fontSize: 18),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.SizedBox(height: 2),
                  pw.Text(
                    DateTime.now().toString().split('.')[0],
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                    textAlign: pw.TextAlign.center,
                  ),
                  pw.Divider(thickness: 1),
                ],
              ),
            );
          },
          build: (context) => [
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    children: [
                      _buildPDFSection('Personal Information', [
                        _buildPDFRow('Name', _userData!.name),
                        _buildPDFRow('Age/Sex', '${_userData!.age}y/${_userData!.sex}'),
                        _buildPDFRow('Height', '${_userData!.height} cm'),
                        _buildPDFRow('Weight', '${_userData!.weight} kg'),
                      ]),

                      _buildPDFSection('Vital Signs', [
                        _buildPDFRow('Temperature', 
                          '${_questionnaireData!['vitals']['temperature']} ${_questionnaireData!['vitals']['temperatureUnit'].toString().replaceAll('°', '')}'),
                        _buildPDFRow('Blood Pressure', 
                          '${_questionnaireData!['vitals']['bloodPressure']} mmHg'),
                      ]),

                      _buildMedicalHistorySection(healthData),

                      _buildPDFSection('Current Medications', [
                        _buildPDFRow('Status', healthData['takingMedications'] ?? 'No'),
                        if (healthData['takingMedications'] == 'Yes')
                          _buildPDFRow('List', healthData['currentMedications'] ?? ''),
                      ]),
                    ],
                  ),
                ),

                pw.SizedBox(width: 10),

                pw.Expanded(
                  child: pw.Column(
                    children: [
                      _buildPDFSection('Allergies', [
                        _buildPDFRow('Status', healthData['hasAllergies'] ?? 'No'),
                        if (healthData['hasAllergies'] == 'Yes')
                          _buildPDFRow('List', healthData['allergies'] ?? ''),
                      ]),

                      _buildPDFSection('Lifestyle', [
                        _buildPDFRow('Smoking', healthData['smoking'] ?? 'No'),
                        _buildPDFRow('Alcohol', healthData['drinking'] ?? 'No'),
                      ]),

                      _buildPDFSection('Current Symptoms', [
                        ...(_questionnaireData!['symptoms'] as Map<String, dynamic>)
                            .entries
                            .where((e) => e.value == true)
                            .map((e) => _buildPDFRow('Symptom', e.key)),
                        if (_questionnaireData!['symptoms']['Other'] == true)
                          _buildPDFRow('Other', _questionnaireData!['otherSymptoms']),
                        _buildPDFRow('Duration', _questionnaireData!['symptomsDuration']),
                      ]),

                      if (_userData!.sex == 'Female' && 
                          _userData!.age >= 12 && 
                          healthData['isPregnant'] == true)
                        _buildPDFSection('Pregnancy', [
                          _buildPDFRow('Status', 'Pregnant'),
                          _buildPDFRow('Trimester', healthData['pregnancyTrimester'] ?? ''),
                        ]),
                    ],
                  ),
                ),
              ],
            ),
          ],
          footer: (context) {
            return pw.Container(
              decoration: pw.BoxDecoration(
                border: pw.Border(top: pw.BorderSide(color: PdfColors.grey300))
              ),
              padding: pw.EdgeInsets.only(top: 5),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'OTiCuRe Health Report',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                  pw.Text(
                    'Page ${context.pageNumber} of ${context.pagesCount}',
                    style: pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                  ),
                ],
              ),
            );
          },
        ),
      );

      final dir = await getApplicationDocumentsDirectory();
      final file = File('${dir.path}/health_report_${DateTime.now().millisecondsSinceEpoch}.pdf');
      await file.writeAsBytes(await pdf.save());
      await OpenFile.open(file.path);

    } catch (e) {
      print('Error generating health report: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating report: $e')),
        );
      }
    }
  }

  pw.Widget _buildPDFSection(String title, List<pw.Widget> content) {
    return pw.Container(
      margin: pw.EdgeInsets.only(bottom: 10),
      padding: pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300),
        borderRadius: pw.BorderRadius.circular(4),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(
              fontSize: 10,
              color: PdfColors.blue800,
            ),
          ),
          pw.Divider(color: PdfColors.grey300),
          ...content,
        ],
      ),
    );
  }

  pw.Widget _buildPDFRow(String label, String value) {
    return pw.Container(
      padding: pw.EdgeInsets.symmetric(vertical: 1),
      child: pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Container(
            width: 50,
            child: pw.Text(
              label,
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.grey700,
              ),
            ),
          ),
          pw.Expanded(
            child: pw.Text(
              value,
              style: pw.TextStyle(
                fontSize: 8,
                color: PdfColors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  pw.Widget _buildMedicalHistorySection(Map<String, dynamic> healthData) {
    final List<pw.Widget> content = [];
    
    try {
      if (healthData.containsKey('healthConditions')) {
        final conditions = Map<String, bool>.from(healthData['healthConditions']);
        
        conditions.forEach((condition, value) {
          if (value == true) {
            content.add(_buildPDFRow('Condition', condition));
          }
        });
      }

      if (content.isEmpty) {
        content.add(_buildPDFRow('Status', 'No known conditions'));
      }

    } catch (e) {
      print('Error building medical history section: $e');
      content.add(_buildPDFRow('Error', 'Could not load medical history'));
    }

    return _buildPDFSection('Medical History', content);
  }

  // Add this method to get all active medicines
  Future<List<Map<String, dynamic>>> _getAllActiveMedicines() async {
    List<Map<String, dynamic>> activeMedicines = [];
    try {
      // Get current active medicine from storage
      final activeMedicine = await ActiveMedicineManager.getActiveMedicine();
      if (activeMedicine != null) {
        activeMedicines.add(activeMedicine['medicine']);
      }

      // Get active medicines from Firebase
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getString('userId');
      
      if (userId != null) {
        final reminders = await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('reminders')
            .get();

        for (var doc in reminders.docs) {
          final medicine = doc.data()['medicine'] as Map<String, dynamic>;
          if (!activeMedicines.any((m) => _isSimilarMedicine(m, medicine))) {
            activeMedicines.add(medicine);
          }
        }
      }

      return activeMedicines;
    } catch (e) {
      print('Error getting active medicines: $e');
      return [];
    }
  }

  // Add this method to check medicine similarity
  bool _isSimilarMedicine(Map<String, dynamic> med1, Map<String, dynamic> med2) {
    // Check exact matches
    if (med1['name'] == med2['name'] || 
        med1['genericName'] == med2['genericName']) {
      return true;
    }

    // Normalize names for comparison
    String name1 = med1['name'].toString().toLowerCase();
    String name2 = med2['name'].toString().toLowerCase();
    String generic1 = med1['genericName'].toString().toLowerCase();
    String generic2 = med2['genericName'].toString().toLowerCase();

    // Check for substring matches
    if (name1.contains(generic2) || name2.contains(generic1) ||
        generic1.contains(name2) || generic2.contains(name1)) {
      return true;
    }

    return false;
  }

  // Add this method to check interaction risks
  bool _hasInteractionRisk(Map<String, dynamic> med1, Map<String, dynamic> med2) {
    List<String> interactions1 = List<String>.from(med1['interactions'] ?? [])
        .map((i) => i.toString().toLowerCase())
        .toList();
    
    List<String> interactions2 = List<String>.from(med2['interactions'] ?? [])
        .map((i) => i.toString().toLowerCase())
        .toList();

    // Check if med2's name or generic name appears in med1's interactions
    String med2Name = med2['name'].toString().toLowerCase();
    String med2Generic = med2['genericName'].toString().toLowerCase();

    for (var interaction in interactions1) {
      if (interaction.contains(med2Name) || interaction.contains(med2Generic)) {
        return true;
      }
    }

    // Check if med1's name or generic name appears in med2's interactions
    String med1Name = med1['name'].toString().toLowerCase();
    String med1Generic = med1['genericName'].toString().toLowerCase();

    for (var interaction in interactions2) {
      if (interaction.contains(med1Name) || interaction.contains(med1Generic)) {
        return true;
      }
    }

    return false;
  }

  // Add this method to check exclusion criteria
  bool _hasExclusionCriteria(Map<String, dynamic> medicine, Map<String, dynamic> healthData) {
    // Check health conditions
    Map<String, bool> conditions = Map<String, bool>.from(healthData['healthConditions']);
    String contraindications = medicine['contraindication'].toString().toLowerCase();
    
    for (var entry in conditions.entries) {
      if (entry.value && contraindications.contains(entry.key.toLowerCase())) {
        return true;
      }
    }

    // Check allergies
    if (healthData['hasAllergies'] == 'Yes') {
      String allergies = healthData['allergies'].toString().toLowerCase();
      String ingredients = medicine['activeIngredient'].toString().toLowerCase();
      
      if (allergies.split(',').any((allergy) => 
          ingredients.contains(allergy.trim()))) {
        return true;
      }
    }

    // Check pregnancy
    if (healthData['isPregnant'] == true && 
        contraindications.contains('pregnan')) {
      return true;
    }

    return false;
  }

  // Add this method to get matching symptoms
  String _getMatchingSymptoms(Map<String, dynamic> medicine) {
    Set<String> matchingSymptoms = {};
    Map<String, bool> symptoms = Map<String, bool>.from(_questionnaireData!['symptoms']);
    List<String> medicineCategories = List<String>.from(medicine['categories'])
        .map((c) => c.toString().toLowerCase())
        .toList();
    List<String> medicineIndications = List<String>.from(medicine['indications'] ?? [])
        .map((i) => i.toString().toLowerCase())
        .toList();

    symptoms.forEach((symptom, hasSymptom) {
      if (hasSymptom && symptom != 'Other') {
        // First check exact symptom match in indications
        if (medicineIndications.any((indication) => 
            indication.contains(symptom.toLowerCase()))) {
          matchingSymptoms.add(symptom);
          return;
        }

        // Then check category match through symptom map
        List<String>? categories = symptomToCategoryMap[symptom]
            ?.map((c) => c.toLowerCase())
            .toList();
        
        if (categories != null) {
          // Check if ANY of the medicine's categories match ANY of the symptom's categories
          if (medicineCategories.any((medicineCategory) =>
              categories.any((mappedCategory) => 
                mappedCategory.toLowerCase() == medicineCategory))) {
            matchingSymptoms.add(symptom);
          }
        }
      }
    });

    if (symptoms['Other'] == true && 
        _questionnaireData!['otherSymptoms'].isNotEmpty) {
      String otherSymptom = _questionnaireData!['otherSymptoms'].toLowerCase();
      
      // First check direct indication match
      if (medicineIndications.any((indication) => 
          indication.contains(otherSymptom))) {
        matchingSymptoms.add(otherSymptom);
      } else {
        // Then check through symptom map for known similar symptoms
        bool foundMatch = false;
        symptomToCategoryMap.forEach((knownSymptom, categories) {
          if (!foundMatch && 
              knownSymptom.toLowerCase().contains(otherSymptom) || 
              otherSymptom.contains(knownSymptom.toLowerCase())) {
            if (categories.any((category) => 
                medicineCategories.contains(category.toLowerCase()))) {
              matchingSymptoms.add(knownSymptom);
              foundMatch = true;
            }
          }
        });
      }
    }

    return matchingSymptoms.isEmpty ? 'No matching symptoms' 
                                  : matchingSymptoms.join(', ');
  }

  @override
  void dispose() {
    super.dispose();
  }
}