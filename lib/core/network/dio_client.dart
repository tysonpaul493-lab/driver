import 'dart:io';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

/// Robust HTTP client with Dio, Sanctum token injection, and error formatting
class DioClient {
  late final Dio _dio;
  final SecureStorageService _storageService;

  DioClient(this._storageService, {void Function()? onUnauthorized}) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.defaultBaseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        responseType: ResponseType.json,
      ),
    );

    _dio.interceptors.add(
      AuthInterceptor(_storageService, onUnauthorized: onUnauthorized),
    );
  }

  /// Update the base URL dynamically (e.g. driver setting custom host)
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url.endsWith('/') ? url.substring(0, url.length - 1) : url;
  }

  /// Initialize configured base URL from storage
  Future<void> initFromStorage() async {
    final customUrl = await _storageService.getCustomApiUrl();
    if (customUrl != null && customUrl.isNotEmpty) {
      setBaseUrl(customUrl);
    }
  }

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
      throw _handleDioError(e);
    }
  }

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
      throw _handleDioError(e);
    }
  }

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
      throw _handleDioError(e);
    }
  }

  Future<dynamic> patch(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _dio.patch(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

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
      throw _handleDioError(e);
    }
  }

  /// Upload multipart file (driving license, vehicle registration, permit)
  Future<dynamic> uploadFile(
    String path, {
    required File file,
    required String fileField,
    Map<String, dynamic>? extraFields,
  }) async {
    try {
      final fileName = file.path.split(Platform.pathSeparator).last;
      final formData = FormData.fromMap({
        fileField: await MultipartFile.fromFile(file.path, filename: fileName),
        ...?extraFields,
      });

      final response = await _dio.post(
        path,
        data: formData,
        options: Options(
          headers: {'Content-Type': 'multipart/form-data'},
        ),
      );
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  ApiException _handleDioError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return ApiException(
        message: 'Network connection error. Please check your cellular/Wi-Fi connection.',
        isNetworkError: true,
      );
    }

    final response = error.response;
    if (response != null) {
      final statusCode = response.statusCode;
      final data = response.data;

      String message = 'An error occurred (${statusCode ?? "unknown"})';
      Map<String, dynamic>? validationErrors;

      if (data is Map) {
        if (data.containsKey('message')) {
          message = data['message'].toString();
        }
        if (data.containsKey('errors') && data['errors'] is Map) {
          validationErrors = Map<String, dynamic>.from(data['errors'] as Map);
        }
      }

      // Handle race condition: 409 Conflict (e.g. another driver already accepted)
      if (statusCode == 409) {
        message = message.isEmpty
            ? 'This booking request was already accepted by another ambulance or cancelled.'
            : message;
      }

      return ApiException(
        message: message,
        statusCode: statusCode,
        validationErrors: validationErrors,
      );
    }

    return ApiException(
      message: error.message ?? 'Network connection error. Please check your cellular/Wi-Fi connection.',
      isNetworkError: true,
    );
  }
}
