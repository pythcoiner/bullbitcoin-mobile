import 'dart:async';

import 'package:bb_mobile/features/sp/application/usecases/generate_taproot_address_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/prepare_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/scan_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/send_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/stop_sp_scan_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/watch_sp_notifications_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/sp_wallet.dart';
import 'package:bb_mobile/features/sp/presentation/cubit.dart';
import 'package:bb_mobile/features/sp/presentation/state.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../sp_test_streams.dart';

class _MockLoadSpWalletDataUsecase extends Mock
    implements LoadSpWalletDataUsecase {}

class _MockWatchSpNotificationsUsecase extends Mock
    implements WatchSpNotificationsUsecase {}

class _MockScanSpWalletUsecase extends Mock implements ScanSpWalletUsecase {}

class _MockStopSpScanUsecase extends Mock implements StopSpScanUsecase {}

class _MockPrepareSpPaymentUsecase extends Mock
    implements PrepareSpPaymentUsecase {}

class _MockSendSpPaymentUsecase extends Mock implements SendSpPaymentUsecase {}

class _MockRevokeSpWalletUsecase extends Mock implements RevokeSpWalletUsecase {}

class _MockGenerateTaprootAddressUsecase extends Mock
    implements GenerateTaprootAddressUsecase {}

void main() {
  late _MockLoadSpWalletDataUsecase loadUsecase;
  late _MockWatchSpNotificationsUsecase watchUsecase;
  late _MockScanSpWalletUsecase scanUsecase;
  late _MockStopSpScanUsecase stopUsecase;
  late _MockPrepareSpPaymentUsecase prepareUsecase;
  late _MockSendSpPaymentUsecase sendUsecase;
  late _MockRevokeSpWalletUsecase revokeUsecase;
  late _MockGenerateTaprootAddressUsecase generateUsecase;
  late SpCubit cubit;

  final fakeBalance = SpBalance(
    confirmedSat: BigInt.from(10000),
    totalUnifiedSat: BigInt.from(10000),
    lastScannedHeight: 800000,
  );

  SpWalletData buildData({
    SpBalance? balance,
    List<SpPaymentView>? history,
    int? lastScannedHeight = 800000,
    bool isScanning = false,
  }) => SpWalletData(
    wallet: SpWallet(
      spAddress: 'sp1qtest',
      balance: balance ?? fakeBalance,
      isScanning: isScanning,
      lastScannedHeight: lastScannedHeight,
    ),
    history: history ?? <SpPaymentView>[],
    coins: const [],
    network: SpNetwork.regtest,
    backendOnline: true,
  );

  SpCubit buildCubit() => SpCubit(
    loadSpWalletDataUsecase: loadUsecase,
    watchSpNotificationsUsecase: watchUsecase,
    scanSpWalletUsecase: scanUsecase,
    stopSpScanUsecase: stopUsecase,
    prepareSpPaymentUsecase: prepareUsecase,
    sendSpPaymentUsecase: sendUsecase,
    revokeSpWalletUsecase: revokeUsecase,
    generateTaprootAddressUsecase: generateUsecase,
  );

  setUp(() {
    loadUsecase = _MockLoadSpWalletDataUsecase();
    watchUsecase = _MockWatchSpNotificationsUsecase();
    scanUsecase = _MockScanSpWalletUsecase();
    stopUsecase = _MockStopSpScanUsecase();
    prepareUsecase = _MockPrepareSpPaymentUsecase();
    sendUsecase = _MockSendSpPaymentUsecase();
    revokeUsecase = _MockRevokeSpWalletUsecase();
    generateUsecase = _MockGenerateTaprootAddressUsecase();

    when(() => loadUsecase.execute()).thenAnswer((_) async => buildData());
    when(
      () => watchUsecase.execute(),
    ).thenAnswer((_) => openSpNotificationStream());

    cubit = buildCubit();
  });

  tearDown(() async {
    await cubit.close();
  });

  test('initial state is empty', () {
    expect(cubit.state, const SpState());
  });

  test('load() populates address and balance fields from wallet', () async {
    await cubit.load();

    expect(cubit.state.spAddress, 'sp1qtest');
    expect(cubit.state.balance, fakeBalance);
    expect(cubit.state.history, isEmpty);
    expect(cubit.state.lastScannedHeight, 800000);
    expect(cubit.state.isScanning, false);
    expect(cubit.state.isLoading, false);
    expect(cubit.state.network, SpNetwork.regtest);
    expect(cubit.state.backendOnline, true);
  });

  test('load() sets isLoading to false after completion', () async {
    await cubit.load();
    // Check state directly — avoids relying on stream delivery timing.
    expect(cubit.state.isLoading, false);
  });

  test('totalBalance getter returns totalUnifiedSat from balance', () async {
    await cubit.load();
    expect(cubit.state.totalBalance, BigInt.from(10000));
  });

  test('load() sets error on wallet access failure', () async {
    when(() => loadUsecase.execute()).thenThrow(Exception('wallet error'));

    await cubit.load();

    expect(cubit.state.error, isNotNull);
    expect(cubit.state.isLoading, false);
  });

  test('load() subscribes to watchSpNotificationsUsecase', () async {
    await cubit.load();
    verify(() => watchUsecase.execute()).called(1);
  });

  test(
    'recreated cubit subscribes to the same broadcast stream (no init reuse)',
    () async {
      // Regression for: after first cubit closes (route leave), a second
      // cubit (route re-entry) must still receive notifications. The usecase
      // exposes a broadcast stream so both subscribe without depleting the
      // single-take Rust receiver.
      final controller = StreamController<SpNotification>.broadcast();
      addTearDown(controller.close);
      when(() => watchUsecase.execute()).thenAnswer((_) => controller.stream);

      // First cubit
      await cubit.load();
      final firstEvents = <SpNotification>[];
      final firstStateSub = cubit.stream.listen((s) {
        if (s.isScanning) {
          firstEvents.add(const SpNotification.scanStarted(from: 1, to: 2));
        }
      });
      controller.add(const SpNotification.scanStarted(from: 1, to: 2));
      await Future<void>.delayed(Duration.zero);
      expect(firstEvents, isNotEmpty);
      await firstStateSub.cancel();
      await cubit.close();

      // Second cubit on the same notification stream
      final cubit2 = buildCubit();
      addTearDown(cubit2.close);

      await cubit2.load();
      controller.add(const SpNotification.scanStarted(from: 10, to: 20));
      await Future<void>.delayed(Duration.zero);
      expect(cubit2.state.isScanning, true);
      expect(cubit2.state.scanFrom, 10);
      expect(cubit2.state.scanTo, 20);
    },
  );

  test('ScanSpWalletUsecase is never called during load()', () async {
    await cubit.load();
    verifyNever(() => scanUsecase.execute());
  });

  group('generateTaprootAddress', () {
    test(
      'each call reveals a fresh address via the usecase and updates state',
      () async {
        var calls = 0;
        when(() => generateUsecase.execute()).thenAnswer((_) async {
          calls++;
          return calls == 1 ? 'bcrt1pfirst' : 'bcrt1psecond';
        });

        await cubit.generateTaprootAddress();
        expect(cubit.state.taprootReceiveAddress, 'bcrt1pfirst');
        expect(cubit.state.isGeneratingAddress, false);

        await cubit.generateTaprootAddress();
        expect(cubit.state.taprootReceiveAddress, 'bcrt1psecond');
        expect(cubit.state.isGeneratingAddress, false);

        verify(() => generateUsecase.execute()).called(2);
      },
    );

    test('sets error and clears isGeneratingAddress on failure', () async {
      when(
        () => generateUsecase.execute(),
      ).thenThrow(Exception('derive failed'));

      await cubit.generateTaprootAddress();

      expect(cubit.state.error, isNotNull);
      expect(cubit.state.isGeneratingAddress, false);
    });
  });

  group('revokeWallet', () {
    test('delegates to the revoke usecase', () async {
      when(() => revokeUsecase.execute()).thenAnswer((_) async {});

      await cubit.revokeWallet();

      verify(() => revokeUsecase.execute()).called(1);
    });

    test('does not throw when the usecase fails (UI must still navigate)',
        () async {
      when(() => revokeUsecase.execute()).thenThrow(Exception('delete failed'));

      // The usecase already makes the wallet unloadable (sentinel) even on its
      // failure path, so revokeWallet must complete instead of propagating.
      await expectLater(cubit.revokeWallet(), completes);
    });
  });
}
