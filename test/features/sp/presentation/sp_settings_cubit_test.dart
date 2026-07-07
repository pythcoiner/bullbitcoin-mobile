import 'dart:async';

import 'package:bb_mobile/features/sp/application/ports/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/application/usecases/recreate_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/watch_sp_notification_log_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_backend_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/presentation/sp_settings_cubit.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockRecreateSpWalletUsecase extends Mock
    implements RecreateSpWalletUsecase {}

class _MockWatchSpNotificationLogUsecase extends Mock
    implements WatchSpNotificationLogUsecase {}

class _MockSpBackendConfigRepository extends Mock
    implements SpBackendConfigRepository {}

SpNotifLogLine _line(String text) =>
    SpNotifLogLine(time: DateTime(2026, 6, 24), text: text);

void main() {
  late _MockWatchSpNotificationLogUsecase logUsecase;
  late StreamController<SpNotifLogLine> logController;

  SpSettingsCubit build({List<SpNotifLogLine> seed = const []}) {
    when(() => logUsecase.current()).thenReturn(seed);
    when(() => logUsecase.stream()).thenAnswer((_) => logController.stream);
    final configRepo = _MockSpBackendConfigRepository();
    when(() => configRepo.fetch()).thenAnswer((_) async => null);
    return SpSettingsCubit(
      _MockRecreateSpWalletUsecase(),
      logUsecase,
      TestSpBackendUsecase(
        testBlindbit: ({required String url}) async => 0,
        testElectrum: ({required String url}) async {},
      ),
      configRepo,
      regtestDefaults: () => const SpBackendDefaults.ok(
        blindbitUrl: 'http://127.0.0.1:8000',
        electrumUrl: 'tcp://127.0.0.1:50001',
      ),
    );
  }

  setUp(() {
    logUsecase = _MockWatchSpNotificationLogUsecase();
    logController = StreamController<SpNotifLogLine>.broadcast();
  });

  tearDown(() => logController.close());

  group('SpSettingsCubit', () {
    test('initial regtest state pre-fills default URLs', () async {
      final cubit = build();
      expect(cubit.state.network, SpNetwork.regtest);
      expect(cubit.state.blindbitUrl, isNotEmpty);
      expect(cubit.state.electrumUrl, isNotEmpty);
      await cubit.close();
    });

    test('setNetwork to regtest pre-fills default URLs', () async {
      final cubit = build();
      cubit.setNetwork(SpNetwork.bitcoin);
      expect(cubit.state.blindbitUrl, isNotEmpty);

      cubit.setNetwork(SpNetwork.regtest);

      expect(cubit.state.network, SpNetwork.regtest);
      expect(cubit.state.blindbitUrl, isNotEmpty);
      expect(cubit.state.electrumUrl, isNotEmpty);
      await cubit.close();
    });

    test('initFromNetwork loads the stored custom config over defaults', () async {
      when(() => logUsecase.current()).thenReturn(const []);
      when(() => logUsecase.stream()).thenAnswer((_) => logController.stream);
      final configRepo = _MockSpBackendConfigRepository();
      when(() => configRepo.fetch()).thenAnswer(
        (_) async => const SpBackendConfig(
          network: SpNetwork.bitcoin,
          blindbitUrl: 'https://custom.blindbit',
          electrumUrl: 'ssl://custom.electrum:50002',
        ),
      );
      final cubit = SpSettingsCubit(
        _MockRecreateSpWalletUsecase(),
        logUsecase,
        TestSpBackendUsecase(
          testBlindbit: ({required String url}) async => 0,
          testElectrum: ({required String url}) async {},
        ),
        configRepo,
        regtestDefaults: () => const SpBackendDefaults.ok(
          blindbitUrl: 'http://127.0.0.1:8000',
          electrumUrl: 'tcp://127.0.0.1:50001',
        ),
      );

      await cubit.initFromNetwork(SpNetwork.regtest);

      expect(cubit.state.network, SpNetwork.bitcoin);
      expect(cubit.state.blindbitUrl, 'https://custom.blindbit');
      expect(cubit.state.electrumUrl, 'ssl://custom.electrum:50002');
      await cubit.close();
    });
  });

  group('SpSettingsCubit console', () {
    test('seeds console from the buffered log', () async {
      final cubit = build(seed: [_line('ScanStarted 1 -> 2')]);
      expect(cubit.state.console.map((l) => l.text), ['ScanStarted 1 -> 2']);
      await cubit.close();
    });

    test('appends new lines from the stream', () async {
      final cubit = build();
      expect(cubit.state.console, isEmpty);

      logController.add(_line('NewOutput abc 100sat'));
      await Future.delayed(Duration.zero);

      expect(cubit.state.console.map((l) => l.text), ['NewOutput abc 100sat']);
      await cubit.close();
    });

    test('console survives a network change', () async {
      final cubit = build(seed: [_line('ScanCompleted')]);
      cubit.setNetwork(SpNetwork.bitcoin);
      expect(cubit.state.console.map((l) => l.text), ['ScanCompleted']);
      await cubit.close();
    });

    test('clearConsole empties the console', () async {
      final cubit = build(seed: [_line('ScanCompleted')]);
      cubit.clearConsole();
      expect(cubit.state.console, isEmpty);
      await cubit.close();
    });
  });
}
