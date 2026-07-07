import 'dart:io';

import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/application/usecases/fetch_sp_secret_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:path_provider/path_provider.dart';

class CheckSpWalletSetupUsecase {
  final FetchSpSecretUsecase _fetchSpSecretUsecase;
  final SettingsRepository _settingsRepository;
  final SpBackendConfigRepository _configRepository;

  CheckSpWalletSetupUsecase({
    required this._fetchSpSecretUsecase,
    required this._settingsRepository,
    required this._configRepository,
  });

  Future<bool> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      if (settings.isSuperuser != true) return false;
      if (settings.isDevModeEnabled != true) return false;

      final secretBytes = await _fetchSpSecretUsecase.execute();
      if (secretBytes == null) return false;

      // The session is reconstructed from the persisted backend config; with
      // no config there is nothing to reconstruct, so it is not set up. Keep
      // this in sync with `EnsureSpSessionUsecase`.
      final config = await _configRepository.fetch();
      if (config == null) return false;

      // Mirror the repository's sentinel veto: if a prior revoke wrote
      // `.revoked` into the account dir but the recursive delete failed, the
      // wallet is partially-revoked and MUST NOT be considered "set up".
      // Without this check, the GoRouter redirect would see
      // `isSpWalletSetup == true` and let the user into the SP shell, where
      // loading then returns null. Keep both gates in sync.
      final appDocsDir = await getApplicationDocumentsDirectory();
      final sentinelPath =
          '${appDocsDir.path}/${SpConfig.accountName}/${SpConfig.revokedSentinelFile}';
      if (File(sentinelPath).existsSync()) return false;

      return true;
    } catch (e) {
      return false;
    }
  }
}
