import 'package:shared_preferences/shared_preferences.dart';

/// Simple persistent user id store.
/// Uses `SharedPreferences`, which maps to `localStorage` on web.
class UserStore {
  static const _keyUserId = 'afropool_user_id';

  /// Save the current user id (UUID string).
  static Future<void> saveUserId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyUserId, userId);
  }

  /// Retrieve stored user id or null.
  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    final v = prefs.getString(_keyUserId);
    if (v == null || v.trim().isEmpty) return null;
    return v.trim();
  }

  /// Clear stored user id.
  static Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyUserId);
  }
}
