import 'package:shared_preferences/shared_preferences.dart';

abstract final class SessionStore {
  static const _userIdKey = 'userId';
  static const _userRoleKey = 'userRole';
  static const _companyIdKey = 'companyId';
  static const _firebaseUidKey = 'firebaseUid';
  static const _hrmsRoleKey = 'hrmsRole';

  static Future<String?> getUserId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userIdKey);
  }

  static Future<String?> getUserRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_userRoleKey);
  }

  static Future<String?> getCompanyId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_companyIdKey);
  }

  static Future<String?> getFirebaseUid() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_firebaseUidKey);
  }

  static Future<String?> getHrmsRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_hrmsRoleKey);
  }

  static Future<void> saveSession({
    required String userId,
    required String role,
    String? companyId,
    String? firebaseUid,
    String? hrmsRole,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, userId);
    await prefs.setString(_userRoleKey, role);

    if (companyId == null) {
      await prefs.remove(_companyIdKey);
    } else {
      await prefs.setString(_companyIdKey, companyId);
    }
    if (firebaseUid == null) {
      await prefs.remove(_firebaseUidKey);
    } else {
      await prefs.setString(_firebaseUidKey, firebaseUid);
    }
    if (hrmsRole == null) {
      await prefs.remove(_hrmsRoleKey);
    } else {
      await prefs.setString(_hrmsRoleKey, hrmsRole);
    }
  }

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_companyIdKey);
    await prefs.remove(_firebaseUidKey);
    await prefs.remove(_hrmsRoleKey);
  }
}
