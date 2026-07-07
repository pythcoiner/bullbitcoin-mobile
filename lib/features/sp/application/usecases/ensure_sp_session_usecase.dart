import 'dart:io';

import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/application/sp_key_material.dart';
import 'package:bb_mobile/features/sp/application/usecases/fetch_sp_secret_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_wallet.dart';
import 'package:path_provider/path_provider.dart';

/// Establishes the live SP session, reconstructing it via `createFromKeys` from
/// the persisted backend config plus the re-derived secret (the FFI create path
/// never writes a reloadable config file, so `SpAccount.load` cannot be used).
///
/// Returns null when the wallet is not set up: a `.revoked` sentinel is present,
/// no backend config is stored, or no secret is derivable. Reconstruction reuses
/// the on-disk sqlite stores, so balance and history survive.
///
/// Registered as a singleton so the in-flight guard serializes establishment:
/// concurrent callers (the SP shell `load()` and the wallet-side refresh on cold
/// start) share one `createFromKeys` instead of racing two live sessions.
class EnsureSpSessionUsecase {
  final SpAccountRepository _repository;
  final SpBackendConfigRepository _configRepository;
  final FetchSpSecretUsecase _fetchSpSecretUsecase;
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;

  EnsureSpSessionUsecase({
    required this._repository,
    required this._configRepository,
    required this._fetchSpSecretUsecase,
    required this._getDefaultSeedUsecase,
  });

  Future<SpWallet?>? _inFlight;

  Future<SpWallet?> execute() {
    if (_repository.hasSession) return Future.value(_repository.snapshot());
    return _inFlight ??= _establish().whenComplete(() => _inFlight = null);
  }

  Future<SpWallet?> _establish() async {
    final appDocsDir = await getApplicationDocumentsDirectory();
    final accountDir = '${appDocsDir.path}/${SpConfig.accountName}';
    // A `.revoked` sentinel means a prior revoke deleted (or tried to) this
    // wallet; never resurrect it.
    if (File('$accountDir/${SpConfig.revokedSentinelFile}').existsSync()) {
      return null;
    }

    final config = await _configRepository.fetch();
    if (config == null) return null;
    // The BIP85 secret is only the "SP enabled" marker now; SP keys are derived
    // from the mnemonic (BIP352) by bwk. A missing secret means not set up.
    final secret = await _fetchSpSecretUsecase.execute();
    if (secret == null) return null;

    final seed = await _getDefaultSeedUsecase.execute();
    final mnemonic = spMnemonicFromSeed(seed);

    await _repository.createFromMnemonic(
      network: config.network,
      mnemonic: mnemonic,
      blindbitUrl: config.blindbitUrl,
      electrumUrl: config.electrumUrl,
    );
    return _repository.snapshot();
  }
}
