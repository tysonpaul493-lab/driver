/// Standardized API exception model
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? validationErrors;
  final bool isNetworkError;

  ApiException({
    required this.message,
    this.statusCode,
    this.validationErrors,
    this.isNetworkError = false,
  });

  @override
  String toString() => message;

  /// Returns user-friendly formatted validation message
  String get firstErrorMessage {
    if (validationErrors != null && validationErrors!.isNotEmpty) {
      final firstKey = validationErrors!.keys.first;
      final val = validationErrors![firstKey];
      if (val is List && val.isNotEmpty) {
        return val.first.toString();
      }
      return val.toString();
    }
    return message;
  }
}
