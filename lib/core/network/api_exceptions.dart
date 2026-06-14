import 'package:dio/dio.dart';

/// Structured exception types for the API layer.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic data;

  const ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  factory ApiException.fromDioException(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const ApiException(
          message: 'Connection timed out. Please try again.',
        );
      case DioExceptionType.badResponse:
        return _fromResponse(e.response);
      case DioExceptionType.cancel:
        return const ApiException(message: 'Request was cancelled.');
      case DioExceptionType.connectionError:
        return const ApiException(
          message: 'No internet connection. Please check your network.',
        );
      default:
        return ApiException(message: e.message ?? 'Unexpected error occurred.');
    }
  }

  static ApiException _fromResponse(Response? response) {
    final statusCode = response?.statusCode ?? 0;
    final data = response?.data;

    String message;
    if (data is Map<String, dynamic>) {
      message = (data['message'] as String?) ??
          (data['error'] as String?) ??
          (data['title'] as String?) ??
          'Request failed';
    } else if (data is String && data.isNotEmpty) {
      message = data;
    } else {
      message = _defaultMessage(statusCode);
    }

    return ApiException(
      // Never surface raw backend text (internal ids / tokens) to the UI.
      message: sanitizeMessage(message, statusCode),
      statusCode: statusCode,
      data: data,
    );
  }

  /// A GUID such as `200118e4-8239-43fe-870f-9c9659b61f51`, optionally wrapped
  /// in single quotes as the backend formats it.
  static final RegExp _guidRegExp = RegExp(
    r"'?[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'?",
  );

  /// A JWT / bearer-style token (three base64url segments separated by dots).
  static final RegExp _tokenRegExp = RegExp(
    r'(?:Bearer\s+)?[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}',
  );

  /// Turn raw backend error text into safe, user-facing copy.
  ///
  /// Backend validation messages can leak internal identifiers — e.g.
  /// "Meal '200118e4-…' does not belong to the restaurant" — or even auth
  /// tokens. None of that should ever reach a snackbar, so we map known
  /// technical errors to friendly copy and strip any leftover ids / tokens.
  static String sanitizeMessage(String raw, [int statusCode = 0]) {
    var msg = raw.trim();
    if (msg.isEmpty) return _defaultMessage(statusCode);

    // Drop anything that looks like an auth token first.
    msg = msg.replaceAll(_tokenRegExp, '').trim();

    final lower = msg.toLowerCase();
    // Map known technical validation errors to friendly copy.
    if (lower.contains('does not belong to the restaurant')) {
      return "This item isn't available from this restaurant. "
          "Please reopen it from the restaurant's menu and try again.";
    }

    // Strip any leaked internal identifiers (GUIDs) and tidy the leftovers.
    msg = msg
        .replaceAll(_guidRegExp, '')
        .replaceAll("''", '')
        .replaceAll(RegExp(r"'\s*'"), '')
        .replaceAll(RegExp(r'\s{2,}'), ' ')
        .trim();

    if (msg.isEmpty) return _defaultMessage(statusCode);
    return msg;
  }

  static String _defaultMessage(int code) {
    switch (code) {
      case 400:
        return 'Bad request. Please check your input.';
      case 401:
        return 'Session expired. Please sign in again.';
      case 403:
        return 'You don\'t have permission to perform this action.';
      case 404:
        return 'Resource not found.';
      case 409:
        return 'Conflict. This record may already exist.';
      case 422:
        return 'Invalid data provided.';
      case 500:
        return 'Server error. Please try again later.';
      default:
        return 'Something went wrong (code: $code).';
    }
  }

  @override
  String toString() => 'ApiException($statusCode): $message';
}


