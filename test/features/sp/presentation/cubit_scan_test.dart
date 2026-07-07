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
  late StreamController<SpNotification> notifController;

  final fakeBalance = SpBalance(
    confirmedSat: BigInt.from(5000),
    totalUnifiedSat: BigInt.from(5000),
  );

  SpWalletData buildData() => SpWalletData(
    wallet: SpWallet(
      spAddress: 'sp1qtest',
      balance: fakeBalance,
      isScanning: false,
      lastScannedHeight: null,
    ),
    history: <SpPaymentView>[],
    coins: const [],
    network: SpNetwork.regtest,
    backendOnline: true,
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
    notifController = StreamController<SpNotification>.broadcast();

    when(() => loadUsecase.execute()).thenAnswer((_) async => buildData());
    when(() => watchUsecase.execute()).thenAnswer((_) => notifController.stream);
    when(() => scanUsecase.execute()).thenAnswer((_) async {});

    cubit = SpCubit(
      loadSpWalletDataUsecase: loadUsecase,
      watchSpNotificationsUsecase: watchUsecase,
      scanSpWalletUsecase: scanUsecase,
      stopSpScanUsecase: stopUsecase,
      prepareSpPaymentUsecase: prepareUsecase,
      sendSpPaymentUsecase: sendUsecase,
      revokeSpWalletUsecase: revokeUsecase,
      generateTaprootAddressUsecase: generateUsecase,
    );
  });

  tearDown(() async {
    await cubit.close();
    await notifController.close();
  });

  test('ScanStarted notification sets isScanning=true and scan bounds', () async {
    await cubit.load();

    notifController.add(const SpNotification.scanStarted(from: 800000, to: 850000));
    await Future.delayed(Duration.zero);

    expect(cubit.state.isScanning, true);
    expect(cubit.state.scanFrom, 800000);
    expect(cubit.state.scanTo, 850000);
    expect(cubit.state.scanCurrent, 800000);
    expect(cubit.state.scanStartTime, isNotNull);
  });

  test('ScanReceiveProgress updates scanCurrent/scanTo, phase=receive', () async {
    await cubit.load();

    notifController.add(const SpNotification.scanStarted(from: 800000, to: 850000));
    await Future.delayed(Duration.zero);

    notifController
        .add(const SpNotification.scanReceiveProgress(current: 810000, end: 850000));
    await Future.delayed(Duration.zero);

    expect(cubit.state.scanCurrent, 810000);
    expect(cubit.state.scanTo, 850000);
    expect(cubit.state.scanPhase, SpScanPhase.receive);
    expect(cubit.state.isScanning, true);
  });

  test('ScanSpendProgress switches to step 2 and rebases the bar', () async {
    await cubit.load();

    notifController.add(const SpNotification.scanStarted(from: 800000, to: 850000));
    await Future.delayed(Duration.zero);
    notifController
        .add(const SpNotification.scanReceiveProgress(current: 850000, end: 850000));
    await Future.delayed(Duration.zero);

    // First spend update: phase flips, scanFrom rebases to the spend start so
    // progress restarts near 0 (not negative against the receive baseline).
    notifController
        .add(const SpNotification.scanSpendProgress(current: 800000, end: 850000));
    await Future.delayed(Duration.zero);

    expect(cubit.state.scanPhase, SpScanPhase.spend);
    expect(cubit.state.scanFrom, 800000);
    expect(cubit.state.scanCurrent, 800000);
    expect(cubit.state.scanTo, 850000);
    expect(cubit.state.scanProgress, 0.0);

    notifController
        .add(const SpNotification.scanSpendProgress(current: 825000, end: 850000));
    await Future.delayed(Duration.zero);
    expect(cubit.state.scanProgress, closeTo(0.5, 0.001));
  });

  test('ScanCompleted notification sets isScanning=false and reloads data', () async {
    await cubit.load();
    clearInteractions(loadUsecase);

    notifController.add(const SpNotification.scanStarted(from: 800000, to: 850000));
    await Future.delayed(Duration.zero);

    notifController.add(const SpNotification.scanCompleted());
    await Future.delayed(Duration.zero);

    expect(cubit.state.isScanning, false);
    // Total scan duration is captured for the post-scan view.
    expect(cubit.state.scanLastDurationSecs, isNotNull);
    // The one-shot scan runs on a background thread, so ScanCompleted is the
    // done signal that drives the wallet-data reload.
    verify(() => loadUsecase.execute()).called(1);
  });

  test('ScanStopped notification sets isScanning=false and reloads data', () async {
    await cubit.load();
    clearInteractions(loadUsecase);

    notifController.add(const SpNotification.scanStarted(from: 800000, to: 850000));
    await Future.delayed(Duration.zero);

    notifController.add(const SpNotification.scanStopped());
    await Future.delayed(Duration.zero);

    expect(cubit.state.isScanning, false);
    // Reload so lastScannedHeight reflects where the scan stopped (the next
    // scan resumes from there).
    verify(() => loadUsecase.execute()).called(1);
  });

  test('ScanFailed notification sets isScanning=false and sets error', () async {
    await cubit.load();

    notifController.add(const SpNotification.scanFailed(message: 'network error'));
    await Future.delayed(Duration.zero);

    expect(cubit.state.isScanning, false);
    expect(cubit.state.error, isNotNull);
    expect(cubit.state.error!.message, contains('network error'));
  });

  group('no auto-scan on init', () {
    test('SpCubit.load() does not trigger scan', () async {
      await cubit.load();
      await Future.delayed(Duration.zero);

      verifyNever(() => scanUsecase.execute());
    });

    test('Electrum balance push does not trigger scan', () async {
      await cubit.load();

      notifController.add(
        SpNotification.electrumTx(
          kind: CoinSource.segwit,
          txid: 'aabbcc',
          amountSat: BigInt.from(1000),
        ),
      );
      await Future.delayed(Duration.zero);

      verifyNever(() => scanUsecase.execute());
    });
  });

  test('coin notification during scan defers reload to ScanCompleted', () async {
    await cubit.load();
    notifController.add(const SpNotification.scanStarted(from: 1, to: 10));
    await Future.delayed(Duration.zero);

    // Ignore the initial load() call; assert only what happens during scan.
    clearInteractions(loadUsecase);

    notifController.add(
      SpNotification.newOutput(outpoint: 'o:0', amountSat: BigInt.from(1)),
    );
    await Future.delayed(Duration.zero);
    // Still scanning: defer the reload (avoid churn during the background scan).
    verifyNever(() => loadUsecase.execute());

    notifController.add(const SpNotification.scanCompleted());
    await Future.delayed(Duration.zero);
    // ScanCompleted reloads exactly once.
    verify(() => loadUsecase.execute()).called(1);
  });

  test('scan() invokes ScanSpWalletUsecase.execute exactly once per call', () async {
    await cubit.load();

    await cubit.scan();
    verify(() => scanUsecase.execute()).called(1);

    await cubit.scan();
    verify(() => scanUsecase.execute()).called(1);
  });

  test('scan() only goes through ScanSpWalletUsecase', () async {
    // scan() must only go through ScanSpWalletUsecase, never directly to FFI.
    await cubit.load();
    await cubit.scan();

    verify(() => scanUsecase.execute()).called(1);
  });

  test('scan(startHeight) forwards the chosen height to the usecase', () async {
    when(
      () => scanUsecase.execute(startHeight: any(named: 'startHeight')),
    ).thenAnswer((_) async {});
    await cubit.load();

    await cubit.scan(startHeight: 800000);

    verify(() => scanUsecase.execute(startHeight: 800000)).called(1);
  });

  test('stopScan() invokes StopSpScanUsecase.execute', () async {
    when(() => stopUsecase.execute()).thenAnswer((_) async {});
    await cubit.load();

    await cubit.stopScan();

    verify(() => stopUsecase.execute()).called(1);
  });

  test('scanProgress getter returns 0.0 when scan bounds are null', () {
    expect(cubit.state.scanProgress, 0.0);
  });

  test('scanProgress getter returns correct fraction', () async {
    await cubit.load();

    notifController.add(const SpNotification.scanStarted(from: 0, to: 100));
    await Future.delayed(Duration.zero);

    notifController
        .add(const SpNotification.scanReceiveProgress(current: 50, end: 100));
    await Future.delayed(Duration.zero);

    expect(cubit.state.scanProgress, closeTo(0.5, 0.001));
  });

  group('async edge cases', () {
    test('two scan() calls each delegate to the usecase (thin pass-through, '
        'no cubit-level dedup)', () async {
      await cubit.load();

      await Future.wait([cubit.scan(), cubit.scan()]);

      verify(() => scanUsecase.execute()).called(2);
    });

    test('stopScan() is idempotent across repeated calls', () async {
      when(() => stopUsecase.execute()).thenAnswer((_) async {});
      await cubit.load();

      await cubit.stopScan();
      await cubit.stopScan();

      verify(() => stopUsecase.execute()).called(2);
      expect(cubit.state.error, isNull);
    });

    test('stopScan() swallows a usecase error (no throw, no error state)',
        () async {
      when(() => stopUsecase.execute()).thenThrow(StateError('stop failed'));
      await cubit.load();

      // Must not throw; stopScan is best-effort (the scan tears down async).
      await cubit.stopScan();

      expect(cubit.state.error, isNull);
    });

    test('a notification arriving after close() does not throw or emit',
        () async {
      await cubit.load();
      final emitted = <Object?>[];
      final sub = cubit.stream.listen(emitted.add);

      await cubit.close();
      // Late notification on the still-open controller must be ignored.
      notifController.add(const SpNotification.scanStarted(from: 1, to: 2));
      await Future.delayed(Duration.zero);

      await sub.cancel();
      expect(emitted, isEmpty);
    });

    test('self-heals when its notification stream closes: re-subscribes via '
        'load() (the #2 session-recycle regression)', () async {
      await cubit.load();

      // After the session is recycled, watching yields a fresh (open) stream —
      // mirror the real adapter, which establishes a new broadcast stream for
      // the new session. Left open so re-subscription does not loop.
      final freshController = StreamController<SpNotification>.broadcast();
      when(
        () => watchUsecase.execute(),
      ).thenAnswer((_) => freshController.stream);

      // Simulate the singleton session being disposed out from under the cubit
      // (e.g. a wallet-side full refresh after a network change): its stream
      // completes.
      await notifController.close();
      await Future.delayed(Duration.zero);

      // The cubit must have re-established by reloading + re-subscribing rather
      // than leaving a dead screen: load() ran on entry and again on self-heal,
      // and notifications were watched on each (verify counts cumulatively as
      // these methods are verified only here).
      verify(() => loadUsecase.execute()).called(greaterThanOrEqualTo(2));
      verify(() => watchUsecase.execute()).called(greaterThanOrEqualTo(2));
    });
  });
}
