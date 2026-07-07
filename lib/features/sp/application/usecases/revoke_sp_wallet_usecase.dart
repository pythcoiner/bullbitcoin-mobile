import 'dart:io';

import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:path_provider/path_provider.dart';

class RevokeSpWalletUsecase {
  final Bip85Repository _bip85Repository;
  final SpAccountRepository _repository;
  final SpBackendConfigRepository _configRepository;

  RevokeSpWalletUsecase({
    required this._bip85Repository,
    required this._repository,
    required this._configRepository,
  });

  /// Revoke the SP wallet.
  ///
  /// Order of operations matters and is deliberate:
  ///   0. Dispose the live session FIRST (if any). The Rust notification
  ///      thread holds the `account.sqlite` handle; releasing it here is what
  ///      lets the step-3 recursive delete actually succeed instead of failing
  ///      file-locked. `dispose()` rethrows on timeout (a long-running
  ///      lock-holder) with nothing yet revoked, so the toggle stays retriable.
  ///   1. Revoke the BIP85 derivation. This is the step that locks re-setup
  ///      (`CreateSpSecretUsecase` throws `SpDerivationAlreadyExistsError` for
  ///      an active derivation). Performed BEFORE any destructive disk op, so a
  ///      transient failure leaves the artifacts intact — `execute()` is
  ///      idempotent because a second invocation re-fetches derivations and
  ///      only revokes one that's still active.
  ///   2. Write a `.revoked` sentinel inside `{appDocs}/{SpConfig.accountName}`
  ///      so that even if the subsequent `deleteSync` partially fails, the
  ///      repository refuses to ever load that on-disk wallet again.
  ///   3. Recursively delete the account directory. If this throws we rethrow
  ///      so the caller can surface the failure — but the sentinel from step 2
  ///      means the partial state is no longer dangerous.
  ///   4. Emit `SpSetupChanged` so observers (the wallet home) re-evaluate and
  ///      drop the SP card — including on a caught delete failure, since the
  ///      sentinel already makes the wallet unloadable.
  ///
  /// Coordination note: `CreateSpWalletUsecase` clears any stale `.revoked`
  /// sentinel before invoking `createFromKeys`, so a (sentinel + sqlite) combo
  /// left by a failed delete is cleaned up on the next setup.
  Future<void> execute() async {
    // Step 0: tear down the live session so its sqlite handle is released
    // before we try to delete the directory. A dispose timeout must NOT abort
    // the revoke (that left the wallet undeletable): on Android an open handle
    // does not block unlinking, and the `.revoked` sentinel guards a partial
    // delete, so proceed even if dispose fails.
    if (_repository.hasSession) {
      try {
        await _repository.dispose();
      } catch (e) {
        log.warning('RevokeSpWalletUsecase: dispose failed, proceeding: $e');
      }
    }

    // Drop the persisted backend config so the wallet cannot be reconstructed
    // even if a later destructive step fails. A delete failure must not abort
    // the revoke before the sentinel is written, so log and proceed.
    try {
      await _configRepository.delete();
    } catch (e) {
      log.warning('RevokeSpWalletUsecase: config delete failed, proceeding: $e');
    }

    // Step 1: BIP85 revoke. If this throws, no on-disk state has been touched
    // yet, so the next toggle-on can retry from a clean slate.
    final derivations = switch (await _bip85Repository.fetchAll()) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    for (final d in derivations) {
      if (d.application == Bip85Application.hex &&
          d.index == SpConfig.bip85Index) {
        if (d.status == Bip85Status.revoked) {
          break;
        }
        switch (await _bip85Repository.revoke(d)) {
          case Ok():
            break;
          case Err(:final failure):
            throw failure;
        }
        break;
      }
    }

    final appDocsDir = await getApplicationDocumentsDirectory();
    final accountDir = Directory('${appDocsDir.path}/${SpConfig.accountName}');

    if (accountDir.existsSync()) {
      // Step 2: drop sentinel BEFORE attempting the recursive delete.
      try {
        final sentinel = File(
          '${accountDir.path}/${SpConfig.revokedSentinelFile}',
        );
        final timestamp = DateTime.now().toUtc().toIso8601String();
        sentinel.writeAsStringSync('revoked-at: $timestamp\n', flush: true);
      } catch (e, st) {
        log.severe(
          message: 'Failed to write SP revoke sentinel',
          error: e,
          trace: st,
        );
        rethrow;
      }

      // Step 3: attempt recursive delete.
      try {
        accountDir.deleteSync(recursive: true);
      } catch (e, st) {
        log.severe(
          message:
              'Failed to delete SP account directory; sentinel left in '
              'place so wallet will not be loaded',
          error: e,
          trace: st,
        );
        // The recursive delete may have removed the sentinel before failing
        // on a locked child — re-create it so the partial-delete state stays
        // safe for the next launch.
        try {
          if (accountDir.existsSync()) {
            final sentinel = File(
              '${accountDir.path}/${SpConfig.revokedSentinelFile}',
            );
            if (!sentinel.existsSync()) {
              final timestamp = DateTime.now().toUtc().toIso8601String();
              sentinel.writeAsStringSync(
                'revoked-at: $timestamp\n',
                flush: true,
              );
            }
          }
        } catch (sentinelErr, sentinelSt) {
          log.severe(
            message:
                'Failed to re-create SP revoke sentinel after delete '
                'failure; on-disk wallet may be resurrectable',
            error: sentinelErr,
            trace: sentinelSt,
          );
        }
        // Step 4 (failure path): the wallet is unloadable via the sentinel, so
        // observers must still re-evaluate and drop the SP card before we
        // surface the delete error to the caller.
        _repository.notifySetupChanged();
        Error.throwWithStackTrace(e, st);
      }
    }

    // Step 4 (success path): tell observers the wallet is gone.
    _repository.notifySetupChanged();
  }
}
