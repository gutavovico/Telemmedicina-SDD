import 'dart:convert';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SecureStorageService {
  static final SecureStorageService _instance =
      SecureStorageService._internal();
  factory SecureStorageService() => _instance;
  SecureStorageService._internal();

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    webOptions: WebOptions(
      dbName: 'telemedicina_db',
    ),
  );

  static const String _keyAccessToken = 'access_token';
  static const String _keyRefreshToken = 'refresh_token';
  static const String _keyTenantId = 'tenant_id';
  static const String _keyUser = 'user_data';
  static const String _keyRememberMe = 'remember_me';

  // Save Tenant ID
  Future<void> saveTenantId(String tenantId) async {
    await _secureStorage.write(key: _keyTenantId, value: tenantId);
  }

  // Get Tenant ID
  Future<String?> getTenantId() async {
    return _secureStorage.read(key: _keyTenantId);
  }

  Future<void> clearTenantId() async {
    await _secureStorage.delete(key: _keyTenantId);
  }

  // Save JWT tokens
  Future<void> saveTokens({
    required String accessToken,
    String? refreshToken,
  }) async {
    await _secureStorage.write(key: _keyAccessToken, value: accessToken);
    if (refreshToken != null) {
      await _secureStorage.write(key: _keyRefreshToken, value: refreshToken);
    }
    // Also save to SharedPreferences for web (more reliable)
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccessToken, accessToken);
      if (refreshToken != null) {
        await prefs.setString(_keyRefreshToken, refreshToken);
      }
    }
  }

  // Get Access Token
  Future<String?> getAccessToken() async {
    // On web, prioritize SharedPreferences (more reliable than flutter_secure_storage web)
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_keyAccessToken);
      if (token != null && token.isNotEmpty) return token;
    }

    try {
      final token = await _secureStorage.read(key: _keyAccessToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyAccessToken);
  }

  // Get Refresh Token
  Future<String?> getRefreshToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_keyRefreshToken);
      if (token != null && token.isNotEmpty) return token;
    }

    try {
      final token = await _secureStorage.read(key: _keyRefreshToken);
      if (token != null && token.isNotEmpty) return token;
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyRefreshToken);
  }

  // Save User Profile
  Future<void> saveUser(Map<String, dynamic> userData) async {
    final userJson = jsonEncode(userData);
    try {
      await _secureStorage.write(key: _keyUser, value: userJson);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUser, userJson);
    }
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyUser, userJson);
    }
  }

  // Get Saved User Profile
  Future<Map<String, dynamic>?> getUser() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final userJson = prefs.getString(_keyUser);
      if (userJson != null) {
        return jsonDecode(userJson) as Map<String, dynamic>;
      }
    }

    try {
      final userJson = await _secureStorage.read(key: _keyUser);
      if (userJson != null) {
        return jsonDecode(userJson) as Map<String, dynamic>;
      }
    } catch (_) {}

    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyUser);
    if (userJson != null) {
      return jsonDecode(userJson) as Map<String, dynamic>;
    }
    return null;
  }

  // Set Remember Me preference
  Future<void> setRememberMe(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyRememberMe, value);
  }

  Future<bool> getRememberMe() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyRememberMe) ?? true;
  }

  // Clear Session Data
  Future<void> clearSession() async {
    await _secureStorage.delete(key: _keyAccessToken);
    await _secureStorage.delete(key: _keyRefreshToken);
    await _secureStorage.delete(key: _keyTenantId);
    await _secureStorage.delete(key: _keyUser);

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyRefreshToken);
    await prefs.remove(_keyTenantId);
    await prefs.remove(_keyUser);
  }
}
