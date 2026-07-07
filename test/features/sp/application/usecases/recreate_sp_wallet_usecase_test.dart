import 'dart:io';

import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/application/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/fetch_sp_secret_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/recreate_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockGetDefaultSeedUsecase extends Mock
    implements GetDefaultSeedUsecase {}

class _MockFetchSpSecretUsecase extends Mock implements FetchSpSecretUsecase {}

class _MockSpAccountRepository extends Mock implements SpAccountRepository {}

class _MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

class _MockEnsureSpSessionUsecase extends Mock
    implements EnsureSpSessionUsecase {}

MnemonicSeed _seed() => MnemonicSeed(
  mnemonicWords: List.filled(12, 'abandon'),
  bytes: Uint8List.fromList(List.filled(64, 1)),
  masterFingerprint: 'f23f9fd2',
);

List<int> _secret() => List<int>.generate(64, (index) => index);

void main() {
  late _MockGetDefaultSeedUsecase getDefaultSeedUsecase;
  late _MockFetchSpSecretUsecase fetchSpSecretUsecase;
  late _MockSpAccountRepository repository;
  late _MockSpBackendConfigRepository configRepository;
  late _MockEnsureSpSessionUsecase ensureSpSessionUsecase;
  late RecreateSpWalletUsecase usecase;
  late Directory tempDir;

  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    registerFallbackValue(SpNetwork.regtest);
    registerFallbackValue(
      const SpBackendConfig(
        network: SpNetwork.regtest,
        blindbitUrl: '',
        electrumUrl: '',
      ),
    );
  });

  setUp(() {
    getDefaultSeedUsecase = _MockGetDefaultSeedUsecase();
    fetchSpSecretUsecase = _MockFetchSpSecretUsecase();
    repository = _MockSpAccountRepository();
    configRepository = _MockSpBackendConfigRepository();
    ensureSpSessionUsecase = _MockEnsureSpSessionUsecase();
    usecase = RecreateSpWalletUsecase(
      getDefaultSeedUsecase,
      fetchSpSecretUsecase,
      repository,
      configRepository,
      ensureSpSessionUsecase,
    );
    tempDir = Directory.systemTemp.createTempSync('sp_recreate_test_');
    const channel = MethodChannel('plugins.flutter.io/path_provider');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall call) async {
          return tempDir.path;
        });

    when(
      () => getDefaultSeedUsecase.execute(),
    ).thenAnswer((_) async => _seed());
    when(
      () => fetchSpSecretUsecase.execute(),
    ).thenAnswer((_) async => _secret());
    when(() => repository.dispose()).thenAnswer((_) async {});
    when(() => configRepository.save(any())).thenAnswer((_) async {});
    when(() => ensureSpSessionUsecase.execute()).thenAnswer((_) async => null);
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
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('plugins.flutter.io/path_provider'),
          null,
        );
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test('recreates from the active SP secret without revoking it', () async {
    final accountDir = Directory('${tempDir.path}/${SpConfig.accountName}')
      ..createSync();
    File('${accountDir.path}/account.sqlite').writeAsStringSync('old');

    await usecase.execute(
      network: SpNetwork.bitcoin,
      blindbitUrl: 'https://blindbit.example',
      electrumUrl: 'ssl://electrum.example:50002',
    );

    verify(() => repository.dispose()).called(1);
    verify(
      () => repository.createFromMnemonic(
        network: SpNetwork.bitcoin,
        blindbitUrl: 'https://blindbit.example',
        electrumUrl: 'ssl://electrum.example:50002',
        mnemonic: any(named: 'mnemonic'),
      ),
    ).called(1);
    verify(
      () => configRepository.save(
        any(
          that: isA<SpBackendConfig>()
              .having((c) => c.network, 'network', SpNetwork.bitcoin)
              .having(
                (c) => c.blindbitUrl,
                'blindbitUrl',
                'https://blindbit.example',
              )
              .having(
                (c) => c.electrumUrl,
                'electrumUrl',
                'ssl://electrum.example:50002',
              ),
        ),
      ),
    ).called(1);
    expect(accountDir.existsSync(), isFalse);
  });

  test('restores the previous account directory when recreate fails', () async {
    final accountDir = Directory('${tempDir.path}/${SpConfig.accountName}')
      ..createSync();
    final oldDb = File('${accountDir.path}/account.sqlite')
      ..writeAsStringSync('old');
    when(
      () => repository.createFromMnemonic(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
        mnemonic: any(named: 'mnemonic'),
      ),
    ).thenThrow(Exception('create failed'));

    await expectLater(
      usecase.execute(
        network: SpNetwork.bitcoin,
        blindbitUrl: 'https://blindbit.example',
        electrumUrl: 'ssl://electrum.example:50002',
      ),
      throwsException,
    );

    expect(accountDir.existsSync(), isTrue);
    expect(oldDb.readAsStringSync(), 'old');
    // The previous session is reconstructed from the restored directory.
    verify(() => ensureSpSessionUsecase.execute()).called(1);
  });
}
