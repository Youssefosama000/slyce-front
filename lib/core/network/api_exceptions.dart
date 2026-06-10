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
      message: message,
      statusCode: statusCode,
      data: data,
    );
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


