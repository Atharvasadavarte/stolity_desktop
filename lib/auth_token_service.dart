import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class AuthTokenService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _keyNameKey = 'auth_token_key';

  static Future<void> saveToken(String keyName, String token) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _keyNameKey, value: keyName);
  }

  static Future<Map<String, String>?> loadTokenInfo() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final keyName = await _storage.read(key: _keyNameKey);
      if (token != null && keyName != null) {
        return {'key': keyName, 'token': token};
      }
    } catch (e) {}
    return null;
  }

  static Future<void> clear() async {
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _keyNameKey);
  }

  static bool isTokenValid(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final expRaw = map['exp'];
      if (expRaw == null) return false;
      final exp = (expRaw is num) ? expRaw.toInt() : int.tryParse(expRaw.toString());
      if (exp == null) return false;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      const skewSeconds = 30;
      return now + skewSeconds < exp;
    } catch (_) {
      return false;
    }
  }
}
