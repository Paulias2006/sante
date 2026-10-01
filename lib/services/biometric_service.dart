import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:sante/config/app_constants.dart';

class BiometricService {
  BiometricService._();

  static final BiometricService instance = BiometricService._();
  final LocalAuthentication _authentication = LocalAuthentication();

  Future<bool> isEnabled() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(AppConstants.keyBiometricEnabled) ?? false;
  }

  Future<bool> isSupported() async {
    try {
      final supported = await _authentication.isDeviceSupported();
      final available = await _authentication.canCheckBiometrics;
      return supported && available;
    } catch (_) {
      return false;
    }
  }

  Future<bool> authenticate() async {
    try {
      return await _authentication.authenticate(
        localizedReason: 'Confirmez votre identité pour ouvrir SantéTogo',
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<bool> setEnabled(bool enabled) async {
    final preferences = await SharedPreferences.getInstance();
    if (!enabled) {
      await preferences.setBool(AppConstants.keyBiometricEnabled, false);
      return true;
    }

    if (!await isSupported()) return false;
    final authenticated = await authenticate();
    if (!authenticated) return false;
    await preferences.setBool(AppConstants.keyBiometricEnabled, true);
    return true;
  }
}
