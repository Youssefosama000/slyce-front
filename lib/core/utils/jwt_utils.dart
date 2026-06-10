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
}
