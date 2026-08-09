import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_config.dart';
import 'api_http_adapter_stub.dart'
    if (dart.library.io) 'api_http_adapter_io.dart';

BaseOptions lockdInBaseOptions() => BaseOptions(
  baseUrl: ApiConfig.baseUrl,
  connectTimeout: const Duration(seconds: 5),
  receiveTimeout: const Duration(seconds: 10),
  sendTimeout: const Duration(seconds: 10),
  headers: const {
    'Accept': 'application/json',
    'Content-Type': 'application/json',
  },
);

Dio createLockdInDio() {
  final dio = Dio(lockdInBaseOptions());
  configurePlatformHttpAdapter(dio);
  return dio;
}

final publicDioProvider = Provider<Dio>((ref) => createLockdInDio());
