import 'package:flutter/foundation.dart';

class ApiConfig {
  static const String _baseUrlOverride = String.fromEnvironment(
    'LOCKDIN_API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_baseUrlOverride.isNotEmpty) {
      return _baseUrlOverride;
    }

    if (kIsWeb) {
      final host = Uri.base.host.isEmpty ? 'localhost' : Uri.base.host;
      return 'http://$host:8000';
    }

    return switch (defaultTargetPlatform) {
      TargetPlatform.android => 'http://10.0.2.2:8000',
      _ => 'http://127.0.0.1:8000',
    };
  }
}
