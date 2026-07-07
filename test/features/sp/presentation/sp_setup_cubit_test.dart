import 'package:bb_mobile/features/sp/application/application_errors.dart';
import 'package:bb_mobile/features/sp/application/usecases/create_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_cubit.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockCreateSpWalletUsecase extends Mock implements CreateSpWalletUsecase {}

void main() {
  setUpAll(() {
    registerFallbackValue(SpNetwork.regtest);
  });

  late SpSetupCubit cubit;
  late MockCreateSpWalletUsecase mockCreate;

  setUp(() {
    mockCreate = MockCreateSpWalletUsecase();

    when(
      () => mockCreate.execute(
        network: any(named: 'network'),
        blindbitUrl: any(named: 'blindbitUrl'),
        electrumUrl: any(named: 'electrumUrl'),
      ),
    ).thenAnswer((_) async {});

    cubit = SpSetupCubit(
      mockCreate,
      TestSpBackendUsecase(
        testBlindbit: ({required String url}) async => 0,
        testElectrum: ({required String url}) async {},
      ),
      regtestDefaults: () => const SpBackendDefaults.ok(
        blindbitUrl: 'http://127.0.0.1:8000',
        electrumUrl: 'tcp://127.0.0.1:50001',
      ),
    );
  });

  tearDown(() => cubit.close());

  group('SpSetupCubit', () {
    test('initial state is default', () {
      expect(cubit.state.network, SpNetwork.regtest);
      expect(cubit.state.blindbitUrl, isNotEmpty);
      expect(cubit.state.electrumUrl, isNotEmpty);
      expect(cubit.state.isCreating, isFalse);
      expect(cubit.state.created, isFalse);
      expect(cubit.state.error, isNull);
    });

    test('setNetwork to bitcoin pre-fills default URLs', () async {
      await cubit.setNetwork(SpNetwork.bitcoin);

      expect(cubit.state.network, SpNetwork.bitcoin);
      expect(
        cubit.state.blindbitUrl,
        SpConfig.defaultBlindbitUrl[SpNetwork.bitcoin],
      );
      expect(
        cubit.state.electrumUrl,
        SpConfig.defaultElectrumUrl[SpNetwork.bitcoin],
      );
      expect(cubit.state.blindbitUrl, isNotEmpty);
      expect(cubit.state.electrumUrl, isNotEmpty);
    });

    test('setNetwork to signet pre-fills default URLs', () async {
      await cubit.setNetwork(SpNetwork.signet);

      expect(cubit.state.network, SpNetwork.signet);
      expect(cubit.state.blindbitUrl, isNotEmpty);
      expect(cubit.state.electrumUrl, isNotEmpty);
    });

    test('setNetwork to regtest pre-fills default URLs', () async {
      await cubit.setNetwork(SpNetwork.bitcoin);
      expect(cubit.state.blindbitUrl, isNotEmpty);

      await cubit.setNetwork(SpNetwork.regtest);
      expect(cubit.state.network, SpNetwork.regtest);
      expect(cubit.state.blindbitUrl, isNotEmpty);
      expect(cubit.state.electrumUrl, isNotEmpty);
    });

    test('setBlindbitUrl updates state', () {
      cubit.setBlindbitUrl('http://blindbit.local');
      expect(cubit.state.blindbitUrl, 'http://blindbit.local');
      expect(cubit.state.error, isNull);
    });

    test('setElectrumUrl updates state', () {
      cubit.setElectrumUrl('tcp://electrum.local:60001');
      expect(cubit.state.electrumUrl, 'tcp://electrum.local:60001');
      expect(cubit.state.error, isNull);
    });

    test('setNetwork clears prior error', () async {
      when(
        () => mockCreate.execute(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
        ),
      ).thenThrow(Exception('boom'));

      cubit.setBlindbitUrl('http://blindbit.local');
      cubit.setElectrumUrl('tcp://electrum.local:60001');
      await cubit.testBlindbit();
      await cubit.testElectrum();
      await cubit.create();
      expect(cubit.state.error, isNotNull);

      await cubit.setNetwork(SpNetwork.bitcoin);
      expect(cubit.state.error, isNull);
    });

    test('create() success: calls usecase, sets created', () async {
      cubit.setBlindbitUrl('http://blindbit.local');
      cubit.setElectrumUrl('tcp://electrum.local:60001');

      await cubit.testBlindbit();
      await cubit.testElectrum();
      await cubit.create();

      verify(
        () => mockCreate.execute(
          network: SpNetwork.regtest,
          blindbitUrl: 'http://blindbit.local',
          electrumUrl: 'tcp://electrum.local:60001',
        ),
      ).called(1);
      expect(cubit.state.created, isTrue);
      expect(cubit.state.error, isNull);
      expect(cubit.state.isCreating, isFalse);
    });

    test(
      'create() surfaces SpSetupRequiresMnemonicError from usecase (BytesSeed path)',
      () async {
        when(
          () => mockCreate.execute(
            network: any(named: 'network'),
            blindbitUrl: any(named: 'blindbitUrl'),
            electrumUrl: any(named: 'electrumUrl'),
          ),
        ).thenThrow(
          const SpSetupRequiresMnemonicError(
            'SP setup requires a mnemonic-backed seed; got BytesSeed',
          ),
        );

        cubit.setBlindbitUrl('http://blindbit.local');
        cubit.setElectrumUrl('tcp://electrum.local:60001');

        await cubit.testBlindbit();
      await cubit.testElectrum();
      await cubit.create();

        expect(cubit.state.error, isNotNull);
        expect(cubit.state.error, contains('mnemonic-backed seed'));
        expect(cubit.state.created, isFalse);
        expect(cubit.state.isCreating, isFalse);
      },
    );

    test('create() failure: sets error, leaves created false', () async {
      when(
        () => mockCreate.execute(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
        ),
      ).thenThrow(Exception('cleanup failed'));

      cubit.setBlindbitUrl('http://blindbit.local');
      cubit.setElectrumUrl('tcp://electrum.local:60001');

      await cubit.testBlindbit();
      await cubit.testElectrum();
      await cubit.create();

      verify(
        () => mockCreate.execute(
          network: any(named: 'network'),
          blindbitUrl: any(named: 'blindbitUrl'),
          electrumUrl: any(named: 'electrumUrl'),
        ),
      ).called(1);
      expect(cubit.state.error, isNotNull);
      expect(cubit.state.created, isFalse);
      expect(cubit.state.isCreating, isFalse);
    });
  });
}
