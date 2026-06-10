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

    return _resolveCustomerId(
      user,
      fallbackEmail: email,
      fallbackFirstName: firstName,
      fallbackLastName: lastName,
      fallbackPhoneNumber: phoneNumber,
    );
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

    final needsId = resolved.id == null || resolved.id!.isEmpty;
    final token = resolved.accessToken;
    if (needsId && token != null && token.isNotEmpty) {
      final sub = JwtUtils.subject(token);
      if (sub != null) {
        resolved = resolved.copyWith(id: sub);
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
