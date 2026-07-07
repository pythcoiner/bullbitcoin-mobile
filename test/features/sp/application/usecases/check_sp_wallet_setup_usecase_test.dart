import 'dart:io';

import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/application/usecases/check_sp_wallet_setup_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/fetch_sp_secret_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/get_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockFetchSpSecretUsecase extends Mock implements FetchSpSecretUsecase {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

class MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

class MockEnsureSpSessionUsecase extends Mock
    implements EnsureSpSessionUsecase {}

SettingsEntity _makeSettings({
  bool? isSuperuser,
  bool? isDevModeEnabled = true,
}) =>
    const SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'CAD',
      isSuperuser: null,
    ).copyWith(
      isSuperuser: isSuperuser,
      isDevModeEnabled: isDevModeEnabled,
    );

SpBackendConfig _config() => const SpBackendConfig(
  network: SpNetwork.regtest,
  blindbitUrl: 'http://blindbit.example',
  electrumUrl: 'tcp://electrum.example:50001',
);

void main() {
  late MockFetchSpSecretUsecase fetchSpSecretUsecase;
  late MockSettingsRepository settingsRepo;
  late MockSpBackendConfigRepository configRepo;
  late CheckSpWalletSetupUsecase usecase;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  setUp(() {
    fetchSpSecretUsecase = MockFetchSpSecretUsecase();
    settingsRepo = MockSettingsRepository();
    configRepo = MockSpBackendConfigRepository();
    when(() => configRepo.fetch()).thenAnswer((_) async => _config());
    usecase = CheckSpWalletSetupUsecase(
      fetchSpSecretUsecase: fetchSpSecretUsecase,
      settingsRepository: settingsRepo,
      configRepository: configRepo,
    );

    tempDir = Directory.systemTemp.createTempSync('sp_check_setup_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      return tempDir.path;
    });
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('CheckSpWalletSetupUsecase', () {
    test('A: returns false when isSuperuser is not true', () async {
      when(() => settingsRepo.fetch())
          .thenAnswer((_) async => _makeSettings(isSuperuser: false));

      final result = await usecase.execute();

      expect(result, isFalse);
      verifyNever(() => fetchSpSecretUsecase.execute());
    });

    test('A2: returns false when isDevModeEnabled is not true', () async {
      when(() => settingsRepo.fetch()).thenAnswer(
        (_) async => _makeSettings(isSuperuser: true, isDevModeEnabled: false),
      );

      final result = await usecase.execute();

      expect(result, isFalse);
      verifyNever(() => fetchSpSecretUsecase.execute());
    });

    test('B: returns false when fetch returns null', () async {
      when(() => settingsRepo.fetch())
          .thenAnswer((_) async => _makeSettings(isSuperuser: true));
      when(() => fetchSpSecretUsecase.execute()).thenAnswer((_) async => null);

      final result = await usecase.execute();

      expect(result, isFalse);
    });

    test('B2: returns false when no backend config is stored', () async {
      when(() => settingsRepo.fetch())
          .thenAnswer((_) async => _makeSettings(isSuperuser: true));
      when(() => fetchSpSecretUsecase.execute())
          .thenAnswer((_) async => List.filled(64, 0));
      when(() => configRepo.fetch()).thenAnswer((_) async => null);

      final result = await usecase.execute();

      expect(result, isFalse);
    });

    test('C: returns true when superuser, secret and config are all present',
        () async {
      when(() => settingsRepo.fetch())
          .thenAnswer((_) async => _makeSettings(isSuperuser: true));
      when(() => fetchSpSecretUsecase.execute())
          .thenAnswer((_) async => List.filled(64, 0));

      final result = await usecase.execute();

      expect(result, isTrue);
    });

    test('D: returns false when an exception is thrown internally', () async {
      when(() => settingsRepo.fetch()).thenThrow(Exception('unexpected'));

      final result = await usecase.execute();

      expect(result, isFalse);
    });

    test(
      'E: returns false when .revoked sentinel is present even if BIP85 '
      'derivation + superuser + dev mode + config are all set',
      () async {
        when(() => settingsRepo.fetch())
            .thenAnswer((_) async => _makeSettings(isSuperuser: true));
        when(() => fetchSpSecretUsecase.execute())
            .thenAnswer((_) async => List<int>.filled(64, 0xAB));

        final accountDir = Directory('${tempDir.path}/${SpConfig.accountName}')
          ..createSync();
        File('${accountDir.path}/${SpConfig.revokedSentinelFile}')
            .writeAsStringSync('revoked-at: 2026-01-01T00:00:00Z');

        final result = await usecase.execute();

        expect(result, isFalse,
            reason:
                'sentinel must veto "is set up" even with full credentials');
      },
    );
  });

  group('gate consistency (CheckSpWalletSetupUsecase vs GetSpWalletUsecase)',
      () {
    test(
      'with .revoked sentinel present, BOTH usecases treat the wallet as '
      'not-set-up',
      () async {
        when(() => settingsRepo.fetch())
            .thenAnswer((_) async => _makeSettings(isSuperuser: true));
        when(() => fetchSpSecretUsecase.execute())
            .thenAnswer((_) async => List<int>.filled(64, 0xAB));

        // Lay down a partially-revoked account dir: sqlite still present
        // (delete failed) + sentinel present.
        final accountDir = Directory('${tempDir.path}/${SpConfig.accountName}')
          ..createSync();
        File('${accountDir.path}/account.sqlite').writeAsStringSync('db');
        File('${accountDir.path}/${SpConfig.revokedSentinelFile}')
            .writeAsStringSync('revoked-at: 2026-01-01T00:00:00Z');

        final checkUsecase = CheckSpWalletSetupUsecase(
          fetchSpSecretUsecase: fetchSpSecretUsecase,
          settingsRepository: settingsRepo,
          configRepository: configRepo,
        );
        // GetSpWalletUsecase establishes the session via EnsureSpSessionUsecase,
        // which honours the sentinel veto. Mirror that here: with the sentinel
        // present, ensure returns null.
        final ensureSpSession = MockEnsureSpSessionUsecase();
        when(() => ensureSpSession.execute()).thenAnswer((_) async => null);
        final getUsecase = GetSpWalletUsecase(
          ensureSpSessionUsecase: ensureSpSession,
          settingsRepository: settingsRepo,
        );

        final isSetUp = await checkUsecase.execute();
        final wallet = await getUsecase.execute();

        expect(isSetUp, isFalse,
            reason: 'CheckSpWalletSetupUsecase must honour sentinel');
        expect(wallet, isNull,
            reason: 'GetSpWalletUsecase must honour sentinel');
      },
    );
  });
}
