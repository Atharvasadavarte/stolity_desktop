import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'dart:convert';

class AuthTokenService {
  static const _storage = FlutterSecureStorage();
  static const _tokenKey = 'auth_token';
  static const _keyNameKey = 'auth_token_key';

  // Save token and its sessionStorage key
  static Future<void> saveToken(String keyName, String token) async {
    await _storage.write(key: _tokenKey, value: token);
    await _storage.write(key: _keyNameKey, value: keyName);
  }

  // Load saved token and key name
  static Future<Map<String, String>?> loadTokenInfo() async {
    try {
      final token = await _storage.read(key: _tokenKey);
      final keyName = await _storage.read(key: _keyNameKey);
      if (token != null && keyName != null) {
       
        return {'key': keyName, 'token': token};
      }
    
    } catch (e) {
     
    }
    return null;
  }

  // Delete saved token
  static Future<void> clear() async {
    
    await _storage.delete(key: _tokenKey);
    await _storage.delete(key: _keyNameKey);
  }

  // Validate JWT expiration (exp claim in seconds)
  static bool isTokenValid(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return false;
      final payload = utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final map = jsonDecode(payload) as Map<String, dynamic>;
      final exp = map['exp'] as int;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final isValid = now < exp;
     
      return isValid;
    } catch (e) {
   
      return false;
    }
  }
}
