import 'package:bb_mobile/features/sp/domain/sp_backend_config.dart';

/// Persists the [SpBackendConfig] so the live session can be reconstructed via
/// `createFromKeys` on every load, instead of relying on `SpAccount.load`
/// reading a config file the FFI create path never writes.
abstract class SpBackendConfigRepository {
  Future<void> save(SpBackendConfig config);
  Future<SpBackendConfig?> fetch();
  Future<void> delete();
}
