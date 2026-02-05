import 'package:cloud_firestore/cloud_firestore.dart';

class MedicineSafety {
  static Future<List<String>> getRecentlyTakenMedicines(String userId) async {
    final now = DateTime.now();
    final timeWindow = now.subtract(Duration(hours: 24));
    
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('history')
        .where('status', isEqualTo: 'taken')
        .where('takenAt', isGreaterThanOrEqualTo: timeWindow)
        .get();

    return querySnapshot.docs
        .map((doc) => (doc.data()['medicine']['name'] as String))
        .toList();
  }

  static Future<Map<String, double>> getTotalActiveIngredientsIn24Hours(String userId) async {
    final now = DateTime.now();
    final timeWindow = now.subtract(Duration(hours: 24));
    
    final querySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('history')
        .where('status', isEqualTo: 'taken')
        .where('takenAt', isGreaterThanOrEqualTo: timeWindow)
        .get();

    Map<String, double> totalIngredients = {};
    
    for (var doc in querySnapshot.docs) {
      final data = doc.data();
      final medicine = data['medicine'] as Map<String, dynamic>;
      final double dosage = (data['dosage'] as num).toDouble();
      
      // Split active ingredients if there are multiple
      final activeIngredients = medicine['activeIngredient'].toString().split(',');
      
      // If multiple ingredients, assume equal distribution of dosage
      final dosagePerIngredient = dosage / activeIngredients.length;
      
      for (var ingredient in activeIngredients) {
        final cleanIngredient = ingredient.trim().toLowerCase();
        totalIngredients[cleanIngredient] = 
            (totalIngredients[cleanIngredient] ?? 0) + dosagePerIngredient;
      }
    }
    
    return totalIngredients;
  }

  static Future<List<String>> checkTotalActiveDosage(
    Map<String, dynamic> newMedicine,
    double newDosage,
    Map<String, double> currentTotals,
    List<Map<String, dynamic>> medicinesList
  ) {
    List<String> warnings = [];
    final activeIngredients = newMedicine['activeIngredient'].toString().split(',');
    final dosagePerIngredient = newDosage / activeIngredients.length;

    for (var ingredient in activeIngredients) {
      final cleanIngredient = ingredient.trim().toLowerCase();
      final currentTotal = currentTotals[cleanIngredient] ?? 0;
      final newTotal = currentTotal + dosagePerIngredient;

      // Find max daily dosage for this ingredient
      double maxDosage = 0;
      String? ingredientName;

      for (var med in medicinesList) {
        if (med['activeIngredient'].toString().toLowerCase().contains(cleanIngredient)) {
          ingredientName = med['genericName'].toString().split('+')
              .firstWhere((name) => name.trim().toLowerCase().contains(cleanIngredient))
              .trim();
          
          final maxDosageStr = med['directions of use'].toString()
              .toLowerCase()
              .replaceAll('maximum', '')
              .replaceAll('max', '')
              .replaceAll('of', '')
              .replaceAll('per 24 hours', '')
              .replaceAll('daily', '')
              .trim();
          
          RegExp(r'(\d+)').allMatches(maxDosageStr).forEach((match) {
            maxDosage = double.parse(match.group(1)!);
          });
          
          break;
        }
      }

      if (maxDosage > 0 && newTotal > maxDosage) {
        warnings.add(
          'Taking this medicine would exceed the maximum daily dosage for $ingredientName '
          '($maxDosage mg per 24 hours).\n'
          'Total $ingredientName in last 24 hours: ${currentTotal.toStringAsFixed(1)} mg\n'
          'New dose would add: ${dosagePerIngredient.toStringAsFixed(1)} mg'
        );
      }
    }

    return Future.value(warnings);
  }

