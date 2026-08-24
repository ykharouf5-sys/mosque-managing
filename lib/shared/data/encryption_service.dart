import 'package:encrypt/encrypt.dart' as enc;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class EncryptionService {
  static const _keyStorageKey = 'local_enc_key';
  static final FlutterSecureStorage _storage = const FlutterSecureStorage();
  static enc.Encrypter? _encrypter;

  static Future<enc.Encrypter> get encrypter async {
    if (_encrypter != null) return _encrypter!;
    String? keyString = await _storage.read(key: _keyStorageKey);
    if (keyString == null) {
      final key = enc.Key.fromSecureRandom(32);
      keyString = key.base64;
      await _storage.write(key: _keyStorageKey, value: keyString);
    }
    _encrypter = enc.Encrypter(enc.AES(enc.Key.fromBase64(keyString)));
    return _encrypter!;
  }

  static Future<String> encrypt(String plain) async {
    final e = await encrypter;
    final iv = enc.IV.fromSecureRandom(16);
    final encrypted = e.encrypt(plain, iv: iv);
    return '${iv.base64}:${encrypted.base64}';
  }

  static Future<String> decrypt(String cipher) async {
    final e = await encrypter;
    final parts = cipher.split(':');
    if (parts.length != 2) return cipher;
    final iv = enc.IV.fromBase64(parts[0]);
    return e.decrypt64(parts[1], iv: iv);
  }
}
