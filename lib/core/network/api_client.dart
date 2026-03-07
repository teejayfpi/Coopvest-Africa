import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/utils.dart';
import '../../config/app_config.dart';

/// API Client Provider
final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

/// API Client Implementation
class ApiClient {
  late final Dio _dio;
  bool _initialized = false;

  ApiClient() {
    _initialize();
  }

  void _initialize() {
    if (_initialized) return;
    
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.apiTimeout,
        receiveTimeout: AppConfig.apiTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Add interceptors
    _dio.interceptors.add(LoggingInterceptor());
    _dio.interceptors.add(ErrorInterceptor());
    _dio.interceptors.add(AuthInterceptor());
    
    _initialized = true;
  }

  Dio get dio {
    _initialize();
    return _dio;
  }

  Dio getDio() {
    _initialize();
    return _dio;
  }

  /// GET request
  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.get(
        path,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// POST request
  Future<dynamic> post(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.post(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// PUT request
  Future<dynamic> put(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.put(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// DELETE request
  Future<dynamic> delete(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.delete(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleError(e);
    }
  }

  /// Handle errors
  Exception _handleError(DioException error) {
    logger.e('API Error: ${error.message}', error: error, stackTrace: error.stackTrace);

    if (error.response != null) {
      final statusCode = error.response!.statusCode;
      final data = error.response!.data;

      switch (statusCode) {
        case 400:
          return ValidationException(data['message'] ?? 'Bad request');
        case 401:
          return AuthException('Unauthorized. Please login again.');
        case 403:
          return AuthException('Access forbidden');
        case 404:
          return ServerException('Resource not found', statusCode: statusCode);
        case 500:
          return ServerException('Server error. Please try again later.', statusCode: statusCode);
        default:
          return ServerException(
            data['message'] ?? 'An error occurred',
            statusCode: statusCode,
          );
      }
    } else if (error.type == DioExceptionType.connectionTimeout) {
      return NetworkException('Connection timeout. Please check your internet.');
    } else if (error.type == DioExceptionType.receiveTimeout) {
      return NetworkException('Request timeout. Please try again.');
    } else if (error.type == DioExceptionType.connectionError) {
      return NetworkException('Unable to connect to the server. Please check if the backend is running and the API URL in AppConfig is correct.');
    } else if (error.type == DioExceptionType.unknown) {
      return NetworkException('Network error. Please check your connection.');
    }

    return NetworkException(error.message ?? 'An error occurred');
  }

  /// Set authorization token
  void setAuthToken(String token) {
    _initialize();
    _dio.options.headers['Authorization'] = 'Bearer $token';
  }

  /// Clear authorization token
  void clearAuthToken() {
    _initialize();
    _dio.options.headers.remove('Authorization');
  }

  /// Set custom headers
  void setHeaders(Map<String, String> headers) {
    _initialize();
    _dio.options.headers.addAll(headers);
  }

  /// Reset client state
  void reset() {
    _dio.close();
    _dio = Dio(
      BaseOptions(
        baseUrl: AppConfig.apiBaseUrl,
        connectTimeout: AppConfig.apiTimeout,
        receiveTimeout: AppConfig.apiTimeout,
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );
    _dio.interceptors.add(LoggingInterceptor());
    _dio.interceptors.add(ErrorInterceptor());
    _dio.interceptors.add(AuthInterceptor());
  }

  /// Get Loan API Service
  dynamic getLoanApiService() {
    // This will be used with retrofit to create the loan API service
    return _dio;
  }

  /// Get Rollover API Service
  dynamic getRolloverApiService() {
    // This will be used with retrofit to create the rollover API service
    return _dio;
  }

  /// Get Referral API Service
  dynamic getReferralApiService() {
    return _dio;
  }
}

/// API Error Handling
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? errorCode;

  ApiException({
    required this.message,
    this.statusCode,
    this.errorCode,
  });

  @override
  String toString() {
    return 'ApiException: $message${statusCode != null ? ' (Status: $statusCode)' : ''}';
  }
}

/// Result wrapper for API responses
class ApiResult<T> {
  final T? data;
  final String? error;
  final bool isSuccess;

  ApiResult({
    this.data,
    this.error,
    required this.isSuccess,
  });

  factory ApiResult.success(T data) {
    return ApiResult(data: data, isSuccess: true);
  }

  factory ApiResult.error(String error) {
    return ApiResult(error: error, isSuccess: false);
  }

  bool get hasData => data != null;
  bool get hasError => error != null;
}

/// Extension for handling Dio errors
extension DioErrorExtension on DioException {
  ApiException toApiException() {
    switch (type) {
      case DioExceptionType.connectionTimeout:
        return ApiException(
          message: 'Connection timed out. Please try again.',
          statusCode: 408,
        );
      case DioExceptionType.sendTimeout:
        return ApiException(
          message: 'Send timed out. Please try again.',
          statusCode: 408,
        );
      case DioExceptionType.receiveTimeout:
        return ApiException(
          message: 'Receive timed out. Please try again.',
          statusCode: 408,
        );
      case DioExceptionType.badCertificate:
        return ApiException(
          message: 'Security certificate error.',
          statusCode: 495,
        );
      case DioExceptionType.badResponse:
        final statusCode = response?.statusCode;
        final errorMessage = response?.data?['message'] ?? 'Request failed';
        return ApiException(
          message: errorMessage,
          statusCode: statusCode,
        );
      case DioExceptionType.cancel:
        return ApiException(
          message: 'Request cancelled',
          statusCode: -1,
        );
      case DioExceptionType.connectionError:
        return ApiException(
          message: 'Unable to connect to the server. Please check if the backend is running and the API URL in AppConfig is correct.',
          statusCode: -1,
        );
      case DioExceptionType.unknown:
        return ApiException(
          message: 'An unexpected error occurred. Please try again.',
        );
    }
  }
}

/// Logging Interceptor
class LoggingInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    if (AppConfig.enableRequestLogging) {
      logger.i(
        'API Request: ${options.method} ${options.path}',
        error: 'Headers: ${options.headers}',
      );
      if (options.data != null) {
        logger.i('Request Data: ${options.data}');
      }
    }
    handler.next(options);
  }

  @override
  void onResponse(Response response, ResponseInterceptorHandler handler) {
    if (AppConfig.enableResponseLogging) {
      logger.i(
        'API Response: ${response.statusCode} ${response.requestOptions.path}',
        error: 'Data: ${response.data}',
      );
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    logger.e(
      'API Error: ${err.message}',
      error: err.response?.data,
      stackTrace: err.stackTrace,
    );
    handler.next(err);
  }
}

/// Auth Interceptor
class AuthInterceptor extends Interceptor {
  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    // Token will be set by auth provider
    handler.next(options);
  }
}

/// Error Interceptor
class ErrorInterceptor extends Interceptor {
  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    handler.next(err);
  }
}
