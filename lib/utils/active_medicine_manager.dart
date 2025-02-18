import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class ActiveMedicineManager {
  static const String _key = 'active_medicine';

  static Future<Map<String, dynamic>?> getActiveMedicine() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? jsonStr = prefs.getString(_key);
      if (jsonStr != null && jsonStr.isNotEmpty) {
        return json.decode(jsonStr) as Map<String, dynamic>;
      }
      return null;
    } catch (e) {
      print('Error getting active medicine: $e');
      return null;
    }
  }

  static Future<void> setActiveMedicine(Map<String, dynamic> medicine) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_key, json.encode(medicine));
    } catch (e) {
      print('Error setting active medicine: $e');
    }
  }

  static Future<void> clearActiveMedicine() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_key);
    } catch (e) {
      print('Error clearing active medicine: $e');
    }
  }
}
