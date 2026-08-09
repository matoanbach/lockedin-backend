import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lockdin_app/core/api/api_client.dart';

void main() {
  test('a 401 refreshes once and retries the request once', () async {
    final adapter = SequenceAdapter([401, 200]);
    final dio = Dio()..httpClientAdapter = adapter;
    var token = 'initial';
    final forced = <bool>[];
    var terminal = false;
    dio.interceptors.add(
      BoundedAuthInterceptor(
        dio: dio,
        tokenProvider: ({bool forceRefresh = false}) async {
          forced.add(forceRefresh);
          if (forceRefresh) token = 'rotated';
          return token;
        },
        onTerminalAuthFailure: () => terminal = true,
      ),
    );

    final response = await dio.get<Object>('/protected');

    expect(response.statusCode, 200);
    expect(adapter.calls, 2);
    expect(adapter.authorizations, ['Bearer initial', 'Bearer rotated']);
    expect(forced.where((value) => value), hasLength(1));
    expect(terminal, isFalse);
  });

  test('a repeated 401 is not retried again', () async {
    final adapter = SequenceAdapter([401, 401, 200]);
    final dio = Dio()..httpClientAdapter = adapter;
    var terminal = false;
    dio.interceptors.add(
      BoundedAuthInterceptor(
        dio: dio,
        tokenProvider: ({bool forceRefresh = false}) async =>
            forceRefresh ? 'rotated' : 'initial',
        onTerminalAuthFailure: () => terminal = true,
      ),
    );

    await expectLater(
      dio.get<Object>('/protected'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.calls, 2);
    expect(terminal, isTrue);
  });

  test('refresh failure enters terminal auth state without a retry', () async {
    final adapter = SequenceAdapter([401, 200]);
    final dio = Dio()..httpClientAdapter = adapter;
    var terminal = false;
    dio.interceptors.add(
      BoundedAuthInterceptor(
        dio: dio,
        tokenProvider: ({bool forceRefresh = false}) async {
          if (forceRefresh) throw StateError('refresh rejected');
          return 'initial';
        },
        onTerminalAuthFailure: () => terminal = true,
      ),
    );

    await expectLater(
      dio.get<Object>('/protected'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.calls, 1);
    expect(terminal, isTrue);
  });

  test('provider 503 is never treated as a refresh signal', () async {
    final adapter = SequenceAdapter([503, 200]);
    final dio = Dio()..httpClientAdapter = adapter;
    var forcedRefreshes = 0;
    var terminal = false;
    dio.interceptors.add(
      BoundedAuthInterceptor(
        dio: dio,
        tokenProvider: ({bool forceRefresh = false}) async {
          if (forceRefresh) forcedRefreshes += 1;
          return 'initial';
        },
        onTerminalAuthFailure: () => terminal = true,
      ),
    );

    await expectLater(
      dio.get<Object>('/protected'),
      throwsA(isA<DioException>()),
    );

    expect(adapter.calls, 1);
    expect(forcedRefreshes, 0);
    expect(terminal, isFalse);
  });
}

class SequenceAdapter implements HttpClientAdapter {
  SequenceAdapter(this.statuses);

  final List<int> statuses;
  final List<String?> authorizations = [];
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    authorizations.add(options.headers['Authorization'] as String?);
    final status = statuses[calls++];
    return ResponseBody.fromString(
      '{}',
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}
