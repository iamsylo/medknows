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
}
