import 'package:dio/dio.dart';
import '../storage/secure_storage_service.dart';

/// Dio Interceptor that automatically attaches Laravel Sanctum Bearer tokens
/// and intercepts 401 Unauthorized responses to trigger clean logout.
class AuthInterceptor extends Interceptor {
  final SecureStorageService _storageService;
  final void Function()? onUnauthorized;

  AuthInterceptor(this._storageService, {this.onUnauthorized});

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    options.headers['Accept'] = 'application/json';
    options.headers['X-Requested-With'] = 'XMLHttpRequest';

    // Retrieve Sanctum bearer token if present
    final token = await _storageService.getAuthToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    final path = err.requestOptions.path;
    final isAuthEndpoint = path.contains('/auth/');
    if (err.response?.statusCode == 401 && !isAuthEndpoint) {
      // Sanctum token expired or revoked
      onUnauthorized?.call();
    }
    return handler.next(err);
  }
}
