import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'auth_models.dart';

abstract interface class AuthStorage {
  Future<StoredAuthSession?> readSession();
  Future<void> writeSession(StoredAuthSession session);
  Future<void> deleteSession();
  Future<Map<String, String>> readAccountBindings();
  Future<void> writeAccountBindings(Map<String, String> bindings);
}

class SecureAuthStorage implements AuthStorage {
  SecureAuthStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            aOptions: AndroidOptions(storageNamespace: 'lockdin_auth'),
          );

  final FlutterSecureStorage _storage;

  @override
  Future<StoredAuthSession?> readSession() async {
    final raw = await _storage.read(key: _sessionKey);
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      return StoredAuthSession.fromJson(
        Map<String, dynamic>.from(jsonDecode(raw) as Map),
      );
    } on Object {
      await deleteSession();
      return null;
    }
  }

  @override
  Future<void> writeSession(StoredAuthSession session) {
    return _storage.write(
      key: _sessionKey,
      value: jsonEncode(session.toJson()),
    );
  }

  @override
  Future<void> deleteSession() => _storage.delete(key: _sessionKey);

  @override
  Future<Map<String, String>> readAccountBindings() async {
    final raw = await _storage.read(key: _bindingsKey);
    if (raw == null || raw.isEmpty) {
      return <String, String>{};
    }
    try {
      final decoded = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      return decoded.map((key, value) => MapEntry(key, value as String));
    } on Object {
      return <String, String>{};
    }
  }

  @override
  Future<void> writeAccountBindings(Map<String, String> bindings) {
    return _storage.write(key: _bindingsKey, value: jsonEncode(bindings));
  }

  static const String _sessionKey = 'current_session_v1';
  static const String _bindingsKey = 'account_bindings_v1';
}
