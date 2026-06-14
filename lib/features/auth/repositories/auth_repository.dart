import 'package:slyce/core/constants/api_endpoints.dart';
import 'package:slyce/core/network/dio_client.dart';
import 'package:slyce/core/utils/jwt_utils.dart';
import 'package:slyce/features/auth/models/user_model.dart';

/// Repository handling all authentication API calls.
class AuthRepository {
  final _client = DioClient.instance;

  /// Login with email & password.
  Future<UserModel> login({
    required String email,
    required String password,
  }) async {
    final response = await _client.post(
      ApiEndpoints.login,
      data: {
        'email': email,
        'password': password,
      },
    );

    UserModel user;
    // If the API returns a body, parse it normally.
    if (response.data != null && response.data is Map<String, dynamic>) {
      user = UserModel.fromJson(response.data as Map<String, dynamic>);
    } else {
      // 204 No Content – login succeeded but no body.
      // Try to extract token from response headers.
      final headers = response.headers;
      final accessToken =
          headers.value('authorization')?.replaceFirst('Bearer ', '') ??
              headers.value('x-access-token') ??
              headers.value('token');
      final customerId = headers.value('x-customerid');

      user = UserModel(
        id: customerId,
        email: email,
        accessToken: accessToken,
      );
    }

    return _resolveCustomerId(user, fallbackEmail: email);
  }

  /// Register a new customer.
  Future<UserModel> register({
    required String firstName,
    required String lastName,
    required String email,
    required String password,
    String? phoneNumber,
    String? birthDay,
  }) async {
    final response = await _client.post(
      ApiEndpoints.register,
      data: {
        'firstName': firstName,
        'lastName': lastName,
        'email': email,
        'password': password,
        if (phoneNumber != null) 'phoneNumber': phoneNumber,
        if (birthDay != null) 'birthDay': birthDay,
      },
    );

    UserModel user;
    // If the API returns a body, parse it normally.
    if (response.data != null && response.data is Map<String, dynamic>) {
      user = UserModel.fromJson(response.data as Map<String, dynamic>);
    } else {
      // 204 No Content – registration succeeded but no body.
      final headers = response.headers;
      final accessToken =
          headers.value('authorization')?.replaceFirst('Bearer ', '') ??
              headers.value('x-access-token') ??
              headers.value('token');
      final customerId = headers.value('x-customerid');

      user = UserModel(
        id: customerId,
        firstName: firstName,
        lastName: lastName,
        email: email,
        phoneNumber: phoneNumber,
        accessToken: accessToken,
      );
    }

    final resolved = _resolveCustomerId(
      user,
      fallbackEmail: email,
      fallbackFirstName: firstName,
      fallbackLastName: lastName,
      fallbackPhoneNumber: phoneNumber,
    );

    // The register endpoint (/v1/customers) creates the account but does NOT
    // return a session token, so the user would land in the app without being
    // authenticated (no token => name doesn't show and protected endpoints
    // fail). Immediately log in with the same credentials to obtain a real
    // token, while keeping the name/phone supplied at registration.
    if (resolved.accessToken == null || resolved.accessToken!.isEmpty) {
      try {
        final loggedIn = await login(email: email, password: password);
        return loggedIn.copyWith(
          firstName: loggedIn.firstName ?? firstName,
          lastName: loggedIn.lastName ?? lastName,
          phoneNumber: loggedIn.phoneNumber ?? phoneNumber,
        );
      } catch (_) {
        // If auto-login fails for any reason, fall back to the registered user.
        return resolved;
      }
    }

    return resolved;
  }

  /// Set password using a reset token.
  Future<void> setPassword({
    required String token,
    required String password,
  }) async {
    await _client.patch(
      ApiEndpoints.setPassword,
      data: {
        'token': token,
        'password': password,
      },
    );
  }

  /// Send a password reset email to the given address.
  Future<void> forgotPassword({required String email}) async {
    await _client.post(
      ApiEndpoints.forgotPassword,
      data: {'email': email},
    );
  }

  /// The login response is a JWT whose `sub` claim is the customer id. Several
  /// endpoints (cart, subscriptions) require that id as a header, so when the
  /// server doesn't echo it back explicitly we recover it from the token.
  UserModel _resolveCustomerId(
    UserModel user, {
    String? fallbackEmail,
    String? fallbackFirstName,
    String? fallbackLastName,
    String? fallbackPhoneNumber,
  }) {
    var resolved = user;

    final token = resolved.accessToken;
    if (token != null && token.isNotEmpty) {
      final needsId = resolved.id == null || resolved.id!.isEmpty;
      if (needsId) {
        final sub = JwtUtils.subject(token);
        if (sub != null) {
          resolved = resolved.copyWith(id: sub);
        }
      }

      // The role lives under the Microsoft schema URI inside the token, so
      // recover it from there whenever the response body doesn't include it.
      if (resolved.role == null || resolved.role!.isEmpty) {
        final role = JwtUtils.role(token);
        if (role != null) {
          resolved = resolved.copyWith(role: role);
        }
      }

      // The token also carries the user's name and email (e.g. for a 204
      // login that returns no body), so recover those too when missing.
      if (resolved.firstName == null || resolved.firstName!.isEmpty) {
        final firstName = JwtUtils.givenName(token);
        if (firstName != null) {
          resolved = resolved.copyWith(firstName: firstName);
        }
      }
      if (resolved.lastName == null || resolved.lastName!.isEmpty) {
        final lastName = JwtUtils.familyName(token);
        if (lastName != null) {
          resolved = resolved.copyWith(lastName: lastName);
        }
      }
      if (resolved.email == null || resolved.email!.isEmpty) {
        final email = JwtUtils.email(token);
        if (email != null) {
          resolved = resolved.copyWith(email: email);
        }
      }
    }

    return resolved.copyWith(
      email: resolved.email ?? fallbackEmail,
      firstName: resolved.firstName ?? fallbackFirstName,
      lastName: resolved.lastName ?? fallbackLastName,
      phoneNumber: resolved.phoneNumber ?? fallbackPhoneNumber,
    );
  }
}
