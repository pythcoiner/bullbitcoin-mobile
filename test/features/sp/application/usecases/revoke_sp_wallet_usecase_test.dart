import 'dart:io';

import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/application/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBip85Repository extends Mock implements Bip85Repository {}

class MockSpAccountRepository extends Mock implements SpAccountRepository {}

class MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

Bip85DerivationEntity _makeDerivation({
  required Bip85Status status,
  Bip85Application application = Bip85Application.hex,
  int index = SpConfig.bip85Index,
}) => Bip85DerivationEntity(
  path: "m/83696968'/128169'/${SpConfig.bip85Length}'/$index'",
  xprvFingerprint: 'test',
  alias: null,
  status: status,
  application: application,
  index: index,
);

void main() {
  late MockBip85Repository bip85Repo;
  late MockSpAccountRepository accountRepo;
  late MockSpBackendConfigRepository configRepo;
  late RevokeSpWalletUsecase usecase;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(_makeDerivation(status: Bip85Status.active));
  });

  setUp(() {
    bip85Repo = MockBip85Repository();
    accountRepo = MockSpAccountRepository();
    configRepo = MockSpBackendConfigRepository();
    // Default: no live session (so revoke skips dispose unless a test opts in).
    when(() => accountRepo.hasSession).thenReturn(false);
    when(() => accountRepo.dispose()).thenAnswer((_) async {});
    when(() => accountRepo.notifySetupChanged()).thenReturn(null);
    when(() => configRepo.delete()).thenAnswer((_) async {});
    usecase = RevokeSpWalletUsecase(
      bip85Repository: bip85Repo,
      repository: accountRepo,
      configRepository: configRepo,
    );
    tempDir = Directory.systemTemp.createTempSync('sp_revoke_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          return tempDir.path;
        });
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      try {
        tempDir.deleteSync(recursive: true);
      } catch (_) {
        // best-effort cleanup; some tests intentionally leave locked state
      }
    }
  });

  group('RevokeSpWalletUsecase', () {
    test(
      'A: calls revoke exactly once when hex derivation at index 352 exists',
      () async {
        final derivation = _makeDerivation(status: Bip85Status.active);
        when(() => bip85Repo.fetchAll()).thenAnswer(
          (_) async => Ok<List<Bip85DerivationEntity>, Bip85Failure>([
            derivation,
          ]),
        );
        when(() => bip85Repo.revoke(derivation)).thenAnswer(
          (_) async => const Ok<void, Bip85Failure>(null),
        );

        await usecase.execute();

        verify(() => bip85Repo.revoke(derivation)).called(1);
        // The persisted backend config is dropped so the wallet cannot be
        // reconstructed after revoke.
        verify(() => configRepo.delete()).called(1);
      },
    );

    test(
      'B: completes without calling revoke when no derivation exists',
      () async {
        when(() => bip85Repo.fetchAll()).thenAnswer(
          (_) async => const Ok<List<Bip85DerivationEntity>, Bip85Failure>([]),
        );

        await usecase.execute();

        verifyNever(() => bip85Repo.revoke(any()));
      },
    );

    test(
      'B: does not call revoke for non-hex or different-index derivations',
      () async {
        final otherDerivation = _makeDerivation(
          status: Bip85Status.active,
          index: 11811, // Ark index
        );
        when(
          () => bip85Repo.fetchAll(),
        ).thenAnswer(
          (_) async => Ok<List<Bip85DerivationEntity>, Bip85Failure>([
            otherDerivation,
          ]),
        );

        await usecase.execute();

        verifyNever(() => bip85Repo.revoke(any()));
      },
    );

    test('C: BIP85 revoke runs BEFORE sentinel/delete; on success the whole '
        'account dir is removed', () async {
      // Pre-create the account dir + a dummy account.sqlite that would
      // otherwise be loaded by GetSpWalletUsecase.
      final accountDir = Directory('${tempDir.path}/${SpConfig.accountName}')
        ..createSync();
      File('${accountDir.path}/account.sqlite').writeAsStringSync('db');

      final derivation = _makeDerivation(status: Bip85Status.active);
      when(() => bip85Repo.fetchAll()).thenAnswer(
        (_) async => Ok<List<Bip85DerivationEntity>, Bip85Failure>([
          derivation,
        ]),
      );

      // Record whether the sentinel/dir still existed at the moment
      // bip85Repo.revoke was invoked. With the revoke ordering, BIP85 revoke
      // runs FIRST, so the account dir is still intact and the sentinel
      // has NOT been written yet.
      var dirExistedAtRevoke = false;
      var sentinelExistedAtRevoke = false;
      when(() => bip85Repo.revoke(derivation)).thenAnswer((_) async {
        dirExistedAtRevoke = accountDir.existsSync();
        sentinelExistedAtRevoke = File(
          '${accountDir.path}/${SpConfig.revokedSentinelFile}',
        ).existsSync();
        return const Ok<void, Bip85Failure>(null);
      });

      await usecase.execute();

      expect(
        dirExistedAtRevoke,
        isTrue,
        reason: 'account dir must still exist when BIP85 revoke runs',
      );
      expect(
        sentinelExistedAtRevoke,
        isFalse,
        reason: 'sentinel must not be written before BIP85 revoke',
      );

      // After a successful run the whole dir is gone.
      expect(accountDir.existsSync(), isFalse);

      // Observers are notified so the wallet drops the SP card.
      verify(() => accountRepo.notifySetupChanged()).called(1);
    });

    test('D: when recursive delete fails, BIP85 revoke is already done, '
        'sentinel remains, and the delete error is rethrown', () async {
      // Build an account dir whose contents we can lock against deletion by
      // making a child dir read-only. On POSIX systems, removing a file
      // from a read-only dir fails with EACCES, which makes deleteSync
      // throw — exactly the partial-delete scenario we care about. We
      // restore perms in a tearDown-safe way.
      final accountDir = Directory('${tempDir.path}/${SpConfig.accountName}')
        ..createSync();
      final lockedSubdir = Directory('${accountDir.path}/locked')..createSync();
      File('${lockedSubdir.path}/account.sqlite').writeAsStringSync('db');
      // Strip write permission from the subdir so its contents can't be
      // removed.
      final chmod = await Process.run('chmod', ['-w', lockedSubdir.path]);
      // If chmod is unavailable (unlikely on Linux CI), skip the rest.
      if (chmod.exitCode != 0) {
        return;
      }
      addTearDown(() async {
        await Process.run('chmod', ['+w', lockedSubdir.path]);
      });

      final derivation = _makeDerivation(status: Bip85Status.active);
      when(() => bip85Repo.fetchAll()).thenAnswer(
        (_) async => Ok<List<Bip85DerivationEntity>, Bip85Failure>([
          derivation,
        ]),
      );
      when(() => bip85Repo.revoke(derivation)).thenAnswer(
        (_) async => const Ok<void, Bip85Failure>(null),
      );

      Object? caught;
      try {
        await usecase.execute();
      } catch (e) {
        caught = e;
      }

      // 1) The delete error must propagate.
      expect(
        caught,
        isNotNull,
        reason: 'revoke must rethrow when recursive delete fails',
      );

      // 2) BIP85 revoke must have happened FIRST (before the failed delete).
      verify(() => bip85Repo.revoke(derivation)).called(1);

      // 3) The sentinel must have been written BEFORE the delete attempt,
      // so it survives a partial-delete state. This is the load-bearing
      // invariant: GetSpWalletUsecase keys off this file.
      final sentinel = File('${accountDir.path}/${SpConfig.revokedSentinelFile}');
      expect(
        sentinel.existsSync(),
        isTrue,
        reason: 'sentinel must exist even when delete fails',
      );

      // Even on the failure path the wallet must drop the SP card (the
      // sentinel already makes the wallet unloadable).
      verify(() => accountRepo.notifySetupChanged()).called(1);
    });

    test('E: when BIP85 revoke throws, no sentinel is written, no delete is '
        'attempted, and the BIP85 error is rethrown', () async {
      // Pre-create the account dir + sqlite. After a failed BIP85 revoke,
      // these MUST still exist so the user can retry from a clean state.
      final accountDir = Directory('${tempDir.path}/${SpConfig.accountName}')
        ..createSync();
      final sqliteFile = File('${accountDir.path}/account.sqlite')
        ..writeAsStringSync('db');

      final derivation = _makeDerivation(status: Bip85Status.active);
      when(() => bip85Repo.fetchAll()).thenAnswer(
        (_) async => Ok<List<Bip85DerivationEntity>, Bip85Failure>([
          derivation,
        ]),
      );
      const bip85Error = Bip85UnexpectedFailure('bip85 db transient failure');
      when(() => bip85Repo.revoke(derivation)).thenAnswer(
        (_) async => const Err<void, Bip85Failure>(bip85Error),
      );

      Object? caught;
      try {
        await usecase.execute();
      } catch (e) {
        caught = e;
      }

      // 1) The BIP85 error must propagate.
      expect(
        caught,
        same(bip85Error),
        reason: 'revoke must rethrow the BIP85 failure',
      );

      // 2) No destructive disk operation should have happened.
      expect(
        accountDir.existsSync(),
        isTrue,
        reason: 'account dir must NOT be deleted when BIP85 revoke fails',
      );
      expect(
        sqliteFile.existsSync(),
        isTrue,
        reason: 'sqlite must NOT be deleted when BIP85 revoke fails',
      );

      // 3) No sentinel should have been written — the next retry must start
      // from a fully intact on-disk state.
      final sentinel = File('${accountDir.path}/${SpConfig.revokedSentinelFile}');
      expect(
        sentinel.existsSync(),
        isFalse,
        reason: 'sentinel must NOT be written before BIP85 revoke succeeds',
      );
    });

    test(
      'F: re-running execute() after a BIP85 revoke failure is idempotent: '
      'second call succeeds, sentinel + delete happen, no double-revoke',
      () async {
        final accountDir = Directory('${tempDir.path}/${SpConfig.accountName}')
          ..createSync();
        File('${accountDir.path}/account.sqlite').writeAsStringSync('db');

        final activeDerivation = _makeDerivation(status: Bip85Status.active);
        final revokedDerivation = _makeDerivation(status: Bip85Status.revoked);

        // First call: fetchAll returns active, but revoke throws.
        // Second call: fetchAll returns the (now-)revoked derivation, so the
        // usecase skips calling revoke again and proceeds to disk cleanup.
        var callCount = 0;
        when(() => bip85Repo.fetchAll()).thenAnswer((_) async {
          callCount++;
          return Ok<List<Bip85DerivationEntity>, Bip85Failure>(
            callCount == 1 ? [activeDerivation] : [revokedDerivation],
          );
        });
        when(
          () => bip85Repo.revoke(activeDerivation),
        ).thenAnswer(
          (_) async =>
              const Err<void, Bip85Failure>(
                Bip85UnexpectedFailure('transient'),
              ),
        );

        // First call fails.
        Object? firstError;
        try {
          await usecase.execute();
        } catch (e) {
          firstError = e;
        }
        expect(firstError, isNotNull);
        expect(
          accountDir.existsSync(),
          isTrue,
          reason: 'first failure must leave disk intact',
        );

        // Second call succeeds: no revoke attempt on already-revoked derivation,
        // sentinel + delete happen.
        await usecase.execute();

        // revoke must have been called exactly once across both runs (only on
        // the first, active derivation; never on the already-revoked one).
        verify(() => bip85Repo.revoke(activeDerivation)).called(1);
        verifyNever(() => bip85Repo.revoke(revokedDerivation));

        // Account dir is gone after the successful second run.
        expect(accountDir.existsSync(), isFalse);
      },
    );

    test('G: disposes the live session BEFORE deleting the account dir so the '
        'sqlite handle is released', () async {
      final accountDir = Directory('${tempDir.path}/${SpConfig.accountName}')
        ..createSync();
      File('${accountDir.path}/account.sqlite').writeAsStringSync('db');

      when(() => accountRepo.hasSession).thenReturn(true);

      final derivation = _makeDerivation(status: Bip85Status.active);
      when(() => bip85Repo.fetchAll()).thenAnswer(
        (_) async => Ok<List<Bip85DerivationEntity>, Bip85Failure>([
          derivation,
        ]),
      );

      // Capture whether the account dir still existed when dispose ran — it
      // must (dispose precedes the delete).
      var dirExistedAtDispose = false;
      when(() => accountRepo.dispose()).thenAnswer((_) async {
        dirExistedAtDispose = accountDir.existsSync();
      });
      when(() => bip85Repo.revoke(derivation)).thenAnswer(
        (_) async => const Ok<void, Bip85Failure>(null),
      );

      await usecase.execute();

      expect(
        dirExistedAtDispose,
        isTrue,
        reason: 'dispose must run before the recursive delete',
      );
      // Ordering: dispose (step 0) precedes BIP85 revoke (step 1) and the
      // setup-changed notification (step 4).
      verifyInOrder([
        () => accountRepo.dispose(),
        () => bip85Repo.revoke(derivation),
        () => accountRepo.notifySetupChanged(),
      ]);
      expect(accountDir.existsSync(), isFalse);
    });
  });
}
