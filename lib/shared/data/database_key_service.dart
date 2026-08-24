import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DatabaseKeyService {
  DatabaseKeyService._();

  static const _storage = FlutterSecureStorage();
  static const _keyName = 'aqua_sqlcipher_key_v1';

  static Future<String?> read() => _storage.read(key: _keyName);

  static Future<String> getOrCreate() async {
    final existing = await read();
    if (existing != null && existing.isNotEmpty) return existing;

    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    final key = base64UrlEncode(bytes);
    await _storage.write(key: _keyName, value: key);
    return key;
  }
}