  static List<String> checkInteractions(
    Map<String, dynamic> newMedicine,
    List<String> recentMedicines,
    List<Map<String, dynamic>> medicinesList
  ) {
    List<String> warnings = [];
    final List<String> newMedicineInteractions = 
        List<String>.from(newMedicine['interactions'] ?? []);
    
    for (String recentMed in recentMedicines) {
      // Find the recent medicine in the medicines list
      final recentMedData = medicinesList.firstWhere(
        (m) => m['name'] == recentMed,
        orElse: () => {'interactions': []},
      );
      
      // Check for interactions
      final List<String> recentMedInteractions = 
          List<String>.from(recentMedData['interactions'] ?? []);
      
      // Check if new medicine's active ingredient is in recent medicine's interactions
      if (recentMedInteractions.contains(
          newMedicine['activeIngredient'].toString().toLowerCase())) {
        warnings.add(
          '${newMedicine['name']} may interact with recently taken $recentMed'
        );
      }
      
      // Check if recent medicine's active ingredient is in new medicine's interactions
      if (newMedicineInteractions.contains(
          recentMedData['activeIngredient'].toString().toLowerCase())) {
        warnings.add(
          '${newMedicine['name']} may interact with recently taken $recentMed'
        );
      }
    }
    
    return warnings;
  }

  static bool canTakeTogether(
    Map<String, dynamic> currentMedicine, 
    Map<String, dynamic> newMedicine,
  ) {
    print('\nChecking if can take together:');
    print('Current: ${currentMedicine['name']} (${currentMedicine['genericName']})');
    print('New: ${newMedicine['name']} (${newMedicine['genericName']})');

    // 1. Check for same medicine
    if (_isSameMedicine(currentMedicine, newMedicine)) {
      print('Same medicine detected');
      return false;
    }

    // 2. Check for same or related ingredients
    if (hasIngredientOverlap(currentMedicine, newMedicine)) { // Changed from _hasIngredientOverlap
      print('Ingredient overlap detected');
      return false;
    }

    // 3. Check for interactions (both ways)
    if (_hasInteractions(currentMedicine, newMedicine) || 
        _hasInteractions(newMedicine, currentMedicine)) {
      print('Interaction detected');
      return false;
    }

    print('Medicines can be taken together');
    return true;
  }

  // Helper methods for cleaner logic
  static bool _isSameMedicine(Map<String, dynamic> med1, Map<String, dynamic> med2) {
    String name1 = med1['name'].toString().toLowerCase();
    String name2 = med2['name'].toString().toLowerCase();
    String generic1 = med1['genericName'].toString().toLowerCase();
    String generic2 = med2['genericName'].toString().toLowerCase();

    return name1 == name2 ||
           generic1 == generic2 ||
           name1.contains(generic2) ||
           name2.contains(generic1) ||
           generic1.contains(generic2) ||
           generic2.contains(generic1);
  }

  static bool hasIngredientOverlap(Map<String, dynamic> med1, Map<String, dynamic> med2) {
    // Get normalized ingredients for both medicines
    Set<String> ingredients1 = _getNormalizedIngredients(med1);
    Set<String> ingredients2 = _getNormalizedIngredients(med2);

    // Debug logging
    print('Checking ingredients:');
    print('Med1 (${med1['name']}): $ingredients1');
    print('Med2 (${med2['name']}): $ingredients2');

    // Check each ingredient combination
    for (var ing1 in ingredients1) {
      for (var ing2 in ingredients2) {
        // Check for exact match, substring match, or related ingredients
        if (ing1 == ing2 || 
            ing1.contains(ing2) || 
            ing2.contains(ing1) ||
            _areIngredientsRelated(ing1, ing2)) {
          print('Ingredient overlap found: $ing1 - $ing2');
          return true;
        }
      }
    }
    return false;
  }

