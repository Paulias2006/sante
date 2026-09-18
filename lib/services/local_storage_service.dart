import 'package:hive_flutter/hive_flutter.dart';

class LocalStorageService {
  static const String _patientQrBox = 'patient_qr';
  static const String _userDataBox = 'user_data';
  static const String _syncBox = 'sync_data';
  static const String _dossierBox = 'patient_dossier';

  static Future<void> init() async {
    await Hive.initFlutter();
    await Hive.openBox(_patientQrBox);
    await Hive.openBox(_userDataBox);
    await Hive.openBox(_syncBox);
    await Hive.openBox(_dossierBox);
  }

  // Patient QR Code (accessible offline)
  static Future<void> savePatientQrCode(
    String patientId,
    String qrToken,
  ) async {
    final box = Hive.box(_patientQrBox);
    await box.put(patientId, qrToken);
  }

  static String? getPatientQrCode(String patientId) {
    final box = Hive.box(_patientQrBox);
    return box.get(patientId);
  }

  // User data cache
  static Future<void> saveUserData(Map<String, dynamic> userData) async {
    final box = Hive.box(_userDataBox);
    await box.put('user', Map<String, dynamic>.from(userData));
  }

  static Map<String, dynamic>? getUserData() {
    final box = Hive.box(_userDataBox);
    final value = box.get('user');

    if (value is! Map) {
      return null;
    }

    return Map<String, dynamic>.from(value);
  }

  static Future<void> clearUserData() async {
    final box = Hive.box(_userDataBox);
    await box.clear();
  }

  // Sync metadata
  static Future<void> updateLastSync(String key, DateTime timestamp) async {
    final box = Hive.box(_syncBox);
    await box.put(key, timestamp.toIso8601String());
  }

  static DateTime? getLastSync(String key) {
    final box = Hive.box(_syncBox);
    final value = box.get(key);
    if (value != null) {
      return DateTime.parse(value);
    }
    return null;
  }

  static Future<void> clearAll() async {
    await Hive.box(_patientQrBox).clear();
    await Hive.box(_userDataBox).clear();
    await Hive.box(_syncBox).clear();
    await Hive.box(_dossierBox).clear();
  }

  static Future<void> savePatientDossier(
    String patientId,
    Map<String, dynamic> dossier,
  ) async {
    await Hive.box(_dossierBox).put(patientId, dossier);
    await updateLastSync('patient_$patientId', DateTime.now());
  }

  static Map<String, dynamic>? getPatientDossier(String patientId) {
    final value = Hive.box(_dossierBox).get(patientId);
    return value is Map ? Map<String, dynamic>.from(value) : null;
  }
}
