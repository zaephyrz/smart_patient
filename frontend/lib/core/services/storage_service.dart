import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const _tokenKey = 'auth_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _userIdKey = 'user_id';
  static const _userEmailKey = 'user_email';
  static const _userDisplayNameKey = 'user_display_name';
  static const _userRoleKey = 'user_role';
  static const _userPinKey = 'user_pin';
  static const _userProfileKey = 'user_profile';
  static const _userPhoneKey = 'user_phone';
  static const _userDateOfBirthKey = 'user_dob';
  static const _userBloodTypeKey = 'user_blood_type';
  static const _userAllergiesKey = 'user_allergies';
  static const _userMedicationsKey = 'user_medications';
  static const _userAvatarKey = 'user_avatar';
  static const _userAvatarPathKey = 'user_avatar_path';
  static const _isFirstLaunchKey = 'is_first_launch';
  static const _lastLoginKey = 'last_login';
  static const _notificationsKey = 'app_local_notifications';
  
  static const String _appFolderName = 'SmartPatient';
  
  final FlutterSecureStorage? _secureStorage;
  SharedPreferences? _preferences;

  StorageService() : _secureStorage = _isMobilePlatform() ? const FlutterSecureStorage() : null {
    _initPreferences();
  }

  static bool _isMobilePlatform() {
    return !kIsWeb && (Platform.isAndroid || Platform.isIOS);
  }

  Future<void> _initPreferences() async {
    if (!_isMobilePlatform()) {
      _preferences = await SharedPreferences.getInstance();
    }
  }

  Future<SharedPreferences> _getPreferences() async {
    return _preferences ??= await SharedPreferences.getInstance();
  }

  // =============================================
  // GENERIC STORAGE METHODS
  // =============================================

  Future<void> _write(String key, String value) async {
    if (_isMobilePlatform()) {
      try {
        await _secureStorage?.write(key: key, value: value);
      } catch (e) {
        final prefs = await _getPreferences();
        await prefs.setString(key, value);
      }
    } else {
      final prefs = await _getPreferences();
      await prefs.setString(key, value);
    }
  }

  Future<String?> _read(String key) async {
    if (_isMobilePlatform()) {
      try {
        return await _secureStorage?.read(key: key);
      } catch (e) {
        final prefs = await _getPreferences();
        return prefs.getString(key);
      }
    } else {
      final prefs = await _getPreferences();
      return prefs.getString(key);
    }
  }

  Future<void> _delete(String key) async {
    if (_isMobilePlatform()) {
      try {
        await _secureStorage?.delete(key: key);
      } catch (e) {}
    }
    final prefs = await _getPreferences();
    await prefs.remove(key);
  }

  Future<void> _deleteAll() async {
    if (_isMobilePlatform()) {
      try {
        await _secureStorage?.deleteAll();
      } catch (e) {}
    }
    final prefs = await _getPreferences();
    await prefs.clear();
  }

  Future<Map<String, String>> _readAll() async {
    final Map<String, String> result = {};
    
    if (_isMobilePlatform()) {
      try {
        final secureData = await _secureStorage?.readAll() ?? {};
        result.addAll(secureData);
      } catch (e) {}
    }
    
    final prefs = await _getPreferences();
    final prefsKeys = prefs.getKeys();
    for (final key in prefsKeys) {
      final value = prefs.getString(key);
      if (value != null) {
        result[key] = value;
      }
    }
    
    return result;
  }

  // =============================================
  // LOCAL NOTIFICATIONS STORAGE METHODS
  // =============================================

  Future<List<Map<String, dynamic>>> getLocalNotifications() async {
    try {
      final jsonString = await _read(_notificationsKey);
      if (jsonString != null && jsonString.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(jsonString);
        return List<Map<String, dynamic>>.from(decoded);
      }
    } catch (_) {}
    return [];
  }

  Future<void> saveLocalNotification({
    required int id,
    required String title,
    required String message,
    required String type,
  }) async {
    try {
      final List<Map<String, dynamic>> existing = await getLocalNotifications();

      final newNotification = {
        'id': id,
        'title': title,
        'message': message,
        'type': type,
        'is_read': 0,
        'created_at': DateTime.now().toIso8601String(),
      };

      final updated = [
        newNotification,
        ...existing.where((n) => n['id'].toString() != id.toString())
      ].take(50).toList();

      await _write(_notificationsKey, jsonEncode(updated));
    } catch (_) {}
  }

  Future<void> markLocalNotificationAsRead(int id) async {
    try {
      final List<Map<String, dynamic>> existing = await getLocalNotifications();
      for (var item in existing) {
        if (item['id'].toString() == id.toString()) {
          item['is_read'] = 1;
        }
      }
      await _write(_notificationsKey, jsonEncode(existing));
    } catch (_) {}
  }

  Future<void> markAllLocalNotificationsAsRead() async {
    try {
      final List<Map<String, dynamic>> existing = await getLocalNotifications();
      for (var item in existing) {
        item['is_read'] = 1;
      }
      await _write(_notificationsKey, jsonEncode(existing));
    } catch (_) {}
  }

  // =============================================
  // CUSTOM APP FOLDER METHODS
  // =============================================
  
  Future<String> getAppDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    final String appFolder = '${directory.path}/$_appFolderName';
    final Directory folder = Directory(appFolder);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return appFolder;
  }

  Future<String> getAvatarDirectory() async {
    final appFolder = await getAppDirectory();
    final String avatarFolder = '$appFolder/avatars';
    final Directory folder = Directory(avatarFolder);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return avatarFolder;
  }

  Future<String> getDownloadsDirectory() async {
    final appFolder = await getAppDirectory();
    final String downloadsFolder = '$appFolder/downloads';
    final Directory folder = Directory(downloadsFolder);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    return downloadsFolder;
  }

  Future<String> saveFileToAppFolder(String fileName, List<int> bytes, {String subFolder = 'downloads'}) async {
    final appFolder = await getAppDirectory();
    final String folderPath = '$appFolder/$subFolder';
    final Directory folder = Directory(folderPath);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final String filePath = '$folderPath/$fileName';
    final File file = File(filePath);
    await file.writeAsBytes(bytes);
    return filePath;
  }

  Future<String> copyFileToAppFolder(String sourcePath, String fileName, {String subFolder = 'downloads'}) async {
    final appFolder = await getAppDirectory();
    final String folderPath = '$appFolder/$subFolder';
    final Directory folder = Directory(folderPath);
    if (!await folder.exists()) {
      await folder.create(recursive: true);
    }
    final String filePath = '$folderPath/$fileName';
    final File sourceFile = File(sourcePath);
    final File destFile = await sourceFile.copy(filePath);
    return destFile.path;
  }

  Future<String> saveAvatarImage(String sourcePath) async {
    final avatarFolder = await getAvatarDirectory();
    final String fileName = 'avatar_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final String filePath = '$avatarFolder/$fileName';
    final File sourceFile = File(sourcePath);
    final File destFile = await sourceFile.copy(filePath);
    
    await saveUserAvatarPath(destFile.path);
    return destFile.path;
  }

  Future<bool> deleteAvatarFile() async {
    try {
      final path = await getUserAvatarPath();
      if (path != null && path.isNotEmpty) {
        final file = File(path);
        if (await file.exists()) {
          await file.delete();
        }
        await clearUserAvatarPath();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  Future<List<FileSystemEntity>> getFilesInFolder({String subFolder = 'downloads'}) async {
    final appFolder = await getAppDirectory();
    final String folderPath = '$appFolder/$subFolder';
    final Directory folder = Directory(folderPath);
    if (await folder.exists()) {
      return folder.listSync();
    }
    return [];
  }

  Future<bool> deleteFileFromAppFolder(String filePath) async {
    try {
      final file = File(filePath);
      if (await file.exists()) {
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }

  // =============================================
  // AUTH TOKEN METHODS
  // =============================================
  
  Future<void> saveAuthToken(String token) async {
    await _write(_tokenKey, token);
  }
  
  Future<String?> getAuthToken() async {
    return await _read(_tokenKey);
  }
  
  Future<bool> hasValidToken() async {
    final token = await getAuthToken();
    return token != null && token.isNotEmpty;
  }
  
  // =============================================
  // REFRESH TOKEN METHODS
  // =============================================
  
  Future<void> saveRefreshToken(String refreshToken) async {
    await _write(_refreshTokenKey, refreshToken);
  }
  
  Future<String?> getRefreshToken() async {
    return await _read(_refreshTokenKey);
  }
  
  // =============================================
  // USER ID METHODS
  // =============================================
  
  Future<void> saveUserId(String userId) async {
    await _write(_userIdKey, userId);
  }
  
  Future<String?> getUserId() async {
    return await _read(_userIdKey);
  }
  
  // =============================================
  // USER EMAIL METHODS
  // =============================================
  
  Future<void> saveUserEmail(String email) async {
    await _write(_userEmailKey, email);
  }
  
  Future<String?> getUserEmail() async {
    return await _read(_userEmailKey);
  }
  
  // =============================================
  // USER DISPLAY NAME METHODS
  // =============================================
  
  Future<void> saveUserDisplayName(String name) async {
    await _write(_userDisplayNameKey, name);
  }
  
  Future<String?> getUserDisplayName() async {
    return await _read(_userDisplayNameKey);
  }
  
  // =============================================
  // USER ROLE METHODS
  // =============================================
  
  Future<void> saveUserRole(String role) async {
    await _write(_userRoleKey, role);
  }
  
  Future<String?> getUserRole() async {
    return await _read(_userRoleKey);
  }
  
  Future<void> clearUserRole() async {
    await _delete(_userRoleKey);
  }
  
  Future<bool> isDoctor() async {
    final role = await getUserRole();
    return role == 'doctor';
  }
  
  Future<bool> isPatient() async {
    final role = await getUserRole();
    return role == 'patient';
  }
  
  // =============================================
  // USER AVATAR METHODS (Emoji/Text Avatar)
  // =============================================
  
  Future<void> saveUserAvatar(String avatar) async {
    await _write(_userAvatarKey, avatar);
  }
  
  Future<String?> getUserAvatar() async {
    return await _read(_userAvatarKey);
  }
  
  Future<void> clearUserAvatar() async {
    await _delete(_userAvatarKey);
  }
  
  // =============================================
  // USER AVATAR PATH METHODS (Photo Avatar)
  // =============================================
  
  Future<void> saveUserAvatarPath(String path) async {
    await _write(_userAvatarPathKey, path);
  }
  
  Future<String?> getUserAvatarPath() async {
    return await _read(_userAvatarPathKey);
  }
  
  Future<void> clearUserAvatarPath() async {
    await _delete(_userAvatarPathKey);
  }
  
  Future<bool> hasAvatarPath() async {
    final path = await getUserAvatarPath();
    return path != null && path.isNotEmpty;
  }
  
  // =============================================
  // USER PIN METHODS
  // =============================================
  
  Future<void> saveUserPin(String pin) async {
    await _write(_userPinKey, pin);
  }
  
  Future<String?> getUserPin() async {
    return await _read(_userPinKey);
  }
  
  Future<bool> hasPin() async {
    final pin = await getUserPin();
    return pin != null && pin.isNotEmpty;
  }
  
  Future<void> clearUserPin() async {
    await _delete(_userPinKey);
  }
  
  // =============================================
  // USER PROFILE METHODS
  // =============================================
  
  Future<void> saveUserProfile(Map<String, dynamic> profile) async {
    final jsonString = jsonEncode(profile);
    await _write(_userProfileKey, jsonString);
    
    if (profile['phone'] != null) {
      await saveUserPhone(profile['phone'].toString());
    }
    if (profile['date_of_birth'] != null) {
      await saveUserDateOfBirth(profile['date_of_birth'].toString());
    }
    if (profile['blood_type'] != null) {
      await saveUserBloodType(profile['blood_type'].toString());
    }
    if (profile['allergies'] != null) {
      await saveUserAllergies(profile['allergies'].toString());
    }
    if (profile['medications'] != null) {
      await saveUserMedications(profile['medications'].toString());
    }
    if (profile['avatar'] != null) {
      await saveUserAvatar(profile['avatar'].toString());
    }
    if (profile['avatar_path'] != null) {
      await saveUserAvatarPath(profile['avatar_path'].toString());
    }
    if (profile['role'] != null) {
      await saveUserRole(profile['role'].toString());
    }
  }
  
  Future<Map<String, dynamic>?> getUserProfile() async {
    final jsonString = await _read(_userProfileKey);
    if (jsonString != null && jsonString.isNotEmpty) {
      try {
        return jsonDecode(jsonString) as Map<String, dynamic>;
      } catch (e) {
        return null;
      }
    }
    return null;
  }
  
  // =============================================
  // USER ADDITIONAL FIELDS
  // =============================================
  
  Future<void> saveUserPhone(String phone) async {
    await _write(_userPhoneKey, phone);
  }
  
  Future<String?> getUserPhone() async {
    return await _read(_userPhoneKey);
  }
  
  Future<void> saveUserDateOfBirth(String dob) async {
    await _write(_userDateOfBirthKey, dob);
  }
  
  Future<String?> getUserDateOfBirth() async {
    return await _read(_userDateOfBirthKey);
  }
  
  Future<void> saveUserBloodType(String bloodType) async {
    await _write(_userBloodTypeKey, bloodType);
  }
  
  Future<String?> getUserBloodType() async {
    return await _read(_userBloodTypeKey);
  }
  
  Future<void> saveUserAllergies(String allergies) async {
    await _write(_userAllergiesKey, allergies);
  }
  
  Future<String?> getUserAllergies() async {
    return await _read(_userAllergiesKey);
  }
  
  Future<void> saveUserMedications(String medications) async {
    await _write(_userMedicationsKey, medications);
  }
  
  Future<String?> getUserMedications() async {
    return await _read(_userMedicationsKey);
  }
  
  // =============================================
  // APP SETTINGS
  // =============================================
  
  Future<void> setFirstLaunch(bool value) async {
    await _write(_isFirstLaunchKey, value.toString());
  }
  
  Future<bool> isFirstLaunch() async {
    final value = await _read(_isFirstLaunchKey);
    return value == null || value == 'true';
  }
  
  Future<void> saveLastLogin(DateTime dateTime) async {
    await _write(_lastLoginKey, dateTime.toIso8601String());
  }
  
  Future<DateTime?> getLastLogin() async {
    final value = await _read(_lastLoginKey);
    if (value != null && value.isNotEmpty) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
  
  // =============================================
  // AUTHENTICATION STATUS
  // =============================================
  
  Future<bool> isAuthenticated() async {
    final token = await getAuthToken();
    final userId = await getUserId();
    final email = await getUserEmail();
    return token != null && userId != null && email != null;
  }
  
  // =============================================
  // CLEAR ALL DATA
  // =============================================
  
  Future<void> clearAll() async {
    await _deleteAll();
  }
  
  Future<void> clearAuthData() async {
    await _delete(_tokenKey);
    await _delete(_refreshTokenKey);
    await _delete(_userIdKey);
    await _delete(_userEmailKey);
    await _delete(_userDisplayNameKey);
    await _delete(_userRoleKey);
    await _delete(_userProfileKey);
    await _delete(_userAvatarKey);
    await _delete(_userAvatarPathKey);
  }
  
  Future<void> clearUserData() async {
    await _delete(_userPhoneKey);
    await _delete(_userDateOfBirthKey);
    await _delete(_userBloodTypeKey);
    await _delete(_userAllergiesKey);
    await _delete(_userMedicationsKey);
    await _delete(_userAvatarKey);
    await _delete(_userAvatarPathKey);
    await _delete(_userRoleKey);
  }
  
  Future<void> clearAvatarData() async {
    await _delete(_userAvatarKey);
    await _delete(_userAvatarPathKey);
  }
  
  // =============================================
  // LEGACY METHODS (Backward Compatibility)
  // =============================================
  
  Future<void> saveToken(String token) async {
    await saveAuthToken(token);
  }
  
  Future<String?> getToken() async {
    return getAuthToken();
  }
  
  Future<void> saveUserData(Map<String, dynamic> userData) async {
    if (userData['id'] != null) {
      await saveUserId(userData['id'].toString());
    }
    if (userData['email'] != null) {
      await saveUserEmail(userData['email']);
    }
    if (userData['name'] != null) {
      await saveUserDisplayName(userData['name']);
    }
    if (userData['phone'] != null) {
      await saveUserPhone(userData['phone'].toString());
    }
    if (userData['date_of_birth'] != null) {
      await saveUserDateOfBirth(userData['date_of_birth'].toString());
    }
    if (userData['avatar'] != null) {
      await saveUserAvatar(userData['avatar'].toString());
    }
    if (userData['avatar_path'] != null) {
      await saveUserAvatarPath(userData['avatar_path'].toString());
    }
    if (userData['role'] != null) {
      await saveUserRole(userData['role'].toString());
    }
    if (userData.isNotEmpty) {
      await saveUserProfile(userData);
    }
  }
  
  // =============================================
  // UTILITY METHODS
  // =============================================
  
  Future<Map<String, String>> getAllKeys() async {
    return await _readAll();
  }
  
  Future<void> removeKey(String key) async {
    await _delete(key);
  }
  
  Future<bool> containsKey(String key) async {
    final value = await _read(key);
    return value != null;
  }
}