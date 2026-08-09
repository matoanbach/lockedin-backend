import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_provider.dart';
import 'api_transport.dart';

final dioProvider = Provider<Dio>((ref) {
  final dio = createLockdInDio();
  dio.interceptors.add(
    BoundedAuthInterceptor(
      dio: dio,
      tokenProvider: ({bool forceRefresh = false}) => ref
          .read(authControllerProvider.notifier)
          .accessToken(forceRefresh: forceRefresh),
      onTerminalAuthFailure: () =>
          ref.read(authControllerProvider.notifier).requireReauthentication(),
    ),
  );
  return dio;
});

typedef AccessTokenProvider = Future<String> Function({bool forceRefresh});

class BoundedAuthInterceptor extends Interceptor {
  BoundedAuthInterceptor({
    required this.dio,
    required this.tokenProvider,
    required this.onTerminalAuthFailure,
  });

  final Dio dio;
  final AccessTokenProvider tokenProvider;
  final void Function() onTerminalAuthFailure;

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    try {
      final token = await tokenProvider(forceRefresh: false);
      options.headers['Authorization'] = 'Bearer $token';
      handler.next(options);
    } catch (error, stackTrace) {
      handler.reject(
        DioException(
          requestOptions: options,
          error: error,
          stackTrace: stackTrace,
          type: DioExceptionType.cancel,
        ),
      );
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final alreadyRetried = err.requestOptions.extra['authRetried'] == true;
    if (err.response?.statusCode != 401 || alreadyRetried) {
      handler.next(err);
      return;
    }
    try {
      final token = await tokenProvider(forceRefresh: true);
      final request = err.requestOptions;
      request.extra['authRetried'] = true;
      request.headers['Authorization'] = 'Bearer $token';
      handler.resolve(await dio.fetch<Object?>(request));
    } catch (_) {
      onTerminalAuthFailure();
      handler.next(err);
    }
  }
}
