import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../constants/api_endpoints.dart';
import '../storage/secure_storage.dart';
import 'api_exceptions.dart';

/// Dio-based HTTP client with automatic Bearer token injection,
/// error mapping, and optional X-CustomerId header.
class DioClient {
  DioClient._();
  static final DioClient instance = DioClient._();

  late final Dio _dio;
  bool _initialized = false;

  Dio get dio => _dio;

  /// Must be called once at app startup.
  void init({String? baseUrl}) {
    if (_initialized) return;

    _dio = Dio(
      BaseOptions(
        baseUrl: baseUrl ?? ApiEndpoints.baseUrl,
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        sendTimeout: const Duration(seconds: 30),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    _dio.interceptors.addAll([
      _AuthInterceptor(),
      if (kDebugMode) _LoggingInterceptor(),
    ]);

    _initialized = true;
  }

  // ── Convenience Methods ───────────────────────────────────────────────

  Future<Response> get(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? extra,
  }) async {
    try {
      return await _dio.get(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(extra: extra),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Response> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Map<String, dynamic>? extra,
    Map<String, dynamic>? headers,
  }) async {
    try {
      return await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: Options(extra: extra, headers: headers),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Response> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? extra,
  }) async {
    try {
      return await _dio.put(
        path,
        data: data,
        options: Options(extra: extra),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Response> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? extra,
  }) async {
    try {
      return await _dio.patch(
        path,
        data: data,
        options: Options(extra: extra),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }

  Future<Response> delete(
    String path, {
    Map<String, dynamic>? extra,
  }) async {
    try {
      return await _dio.delete(
        path,
        options: Options(extra: extra),
      );
    } on DioException catch (e) {
      throw ApiException.fromDioException(e);
    }
  }
}

/// Injects Bearer token and X-CustomerId into every request automatically.
class _AuthInterceptor extends Interceptor {
  final _storage = SecureStorage.instance;

  @override
  void onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Attach access token if available
    final token = await _storage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    // Attach X-CustomerId and Customer_Id if available
    // (different endpoints use different header names)
    final customerId = await _storage.getCustomerId();
    if (customerId != null && customerId.isNotEmpty) {
      options.headers['X-CustomerId'] = customerId;
      options.headers['Customer_Id'] = customerId;
    }

    // Identify as mobile client
    options.headers['X-Client-Type'] = 'mobile';

    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    // Auto-logout on 401 (token expired)
    if (err.response?.statusCode == 401) {
      await _storage.clearAll();
      // The controller layer will handle navigation to sign-in
    }
    handler.next(err);
  }
}

/// Logs requests and responses in debug mode only.
class _LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    debugPrint('┌── REQUEST ──────────────────────────────────────');
    debugPrint('│ ${options.method} ${options.uri}');
    if (options.data != null) {
      debugPrint('│ Body: ${options.data}');
    }
    debugPrint('└────────────────────────────────────────────────');
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    debugPrint('┌── RESPONSE ─────────────────────────────────────');
    debugPrint('│ ${response.statusCode} ${response.requestOptions.uri}');
    debugPrint('│ Headers: ${response.headers.map}');
    debugPrint('│ Data: ${response.data}');
    debugPrint('└────────────────────────────────────────────────');
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    debugPrint('┌── ERROR ────────────────────────────────────────');
    debugPrint('│ ${err.response?.statusCode} ${err.requestOptions.uri}');
    debugPrint('│ Message: ${err.message}');
    if (err.response?.data != null) {
      debugPrint('│ Data: ${err.response?.data}');
    }
    debugPrint('└────────────────────────────────────────────────');
    handler.next(err);
  }
}


