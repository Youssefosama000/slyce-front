import 'dart:convert';

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
  static const _userRoleKey = 'user_role';

  // Profile fields captured during onboarding. The customer API has no
  // profile-read endpoint, so we persist them locally to feed the AI
  // recommendation call (POST /recommend).
  static const _profileGenderKey = 'profile_gender';
  static const _profileActivityKey = 'profile_activity_rate';
  static const _profileHeightKey = 'profile_height_cm';
  static const _profileWeightKey = 'profile_weight_kg';
  static const _profileBirthDayKey = 'profile_birthday';
  static const _profileAllergiesKey = 'profile_allergies';
  static const _profileDietPrefsKey = 'profile_diet_prefs';

  // Which customer the cached profile above belongs to. Lets us keep a
  // returning user's profile across logout/login while still wiping it when
  // a *different* account signs in on the same device.
  static const _profileOwnerKey = 'profile_owner_id';

  // Cached "Recommended for your plan" meals (JSON), so the row can render
  // instantly on the next open while fresh recommendations load in the
  // background.
  static const _recommendedCacheKey = 'recommended_cache';

  // Cached AI chat conversation (JSON) so it survives closing the chat sheet
  // and is only wiped when the user starts a New Chat.
  static const _chatHistoryCacheKey = 'chat_history_cache';

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

  // ── User Role ───────────────────────────────────────────────────────
  Future<String?> getUserRole() => _storage.read(key: _userRoleKey);

  Future<void> setUserRole(String role) =>
      _storage.write(key: _userRoleKey, value: role);

  /// Returns `true` if the stored role is `Admin` (case-insensitive).
  Future<bool> isAdmin() async {
    final role = await getUserRole();
    return role != null && role.toLowerCase() == 'admin';
  }

  // ── Onboarding profile (local cache for AI recommendations) ─────────
  Future<String?> getProfileGender() => _storage.read(key: _profileGenderKey);
  Future<void> setProfileGender(String v) =>
      _storage.write(key: _profileGenderKey, value: v);

  Future<String?> getProfileActivityRate() =>
      _storage.read(key: _profileActivityKey);
  Future<void> setProfileActivityRate(String v) =>
      _storage.write(key: _profileActivityKey, value: v);

  Future<double?> getProfileHeightCm() async {
    final v = await _storage.read(key: _profileHeightKey);
    return v == null ? null : double.tryParse(v);
  }

  Future<void> setProfileHeightCm(double v) =>
      _storage.write(key: _profileHeightKey, value: v.toString());

  Future<double?> getProfileWeightKg() async {
    final v = await _storage.read(key: _profileWeightKey);
    return v == null ? null : double.tryParse(v);
  }

  Future<void> setProfileWeightKg(double v) =>
      _storage.write(key: _profileWeightKey, value: v.toString());

  Future<String?> getProfileBirthDay() =>
      _storage.read(key: _profileBirthDayKey);
  Future<void> setProfileBirthDay(String v) =>
      _storage.write(key: _profileBirthDayKey, value: v);

  Future<List<String>> getProfileAllergies() =>
      _readStringList(_profileAllergiesKey);
  Future<void> setProfileAllergies(List<String> v) =>
      _writeStringList(_profileAllergiesKey, v);

  Future<List<String>> getProfileDietPreferences() =>
      _readStringList(_profileDietPrefsKey);
  Future<void> setProfileDietPreferences(List<String> v) =>
      _writeStringList(_profileDietPrefsKey, v);

  Future<String?> getProfileOwnerId() => _storage.read(key: _profileOwnerKey);
  Future<void> setProfileOwnerId(String v) =>
      _storage.write(key: _profileOwnerKey, value: v);

  // ── Recommended meals cache (instant render on next open) ───────────
  Future<String?> getRecommendedCache() =>
      _storage.read(key: _recommendedCacheKey);
  Future<void> setRecommendedCache(String v) =>
      _storage.write(key: _recommendedCacheKey, value: v);

  // ── AI chat conversation cache (survives closing the sheet) ───────
  Future<String?> getChatCache() => _storage.read(key: _chatHistoryCacheKey);
  Future<void> setChatCache(String v) =>
      _storage.write(key: _chatHistoryCacheKey, value: v);
  Future<void> clearChatCache() => _storage.delete(key: _chatHistoryCacheKey);

  Future<List<String>> _readStringList(String key) async {
    final raw = await _storage.read(key: key);
    if (raw == null || raw.isEmpty) return const [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
    } catch (_) {
      // Corrupt value — treat as empty.
    }
    return const [];
  }

  Future<void> _writeStringList(String key, List<String> values) =>
      _storage.write(key: key, value: jsonEncode(values));

  // ── Clearing ────────────────────────────────────────────────────────
  /// Wipes everything, including the locally cached profile. Kept for a full
  /// reset; prefer [clearSession] for logout so the profile survives.
  Future<void> clearAll() => _storage.deleteAll();

  /// Clears only the auth/session data (tokens, customer id, display name,
  /// email, role). The onboarding profile cache is intentionally preserved so
  /// a returning user keeps their data after logging out and back in.
  Future<void> clearSession() async {
    await Future.wait([
      _storage.delete(key: _accessTokenKey),
      _storage.delete(key: _refreshTokenKey),
      _storage.delete(key: _customerIdKey),
      _storage.delete(key: _userNameKey),
      _storage.delete(key: _userEmailKey),
      _storage.delete(key: _userRoleKey),
    ]);
  }

  /// Clears only the locally cached onboarding profile. Used when a different
  /// account signs in on the same device.
  Future<void> clearProfile() async {
    await Future.wait([
      _storage.delete(key: _profileGenderKey),
      _storage.delete(key: _profileActivityKey),
      _storage.delete(key: _profileHeightKey),
      _storage.delete(key: _profileWeightKey),
      _storage.delete(key: _profileBirthDayKey),
      _storage.delete(key: _profileAllergiesKey),
      _storage.delete(key: _profileDietPrefsKey),
      _storage.delete(key: _profileOwnerKey),
    ]);
  }

  /// Returns `true` if the user has a stored access token.
  Future<bool> isLoggedIn() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }
}


