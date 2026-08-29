import 'dart:convert';
import 'dart:math';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class DatabaseKeyService {
  DatabaseKeyService._();

  static const _storage = FlutterSecureStorage();
  static const _keyName = 'aqua_sqlcipher_key_v1';

  static String _accountKeyName(String accountId) {
    final safeId = accountId.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    return 'aqua_sqlcipher_account_v1_$safeId';
  }

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

  static Future<String?> readForAccount(String accountId) =>
      _storage.read(key: _accountKeyName(accountId));

  static Future<String> getOrCreateForAccount(
    String accountId, {
    String? migrationKey,
  }) async {
    final existing = await readForAccount(accountId);
    if (existing != null && existing.isNotEmpty) return existing;

    final key = migrationKey ?? _generateKey();
    await _storage.write(key: _accountKeyName(accountId), value: key);
    return key;
  }

  static Future<void> deleteForAccount(String accountId) =>
      _storage.delete(key: _accountKeyName(accountId));

  static String _generateKey() {
    final random = Random.secure();
    final bytes = List<int>.generate(32, (_) => random.nextInt(256));
    return base64UrlEncode(bytes);
  }
}
