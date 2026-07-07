import 'dart:io';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/features/sp/application/application_errors.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/application/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/fetch_sp_secret_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_wallet.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSpAccountRepository extends Mock implements SpAccountRepository {}

class _MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

class _MockFetchSpSecretUsecase extends Mock implements FetchSpSecretUsecase {}

class _MockGetDefaultSeedUsecase extends Mock
    implements GetDefaultSeedUsecase {}

MnemonicSeed _mnemonicSeed() => MnemonicSeed(
  mnemonicWords: List.filled(12, 'abandon'),
  bytes: Uint8List.fromList(List.filled(64, 1)),
  masterFingerprint: 'f23f9fd2',
);

BytesSeed _bytesSeed() => BytesSeed(
  bytes: Uint8List.fromList(List.filled(64, 1)),
  masterFingerprint: 'f23f9fd2',
);

List<int> _secret() => List<int>.generate(64, (index) => index);

SpBackendConfig _config() => const SpBackendConfig(
  network: SpNetwork.regtest,
  blindbitUrl: 'http://blindbit.example',
  electrumUrl: 'tcp://electrum.example:50001',
);

SpWallet _wallet() => SpWallet(
  spAddress: 'sp1qexample',
  balance: SpBalance(
    confirmedSat: BigInt.from(10),
    totalUnifiedSat: BigInt.from(20),
  ),
  isScanning: false,
);

void main() {
  late _MockSpAccountRepository repository;
  late _MockSpBackendConfigRepository configRepository;
  late _MockFetchSpSecretUsecase fetchSpSecretUsecase;
  late _MockGetDefaultSeedUsecase getDefaultSeedUsecase;
  late EnsureSpSessionUsecase usecase;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(SpNetwork.regtest);
  });

  setUp(() {
    repository = _MockSpAccountRepository();
    configRepository = _MockSpBackendConfigRepository();
    fetchSpSecretUsecase = _MockFetchSpSecretUsecase();
    getDefaultSeedUsecase = _MockGetDefaultSeedUsecase();
    usecase = EnsureSpSessionUsecase(
      repository: repository,
      configRepository: configRepository,
      fetchSpSecretUsecase: fetchSpSecretUsecase,
      getDefaultSeedUsecase: getDefaultSeedUsecase,
    );

    tempDir = Directory.systemTemp.createTempSync('sp_ensure_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
      return tempDir.path;
    });

    when(() => repository.hasSession).thenReturn(false);
    when(() => repository.snapshot()).thenReturn(_wallet());
    when(() => configRepository.fetch()).thenAnswer((_) async => _config());
    when(() => fetchSpSecretUsecase.execute()).thenAnswer((_) async => _secret());
    when(
      () => getDefaultSeedUsecase.execute(),
    ).thenAnswer((_) async => _mnemonicSeed());
    when(
      () => repository.createFromMnemonic(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        mnemonic: any(named: 'mnemonic'),
      ),
    ).thenAnswer((_) async {});
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  group('EnsureSpSessionUsecase', () {
    test('reuses the live session without reconstructing', () async {
      when(() => repository.hasSession).thenReturn(true);

      final result = await usecase.execute();

      expect(result, isNotNull);
      verify(() => repository.snapshot()).called(1);
      verifyNever(
        () => repository.createFromMnemonic(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          mnemonic: any(named: 'mnemonic'),
        ),
      );
    });

    test('returns null when a .revoked sentinel is present', () async {
      Directory('${tempDir.path}/${SpConfig.accountName}').createSync();
      File(
        '${tempDir.path}/${SpConfig.accountName}/${SpConfig.revokedSentinelFile}',
      ).writeAsStringSync('revoked');

      final result = await usecase.execute();

      expect(result, isNull);
      verifyNever(() => configRepository.fetch());
    });

    test('returns null when no backend config is stored', () async {
      when(() => configRepository.fetch()).thenAnswer((_) async => null);

      final result = await usecase.execute();

      expect(result, isNull);
      verifyNever(() => fetchSpSecretUsecase.execute());
    });

    test('returns null when no secret is derivable', () async {
      when(() => fetchSpSecretUsecase.execute()).thenAnswer((_) async => null);

      final result = await usecase.execute();

      expect(result, isNull);
    });

    test('throws when the default seed is not mnemonic-backed', () async {
      when(
        () => getDefaultSeedUsecase.execute(),
      ).thenAnswer((_) async => _bytesSeed());

      await expectLater(
        usecase.execute(),
        throwsA(isA<SpSetupRequiresMnemonicError>()),
      );
    });

    test('reconstructs via createFromMnemonic from the stored config', () async {
      final result = await usecase.execute();

      expect(result, isNotNull);
      verify(
        () => repository.createFromMnemonic(
          network: SpNetwork.regtest,
          blindbitUrl: 'http://blindbit.example',
          electrumUrl: 'tcp://electrum.example:50001',
          mnemonic: 'abandon abandon abandon abandon abandon abandon abandon '
              'abandon abandon abandon abandon abandon',
        ),
      ).called(1);
    });

    test('serializes concurrent establishment into one createFromMnemonic', () async {
      final results = await Future.wait([usecase.execute(), usecase.execute()]);

      expect(results[0], isNotNull);
      expect(results[1], isNotNull);
      verify(
        () => repository.createFromMnemonic(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
          mnemonic: any(named: 'mnemonic'),
        ),
      ).called(1);
    });
  });
}
