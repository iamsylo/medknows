import 'package:flutter/services.dart';

class MedicineLabels {
  static List<String>? _labels;

  static List<String> getLabels() {
    if (_labels == null) {
      // Initialize with default labels
      _labels = [
        "Advil",
        "Alaxan FR",
        "Ascof Forte",
        "Bioflu",
        "Biogesic",
        "Buscopan Venus",
        "Coldzep",
        "Diatabs",
        "Flanax",
        "Kremil-S",
        "Kremil-S Advance",
        "Medicol Advance 200",
        "Myracof",
        "Neozep Z+ Forte",
        "No Drowse Decolgen",
        "Sinecod Forte",
        "Solmux Advance",
        "Tempra Forte",
        "Tuseran Forte"
      ];
      print('Labels initialized with default values');
    }
    return _labels!;
  }

  static Future<void> initializeLabels() async {
    try {
      String labelsData = await rootBundle.loadString('assets/labels.txt');
      _labels = labelsData.trim().split('\n');
    } catch (e) {
      print('Error loading labels: $e');
      _labels = getLabels(); // Use default labels if file loading fails
    }
  }
}
