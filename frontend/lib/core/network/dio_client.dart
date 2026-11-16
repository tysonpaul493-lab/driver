import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../constants/api_constants.dart';
import '../storage/secure_storage_service.dart';
import 'api_exception.dart';
import 'auth_interceptor.dart';

/// Robust HTTP client with Dio, Sanctum token injection, automatic host failover, and error formatting
class DioClient {
  late final Dio _dio;
  final SecureStorageService _storageService;
  final void Function()? onHostSwitched;

  DioClient(
    this._storageService, {
    void Function()? onUnauthorized,
    this.onHostSwitched,
  }) {
    _dio = Dio(
      BaseOptions(
        baseUrl: ApiConstants.defaultBaseUrl,
        connectTimeout: ApiConstants.connectTimeout,
        receiveTimeout: ApiConstants.receiveTimeout,
        responseType: ResponseType.json,
        headers: const {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
      ),
    );

    _dio.interceptors.add(
      AuthInterceptor(_storageService, onUnauthorized: onUnauthorized),
    );
  }

  /// Update the base URL dynamically (e.g. driver setting custom host)
  void setBaseUrl(String url) {
    _dio.options.baseUrl = url.endsWith('/')
        ? url.substring(0, url.length - 1)
        : url;
  }

  /// Initialize configured base URL from storage
  Future<void> initFromStorage() async {
    final customUrl = await _storageService.getCustomApiUrl();
    if (customUrl != null && customUrl.isNotEmpty) {
      if (kIsWeb && (customUrl.contains('localhost') || customUrl.contains('127.0.0.1'))) {
        await _storageService.setCustomApiUrl(null);
        ApiConstants.setServerHost(null);
      } else {
        ApiConstants.setServerHost(customUrl);
      }
    }
    refreshBaseUrl();
  }

  /// Sync Dio base URL with current [ApiConstants.defaultBaseUrl]
  void refreshBaseUrl() {
    setBaseUrl(ApiConstants.defaultBaseUrl);
  }

  /// Fast parallel probe of candidate hosts and lock onto the first healthy one instantly
  static Future<String?> resolveReachableHost({
    String? excludeHost,
    Duration timeout = const Duration(milliseconds: 2500),
  }) async {
    if (kIsWeb || ApiConstants.hasCustomServerHost) {
      return ApiConstants.effectiveHost;
    }

    final candidates = ApiConstants.candidateHosts
        .where((h) => excludeHost == null || h != excludeHost)
        .toList();

    if (candidates.isEmpty) return null;

    final completer = Completer<String?>();
    var pending = candidates.length;

    for (final host in candidates) {
      final probe = Dio(
        BaseOptions(
          connectTimeout: timeout,
          receiveTimeout: timeout,
          sendTimeout: timeout,
        ),
      );

      probe.get('${ApiConstants.baseUrlForHost(host)}/health').then((resp) {
        if (resp.statusCode == 200 && !completer.isCompleted) {
          ApiConstants.setRuntimeFallbackHost(host);
          completer.complete(host);
        }
      }).catchError((_) {
        // Probe failed on this host
      }).whenComplete(() {
        probe.close();
        pending--;
        if (pending == 0 && !completer.isCompleted) {
          completer.complete(null);
        }
      });
    }

    return completer.future;
  }

  Future<Response<dynamic>> _executeWithFailover(
    Future<Response<dynamic>> Function() requestFn,
  ) async {
    try {
      return await requestFn();
    } on DioException catch (e) {
      final isConnectivityFailure =
          e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.error is SocketException;

      if (isConnectivityFailure &&
          !kIsWeb &&
          !ApiConstants.hasCustomServerHost) {
        final failedHost = ApiConstants.effectiveHost;
        final nextHost = await resolveReachableHost(excludeHost: failedHost);
        if (nextHost != null && nextHost != failedHost) {
          refreshBaseUrl();
          onHostSwitched?.call();
          return await requestFn();
        }
      }
      rethrow;
    }
  }

  /// Ping dispatch server health endpoint to verify connectivity
  Future<bool> checkHealth() async {
    try {
      final response = await _executeWithFailover(
        () => _dio.get(
          '/health',
          options: Options(
            sendTimeout: const Duration(seconds: 4),
            receiveTimeout: const Duration(seconds: 4),
          ),
        ),
      );
      return response.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<dynamic> get(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
  }) async {
    try {
      final response = await _executeWithFailover(
        () =>
            _dio.get(path, queryParameters: queryParameters, options: options),
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
      final response = await _executeWithFailover(
        () => _dio.post(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        ),
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
      final response = await _executeWithFailover(
        () => _dio.put(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        ),
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
      final response = await _executeWithFailover(
        () => _dio.patch(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        ),
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
      final response = await _executeWithFailover(
        () => _dio.delete(
          path,
          data: data,
          queryParameters: queryParameters,
          options: options,
        ),
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
      final fileName = file.path.split(RegExp(r'[/\\]')).last;
      final response = await _executeWithFailover(() async {
        final formData = FormData.fromMap({
          fileField: await MultipartFile.fromFile(
            file.path,
            filename: fileName,
          ),
          ...?extraFields,
        });
        return _dio.post(
          path,
          data: formData,
          options: Options(headers: {'Content-Type': 'multipart/form-data'}),
        );
      });
      return response.data;
    } on DioException catch (e) {
      throw _handleDioError(e);
    }
  }

  /// Upload multipart file from raw bytes (Web-safe fallback)
  Future<dynamic> uploadFileBytes(
    String path, {
    required List<int> bytes,
    required String fileName,
    required String fileField,
    Map<String, dynamic>? extraFields,
  }) async {
    try {
      final response = await _executeWithFailover(() {
        final formData = FormData.fromMap({
          fileField: MultipartFile.fromBytes(bytes, filename: fileName),
          ...?extraFields,
        });
        return _dio.post(
          path,
          data: formData,
          options: Options(headers: {'Content-Type': 'multipart/form-data'}),
        );
      });
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
        message: 'Network connection error. Unable to reach dispatch gateway. Please check your internet connection.',
        isNetworkError: true,
      );
    }

    final response = error.response;
    if (response != null) {
      final statusCode = response.statusCode;
      dynamic data = response.data;

      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      String message = 'An error occurred (${statusCode ?? "unknown"})';
      Map<String, dynamic>? validationErrors;

      if (data is Map) {
        if (data.containsKey('message') && data['message'] != null) {
          message = data['message'].toString();
        }
        final rawErrors = data['errors'];
        if (rawErrors is Map) {
          try {
            validationErrors = Map<String, dynamic>.from(rawErrors);
          } catch (_) {}
        } else if (rawErrors is List && rawErrors.isNotEmpty) {
          message = rawErrors.map((e) => e.toString()).join('\n');
        }
      }

      // Handle race condition: 409 Conflict (e.g. another driver already accepted)
      if (statusCode == 409) {
        message = message.isEmpty || message.contains('An error occurred')
            ? 'This booking request was already accepted by another ambulance or cancelled.'
            : message;
      } else if (statusCode == 401) {
        if (message.isEmpty || message.contains('An error occurred')) {
          message = 'Incorrect password. Please verify your registered password.';
        }
      } else if (statusCode == 404) {
        if (message.isEmpty || message.contains('An error occurred')) {
          message = 'No registered driver account found for this mobile number.';
        }
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
