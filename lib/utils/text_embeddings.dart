import 'dart:math';

class TextEmbeddings {
  static Map<String, double> getTextEmbedding(String text, List<String> vocabulary) {
    // Handle empty text or vocabulary
    if (text.isEmpty || vocabulary.isEmpty) {
      return {};
    }

    Map<String, double> embedding = {};
    
    // Clean and split text into words
    List<String> words = text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '') // Remove punctuation
        .split(RegExp(r'\s+')) // Split on whitespace
        .where((word) => word.isNotEmpty)
        .toList();

    if (words.isEmpty) return {};

    // Calculate term frequency (TF)
    for (String word in words) {
      embedding.update(word, (value) => value + 1, ifAbsent: () => 1);
    }

    // Calculate IDF and normalize
    int documentLength = words.length;
    double vocabularySize = vocabulary.length.toDouble();

    embedding.forEach((word, count) {
      // Calculate how many vocabulary words contain this word
      double docsWithTerm = vocabulary
          .where((vocabWord) => vocabWord.contains(word))
          .length
          .toDouble();
      
      // Prevent division by zero
      if (docsWithTerm == 0) docsWithTerm = 1;

      // TF-IDF calculation
      double tf = count / documentLength;
      double idf = log(vocabularySize / docsWithTerm);
      
      embedding[word] = tf * idf;
    });

    return embedding;
  }

  static double cosineSimilarity(Map<String, double> vec1, Map<String, double> vec2) {
    // Handle empty vectors
    if (vec1.isEmpty || vec2.isEmpty) return 0.0;

    double dotProduct = 0.0;
    double norm1 = 0.0;
    double norm2 = 0.0;

    // Get all unique words
    Set<String> allWords = {...vec1.keys, ...vec2.keys};

    // Calculate dot product and norms
    for (String word in allWords) {
      double val1 = vec1[word] ?? 0.0;
      double val2 = vec2[word] ?? 0.0;
      
      dotProduct += val1 * val2;
      norm1 += val1 * val1;
      norm2 += val2 * val2;
    }

    // Prevent division by zero
    if (norm1 == 0 || norm2 == 0) return 0.0;

    // Calculate final similarity
    return dotProduct / (sqrt(norm1) * sqrt(norm2));
  }

  // Helper method to preprocess text
  static String preprocessText(String text) {
    return text
        .toLowerCase()
        .replaceAll(RegExp(r'[^\w\s]'), '')
        .trim();
  }
}
