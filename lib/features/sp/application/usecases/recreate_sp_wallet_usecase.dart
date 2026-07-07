import 'dart:io';

import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/features/sp/application/application_errors.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/application/sp_key_material.dart';
import 'package:bb_mobile/features/sp/application/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/fetch_sp_secret_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:path_provider/path_provider.dart';

class RecreateSpWalletUsecase {
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;
  final FetchSpSecretUsecase _fetchSpSecretUsecase;
  final SpAccountRepository _repository;
  final SpBackendConfigRepository _configRepository;
  final EnsureSpSessionUsecase _ensureSpSessionUsecase;

  RecreateSpWalletUsecase(
    this._getDefaultSeedUsecase,
    this._fetchSpSecretUsecase,
    this._repository,
    this._configRepository,
    this._ensureSpSessionUsecase,
  );

  Future<void> execute({
    required SpNetwork network,
    required String blindbitUrl,
    required String electrumUrl,
  }) async {
    final seed = await _getDefaultSeedUsecase.execute();
    // The BIP85 secret is only the "SP enabled" marker now; SP keys come from
    // the mnemonic (BIP352) via bwk.
    final secret = await _fetchSpSecretUsecase.execute();
    if (secret == null) {
      throw const SpNotSetUpError('SP wallet secret not found');
    }
    final mnemonic = spMnemonicFromSeed(seed);

    await _repository.dispose();

    final appDocsDir = await getApplicationDocumentsDirectory();
    final accountDir = Directory('${appDocsDir.path}/${SpConfig.accountName}');
    final backupDir = Directory(
      '${accountDir.path}.backup-${DateTime.now().microsecondsSinceEpoch}',
    );

    var hasBackup = false;
    if (accountDir.existsSync()) {
      accountDir.renameSync(backupDir.path);
      hasBackup = true;
    }

    try {
      await _repository.createFromMnemonic(
        network: network,
        mnemonic: mnemonic,
        blindbitUrl: blindbitUrl,
        electrumUrl: electrumUrl,
      );
      await _configRepository.save(
        SpBackendConfig(
          network: network,
          blindbitUrl: blindbitUrl,
          electrumUrl: electrumUrl,
        ),
      );
    } catch (_) {
      await _repository.dispose();
      if (accountDir.existsSync()) {
        accountDir.deleteSync(recursive: true);
      }
      if (hasBackup && backupDir.existsSync()) {
        backupDir.renameSync(accountDir.path);
        // The stored config still points at the old backend, so reconstruct
        // the previous session from the restored directory.
        await _ensureSpSessionUsecase.execute();
      }
      rethrow;
    }

    if (hasBackup && backupDir.existsSync()) {
      try {
        backupDir.deleteSync(recursive: true);
      } on FileSystemException {
        // The active recreated wallet is already installed. A stale backup
        // directory is harmless and can be cleaned manually.
      }
    }
  }
}
