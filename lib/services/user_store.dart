import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Persistent auth/session store.
///
/// - [userId], [role], and [isBlocked] are stored in SharedPreferences.
/// - [token] is stored in FlutterSecureStorage on mobile, SharedPreferences on web.
class UserStore {
  static const _keyUserId = 'afropool_user_id';
  static const _keyUserRole = 'afropool_user_role';
  static const _keyAccessToken = 'afropool_access_token';
  static const _keyIsBlocked = 'afropool_is_blocked'; // 👈 new

  static const FlutterSecureStorage _secureStorage = FlutterSecureStorage();

  // ── User ID ───────────────────────────────────────────────────────────────

  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId.trim());
  }

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyUserId);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim();
  }

  // ── Role ──────────────────────────────────────────────────────────────────

  static Future<void> saveUserRole(String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserRole, role.trim().toUpperCase());
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    final value = prefs.getString(_keyUserRole);
    if (value == null || value.trim().isEmpty) return null;
    return value.trim().toUpperCase();
  }

  // ── isBlocked ─────────────────────────────────────────────────────────────

  static Future<void> saveIsBlocked(bool isBlocked) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyIsBlocked, isBlocked);
  }

  static Future<bool> getIsBlocked() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_keyIsBlocked) ?? false;
  }

  // ── Token ─────────────────────────────────────────────────────────────────

  static Future<void> saveToken(String token) async {
    final normalized = token.trim();
    if (normalized.isEmpty) {
      await clearToken();
      return;
    }
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccessToken, normalized);
      return;
    }
    try {
      await _secureStorage.write(key: _keyAccessToken, value: normalized);
    } catch (err) {
      debugPrint('Secure storage unavailable, falling back: $err');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_keyAccessToken, normalized);
    }
  }

  static Future<String?> getToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_keyAccessToken);
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    }
    try {
      final value = await _secureStorage.read(key: _keyAccessToken);
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    } catch (err) {
      debugPrint('Secure storage unavailable, falling back: $err');
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(_keyAccessToken);
      if (value == null || value.trim().isEmpty) return null;
      return value.trim();
    }
  }

  static Future<void> clearToken() async {
    if (kIsWeb) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAccessToken);
      return;
    }
    try {
      await _secureStorage.delete(key: _keyAccessToken);
    } catch (_) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_keyAccessToken);
    }
  }

  // ── Clear ─────────────────────────────────────────────────────────────────

  static Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
    await prefs.remove(_keyUserRole);
    await prefs.remove(_keyAccessToken);
    await prefs.remove(_keyIsBlocked); // 👈 clear on logout
    if (!kIsWeb) {
      try {
        await _secureStorage.delete(key: _keyAccessToken);
      } catch (_) {}
    }
  }

  static Future<void> clear() async => clearAll();
}
