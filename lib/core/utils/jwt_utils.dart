import 'dart:convert';

/// Lightweight helpers for reading claims out of a JWT access token.
///
/// This only base64-decodes the payload (no signature verification) so the
/// app can recover values the backend embeds in the token – most importantly
/// the customer id in the `sub` claim, which several endpoints require as the
/// `X-CustomerId` / `Customer_Id` header.
class JwtUtils {
  JwtUtils._();

  /// Decodes the payload section of a JWT. Returns `null` if the token is
  /// malformed.
  static Map<String, dynamic>? decodePayload(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;

      var payload = parts[1].replaceAll('-', '+').replaceAll('_', '/');
      switch (payload.length % 4) {
        case 2:
          payload += '==';
          break;
        case 3:
          payload += '=';
          break;
      }

      final decoded = utf8.decode(base64.decode(payload));
      final map = jsonDecode(decoded);
      return map is Map<String, dynamic> ? map : null;
    } catch (_) {
      return null;
    }
  }

  /// Extracts the `sub` (subject / customer id) claim from a JWT.
  static String? subject(String token) {
    final value = decodePayload(token)?['sub'];
    final str = value?.toString();
    return (str != null && str.isNotEmpty) ? str : null;
  }

  // Standard ASP.NET / WS-Federation claim type URIs. The backend emits the
  // role (and sometimes name/email) under these long Microsoft schema URIs
  // rather than plain keys, so we have to look them up under both forms.
  static const _roleClaimKeys = [
    'role',
    'roles',
    'http://schemas.microsoft.com/ws/2008/06/identity/claims/role',
  ];
  static const _nameClaimKeys = [
    'name',
    'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/name',
  ];
  static const _emailClaimKeys = [
    'email',
    'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/emailaddress',
  ];
  static const _givenNameClaimKeys = [
    'given_name',
    'givenName',
    'name',
    'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/givenname',
  ];
  static const _familyNameClaimKeys = [
    'family_name',
    'familyName',
    'surname',
    'http://schemas.xmlsoap.org/ws/2005/05/identity/claims/surname',
  ];

  /// Reads the first non-empty value among [keys] from the token payload.
  /// If a claim is a list (e.g. multiple roles) the first entry is returned.
  static String? claim(String token, List<String> keys) {
    final payload = decodePayload(token);
    if (payload == null) return null;
    for (final key in keys) {
      final value = payload[key];
      if (value == null) continue;
      if (value is List) {
        if (value.isEmpty) continue;
        final first = value.first?.toString();
        if (first != null && first.isNotEmpty) return first;
      } else {
        final str = value.toString();
        if (str.isNotEmpty) return str;
      }
    }
    return null;
  }

  /// All values for a (possibly repeated) claim such as `role`.
  static List<String> claimList(String token, List<String> keys) {
    final payload = decodePayload(token);
    if (payload == null) return const [];
    for (final key in keys) {
      final value = payload[key];
      if (value == null) continue;
      if (value is List) {
        return value
            .map((e) => e?.toString() ?? '')
            .where((e) => e.isNotEmpty)
            .toList();
      }
      final str = value.toString();
      if (str.isNotEmpty) return [str];
    }
    return const [];
  }

  /// Extracts the user role (e.g. `Admin`) from the token. Handles both a
  /// plain `role` key and the Microsoft schema URI used by the backend.
  static String? role(String token) => claim(token, _roleClaimKeys);

  /// All roles assigned to the user.
  static List<String> roles(String token) => claimList(token, _roleClaimKeys);

  /// `true` when the token grants the `Admin` role (case-insensitive).
  static bool isAdmin(String token) =>
      roles(token).any((r) => r.toLowerCase() == 'admin');

  /// Display name embedded in the token, if present.
  static String? name(String token) => claim(token, _nameClaimKeys);

  /// Email address embedded in the token, if present.
  static String? email(String token) => claim(token, _emailClaimKeys);

  /// Given (first) name embedded in the token, if present. Falls back to the
  /// full `name` claim when no dedicated given-name claim exists.
  static String? givenName(String token) => claim(token, _givenNameClaimKeys);

  /// Family (last) name embedded in the token, if present.
  static String? familyName(String token) => claim(token, _familyNameClaimKeys);

  /// Token expiry (`exp`) as a UTC [DateTime], or `null` if absent/invalid.
  static DateTime? expiry(String token) {
    final exp = decodePayload(token)?['exp'];
    if (exp == null) return null;
    final seconds = exp is int ? exp : int.tryParse(exp.toString());
    if (seconds == null) return null;
    return DateTime.fromMillisecondsSinceEpoch(seconds * 1000, isUtc: true);
  }

  /// `true` when the token carries an `exp` claim that is already in the past.
  static bool isExpired(String token) {
    final date = expiry(token);
    if (date == null) return false;
    return DateTime.now().toUtc().isAfter(date);
  }
}
