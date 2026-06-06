import 'package:dio/dio.dart';

import 'api_config.dart';

String describeApiError(Object error) {
  if (error is DioException) {
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      final detail = data['detail'];
      if (detail is String && detail.isNotEmpty) {
        return detail;
      }
    }

    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout ||
        error.type == DioExceptionType.connectionError) {
      return 'Could not connect to the backend at ${ApiConfig.baseUrl}.';
    }

    final statusCode = error.response?.statusCode;
    if (statusCode != null) {
      return 'Request failed with status $statusCode.';
    }
  }

  return 'Something went wrong while talking to the backend.';
}