  static Set<String> _getNormalizedIngredients(Map<String, dynamic> medicine) {
    // Get ingredients from both activeIngredient and genericName
    Set<String> ingredients = {};
    
    // Add active ingredients
    ingredients.addAll(
      medicine['activeIngredient']
          .toString()
          .toLowerCase()
          .split(',')
          .map((e) => normalizeIngredientName(e.trim()))
    );

    // Add generic name components (for compound medicines)
    ingredients.addAll(
      medicine['genericName']
          .toString()
          .toLowerCase()
          .split('+')
          .map((e) => normalizeIngredientName(e.trim()))
    );

    return ingredients;
  }

  static bool _hasInteractions(Map<String, dynamic> med1, Map<String, dynamic> med2) {
    List<String> interactions = List<String>.from(med1['interactions'] ?? [])
        .map((i) => normalizeIngredientName(i.toString().toLowerCase()))
        .toList();

    // Check against medicine name, generic name, and ingredients
    String nameToCheck = med2['name'].toString().toLowerCase();
    String genericToCheck = med2['genericName'].toString().toLowerCase();
    Set<String> ingredientsToCheck = med2['activeIngredient']
        .toString()
        .toLowerCase()
        .split(',')
        .map<String>((e) => normalizeIngredientName(e.trim()))
        .toSet();

    return interactions.any((interaction) =>
        nameToCheck.contains(interaction) ||
        genericToCheck.contains(interaction) ||
        ingredientsToCheck.any((ingredient) =>
            ingredient.contains(interaction) ||
            interaction.contains(ingredient)));
  }

  // Add this helper method
  static bool _areIngredientsRelated(String ing1, String ing2) {
    // Define groups of related ingredients
    final relatedGroups = [
      // NSAIDs group
      {
        'ibuprofen', 'naproxen', 'diclofenac', 'meloxicam', 'aspirin',
        'ketoprofen', 'ketorolac', 'indomethacin', 'celecoxib'
      },
      // Paracetamol group
      {
        'paracetamol', 'acetaminophen', 'apap', 'tylenol', 'biogesic',
        'tempra', 'calpol'
      },
      // Decongestants group
      {
        'phenylephrine', 'pseudoephedrine', 'oxymetazoline',
        'phenylpropanolamine'
      },
      // Antihistamines group
      {
        'chlorphenamine', 'diphenhydramine', 'cetirizine',
        'loratadine', 'fexofenadine'
      },
      // Cough suppressants group
      {
        'dextromethorphan', 'codeine', 'butamirate'
      }
    ];

    // Check if ingredients belong to the same group
    return relatedGroups.any((group) => 
        group.contains(normalizeIngredientName(ing1)) && 
        group.contains(normalizeIngredientName(ing2)));
  }

  // Changed from _normalizeIngredientName to normalizeIngredientName (made public)
  static String normalizeIngredientName(String name) {
    // Common variations and brand names mapping
    final variations = {
      'ibuprofen': [
        'ibu',
        'brufen',
        'advil',
        'motrin',
        'nurofen',
        'medicol',
        'flanax',
        'alaxan',  // Add since it contains ibuprofen
      ],
      'paracetamol': [
        'acetaminophen',
        'tylenol',
        'panadol',
        'biogesic',
        'tempra',
        'alaxan',  // Add since it contains paracetamol
        'calpol',
      ],
      'phenylephrine': [
        'bioflu',
        'neozep',
        'decolgen',
      ],
      // Add more normalized mappings
    };

    name = name.toLowerCase().trim();

    // First check if the name contains any of the base ingredients
    for (var base in variations.keys) {
      if (name.contains(base)) {
        return base;
      }
    }

    // Then check for brand name variations
    for (var base in variations.keys) {
      if (variations[base]!.any((variant) => name.contains(variant))) {
        return base;
      }
    }

    // Handle compound medicines by splitting on common separators
    final parts = name.split(RegExp(r'[,+&/]'));
    for (var part in parts) {
      part = part.trim();
      for (var base in variations.keys) {
        if (variations[base]!.any((variant) => part.contains(variant))) {
          return base;
        }
      }
    }

    return name;
  }
}
