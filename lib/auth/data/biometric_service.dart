import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  static final LocalAuthentication _auth = LocalAuthentication();
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static const _enabledKey = 'biometric_enabled';

  static Future<bool> isAvailable() async {
    try {
      return await _auth.canCheckBiometrics || await _auth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  static Future<bool> authenticate() async {
    try {
      return await _auth.authenticate(
        localizedReason: 'الرجاء المصادقة لفتح التطبيق',
        biometricOnly: false,
        persistAcrossBackgrounding: true,
      );
    } catch (_) {
      return false;
    }
  }

  static Future<bool> isEnabled() async {
    final val = await _storage.read(key: _enabledKey);
    return val == 'true';
  }

  static Future<void> setEnabled(bool value) async {
    await _storage.write(key: _enabledKey, value: value.toString());
  }
}
