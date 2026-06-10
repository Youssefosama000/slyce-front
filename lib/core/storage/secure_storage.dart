import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Secure token and user data storage backed by platform key-chain / key-store.
class SecureStorage {
  SecureStorage._();
  static final SecureStorage instance = SecureStorage._();

  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(encryptedSharedPreferences: true),
  );

  // ── Keys ────────────────────────────────────────────────────────────
  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';
  static const _customerIdKey = 'customer_id';
  static const _userNameKey = 'user_name';
  static const _userEmailKey = 'user_email';

  // ── Access Token ────────────────────────────────────────────────────
  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);

  Future<void> setAccessToken(String token) =>
      _storage.write(key: _accessTokenKey, value: token);

  // ── Refresh Token ───────────────────────────────────────────────────
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> setRefreshToken(String token) =>
      _storage.write(key: _refreshTokenKey, value: token);

  // ── Customer ID ─────────────────────────────────────────────────────
  Future<String?> getCustomerId() => _storage.read(key: _customerIdKey);

  Future<void> setCustomerId(String id) =>
      _storage.write(key: _customerIdKey, value: id);

  // ── User Info ───────────────────────────────────────────────────────
  Future<String?> getUserName() => _storage.read(key: _userNameKey);

  Future<void> setUserName(String name) =>
      _storage.write(key: _userNameKey, value: name);

  Future<String?> getUserEmail() => _storage.read(key: _userEmailKey);

  Future<void> setUserEmail(String email) =>
      _storage.write(key: _userEmailKey, value: email);

  // ── Clear All ───────────────────────────────────────────────────────
  Future<void> clearAll() => _storage.deleteAll();

  /// Returns `true` if the user has a stored access token.
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}


