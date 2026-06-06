import 'package:dio/dio.dart';

import 'preferences_models.dart';

class PreferencesRepository {
  PreferencesRepository(this._dio);

  final Dio _dio;

  Future<AppPreferences> fetchPreferences() async {
    final response = await _dio.get('/api/v1/me/preferences');
    return AppPreferences.fromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<AppPreferences> updatePreferences(Map<String, dynamic> payload) async {
    final response = await _dio.put('/api/v1/me/preferences', data: payload);
    return AppPreferences.fromJson(Map<String, dynamic>.from(response.data as Map));
  }
}
