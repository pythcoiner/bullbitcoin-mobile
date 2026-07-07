import 'dart:convert';

import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_backend_config.dart';

class KeyValueSpBackendConfigRepository implements SpBackendConfigRepository {
  static const String _storageKey = 'sp_backend_config';

  final KeyValueStorageDatasource<String> _storage;

  KeyValueSpBackendConfigRepository({required this._storage});

  @override
  Future<void> save(SpBackendConfig config) =>
      _storage.saveValue(key: _storageKey, value: jsonEncode(config.toJson()));

  @override
  Future<SpBackendConfig?> fetch() async {
    final jsonString = await _storage.getValue(_storageKey);
    if (jsonString == null || jsonString.isEmpty) return null;
    final json = jsonDecode(jsonString) as Map<String, dynamic>;
    return SpBackendConfig.fromJson(json);
  }

  @override
  Future<void> delete() => _storage.deleteValue(_storageKey);
}
