import 'dart:io';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/features/sp/application/application_errors.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/application/usecases/create_sp_secret_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:path_provider/path_provider.dart';

/// Orchestrates SP wallet creation for the setup flow: derive keys (gated),
/// clear any stale revoked state, then create the on-disk account.
class CreateSpWalletUsecase {
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;
  final CreateSpSecretUsecase _createSpSecretUsecase;
  final SpAccountRepository _repository;
  final SpBackendConfigRepository _configRepository;

  CreateSpWalletUsecase({
    required this._getDefaultSeedUsecase,
    required this._createSpSecretUsecase,
    required this._repository,
    required this._configRepository,
  });

  Future<void> execute({
    required SpNetwork network,
    required String blindbitUrl,
    required String electrumUrl,
  }) async {
    final seed = await _getDefaultSeedUsecase.execute();
    if (seed is! MnemonicSeed) {
      throw SpSetupRequiresMnemonicError(
        'SP setup requires a mnemonic-backed seed; got ${seed.runtimeType}',
      );
    }
    final mnemonic = seed.mnemonicWords.join(' ');

    // CRITICAL ORDERING: clear any stale `.revoked` sentinel BEFORE deriving
    // the secret. If a prior revoke's recursive delete failed, the dir may
    // still hold a stale account.sqlite + sentinel. `GetSpWalletUsecase`
    // vetoes loads while the sentinel exists, so leaving it would make setup
    // "succeed" yet be unreachable. Doing cleanup before
    // `CreateSpSecretUsecase` ensures a cleanup failure surfaces WITHOUT
    // having reactivated the BIP85 derivation (which would wedge re-setup).
    final appDocsDir = await getApplicationDocumentsDirectory();
    final accountDir = Directory('${appDocsDir.path}/${SpConfig.accountName}');
    final sentinel = File(
      '${accountDir.path}/${SpConfig.revokedSentinelFile}',
    );
    if (sentinel.existsSync()) {
      try {
        accountDir.deleteSync(recursive: true);
      } catch (e) {
        throw SpSetupCleanupFailedError(
          'Failed to clear stale SP wallet state on setup: $e',
        );
      }
    }

    // Create the BIP85 derivation as the "SP enabled" marker (gates setup/load).
    // SP keys themselves are derived from the mnemonic (BIP352) by bwk.
    await _createSpSecretUsecase.execute(defaultSeed: seed);

    await _repository.createFromMnemonic(
      network: network,
      mnemonic: mnemonic,
      blindbitUrl: blindbitUrl,
      electrumUrl: electrumUrl,
    );
    // Persist the backend config so the session can be reconstructed on every
    // later load (the FFI create path writes no reloadable config file).
    await _configRepository.save(
      SpBackendConfig(
        network: network,
        blindbitUrl: blindbitUrl,
        electrumUrl: electrumUrl,
      ),
    );
  }
}
