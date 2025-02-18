import 'text_embeddings.dart';

class MedicineRecommender {
  static List<Map<String, dynamic>> getRecommendedMedicines(
    List<Map<String, dynamic>> medicines,
    String selectedCategory,
    String searchQuery
  ) {
    // Create vocabulary from all medicines
    List<String> vocabulary = [];
    for (var medicine in medicines) {
      vocabulary.addAll(medicine['description'].toString().toLowerCase().split(RegExp(r'[^\w]+')));
      vocabulary.addAll((medicine['categories'] as List).map((c) => c.toString().toLowerCase()));
      vocabulary.addAll(medicine['activeIngredient'].toString().toLowerCase().split(RegExp(r'[,\s]+')));
    }
    vocabulary = vocabulary.toSet().toList();

    // Create category profile
    String categoryProfile = selectedCategory;
    Map<String, double> categoryEmbedding = TextEmbeddings.getTextEmbedding(categoryProfile, vocabulary);

    // Score medicines
    List<Map<String, dynamic>> scoredMedicines = medicines.map((medicine) {
      // First check category match
      if (!medicine['categories'].contains(selectedCategory) && selectedCategory != 'All') {
        return {'medicine': medicine, 'score': -1.0};
      }

      // Create medicine profile
      String medicineProfile = '''
        ${medicine['description']}
        ${(medicine['categories'] as List).join(' ')}
        ${medicine['activeIngredient']}
      ''';

      Map<String, double> medicineEmbedding = TextEmbeddings.getTextEmbedding(
        medicineProfile, 
        vocabulary
      );

      double similarityScore = TextEmbeddings.cosineSimilarity(
        categoryEmbedding, 
        medicineEmbedding
      );

      // Check search query if present
      if (searchQuery.isNotEmpty) {
        bool matchesSearch = medicine['name'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
                           medicine['genericName'].toString().toLowerCase().contains(searchQuery.toLowerCase()) ||
                           medicine['description'].toString().toLowerCase().contains(searchQuery.toLowerCase());
        if (!matchesSearch) {
          return {'medicine': medicine, 'score': -1.0};
        }
      }

      return {
        'medicine': medicine,
        'score': similarityScore,
      };
    }).toList();

    // Filter and sort medicines
    var validMedicines = scoredMedicines
        .where((item) => item['score'] > 0)
        .toList()
      ..sort((a, b) => b['score'].compareTo(a['score']));

    return validMedicines.map((item) => item['medicine'] as Map<String, dynamic>).toList();
  }
}
