import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';
import 'package:flutter/foundation.dart';

const String _debugCaBase64 = String.fromEnvironment(
  'LOCKDIN_DEBUG_CA_BASE64',
  defaultValue: '',
);

void configurePlatformHttpAdapter(Dio dio) {
  if (!kDebugMode || _debugCaBase64.isEmpty) {
    return;
  }

  final context = SecurityContext(withTrustedRoots: true);
  context.setTrustedCertificatesBytes(base64Decode(_debugCaBase64));
  dio.httpClientAdapter = IOHttpClientAdapter(
    createHttpClient: () => HttpClient(context: context),
  );
}
