import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_client.dart';
import '../../../shared/models/models.dart';

final accountabilityRepositoryProvider =
    Provider<AccountabilityRepository>((ref) {
  return AccountabilityRepository(ref.watch(dioProvider));
});

final accountabilityPartnersProvider = AsyncNotifierProvider<
    AccountabilityPartnersController,
    List<AccountabilityPartner>>(AccountabilityPartnersController.new);

class AccountabilityPartnersController
    extends AsyncNotifier<List<AccountabilityPartner>> {
  AccountabilityRepository get _repository =>
      ref.read(accountabilityRepositoryProvider);

  @override
  Future<List<AccountabilityPartner>> build() {
    return _repository.listPartners();
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(_repository.listPartners);
  }

  Future<void> addPartner(String email) async {
    await _repository.createPartner(email);
    await refresh();
  }

  Future<void> removePartner(String partnerId) async {
    await _repository.deletePartner(partnerId);
    await refresh();
  }
}

class AccountabilityRepository {
  AccountabilityRepository(this._dio);

  final Dio _dio;

  Future<List<AccountabilityPartner>> listPartners() async {
    final response = await _dio.get('/api/v1/accountability/contacts');
    final data = response.data as List<dynamic>;

    return data
        .map((item) => _partnerFromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  Future<AccountabilityPartner> createPartner(String email) async {
    final response = await _dio.post(
      '/api/v1/accountability/contacts',
      data: {'email': email},
    );

    return _partnerFromJson(Map<String, dynamic>.from(response.data as Map));
  }

  Future<void> deletePartner(String partnerId) async {
    await _dio.delete('/api/v1/accountability/contacts/$partnerId');
  }
}

AccountabilityPartner _partnerFromJson(Map<String, dynamic> json) {
  return AccountabilityPartner(
    id: json['id'] as String,
    name: json['name'] as String,
    email: json['email'] as String,
  );
}
