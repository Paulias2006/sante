import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:sante/services/local_storage_service.dart';

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await Hive.initFlutter();
    await Hive.deleteBoxFromDisk('user_data');
    await Hive.openBox('user_data');
  });

  tearDown(() async {
    final box = Hive.box('user_data');
    await box.clear();
  });

  test('getUserData returns a String-keyed map for auth restore', () async {
    final box = Hive.box('user_data');
    await box.put('user', {
      'id': 'u1',
      'email': 'test@example.com',
      'role': 'patient',
      'nom': 'Doe',
      'prenom': 'John',
    });

    final userData = LocalStorageService.getUserData();

    expect(userData, isNotNull);
    expect(userData, isA<Map<String, dynamic>>());
    expect(userData!['email'], 'test@example.com');
  });
}
