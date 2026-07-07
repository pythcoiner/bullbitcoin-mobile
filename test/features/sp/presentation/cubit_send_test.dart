import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart' hide Logger;
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
import 'package:bull_sdk/bwk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging_colorful/logging_colorful.dart';
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
  setUpAll(() {
    registerFallbackValue(<RecipientView>[]);
    registerFallbackValue(BigInt.zero);
    registerFallbackValue(
      TxSimulation(
        inputs: const [],
        outputs: const [],
        feeSat: BigInt.zero,
        changeSat: BigInt.zero,
      ),
    );
  });

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
    confirmedSat: BigInt.from(50000),
    totalUnifiedSat: BigInt.from(50000),
  );

  final fakeTxSimulation = TxSimulation(
    inputs: [],
    outputs: [],
    feeSat: BigInt.from(200),
    changeSat: BigInt.from(44800),
  );

  const fakeTxid =
      'aabbccddeeff0011aabbccddeeff0011aabbccddeeff0011aabbccddeeff0011';

  SpWalletData buildData() => SpWalletData(
    wallet: SpWallet(
      spAddress: 'sp1qtest',
      balance: fakeBalance,
      isScanning: false,
      lastScannedHeight: null,
    ),
    history: <SpPaymentView>[],
    coins: const [],
    // Mainnet so the sample `sp1…` recipients below match the wallet network
    // (the cubit now rejects a wrong-network silent payment address up front).
    network: SpNetwork.bitcoin,
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

    when(() => loadUsecase.execute()).thenAnswer((_) async => buildData());
    when(
      () => watchUsecase.execute(),
    ).thenAnswer((_) => openSpNotificationStream());

    when(
      () => prepareUsecase.execute(
        recipients: any(named: 'recipients'),
        feerateSatVb: any(named: 'feerateSatVb'),
      ),
    ).thenAnswer((_) async => fakeTxSimulation);

    // The repository logs the txid before returning so it survives an
    // emit-after-close race; mirror that by logging at INFO in the mock.
    when(
      () => sendUsecase.execute(simulation: any(named: 'simulation')),
    ).thenAnswer((_) async {
      log.info('SP broadcast txid: $fakeTxid');
      return fakeTxid;
    });

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
  });

  group('send-flow validation', () {
    test('previewRecipient rejects a wrong-network silent payment address '
        '(testnet address on a mainnet wallet)', () async {
      await cubit.load(); // network = bitcoin (mainnet)
      cubit.previewRecipient('tsp1qexampleaddress');
      expect(
        cubit.state.recipient,
        isNull,
        reason: 'a tsp1 address must not be accepted on a mainnet wallet',
      );
      expect(cubit.state.error, isNotNull);
    });

    test('previewRecipient accepts a matching-network silent payment address',
        () async {
      await cubit.load(); // network = bitcoin (mainnet)
      cubit.previewRecipient('sp1qexampleaddress');
      expect(cubit.state.recipient, isA<RecipientView_Sp>());
      expect(cubit.state.error, isNull);
    });

    test('setValidatedAmount rejects zero and surfaces an error', () async {
      await cubit.load();
      final ok = cubit.setValidatedAmount(BigInt.zero);
      expect(ok, isFalse);
      expect(cubit.state.amountSat, isNull);
      expect(cubit.state.error, isNotNull);
    });

    test('setValidatedAmount rejects an amount exceeding the balance', () async {
      await cubit.load(); // balance.totalUnifiedSat = 50000
      final ok = cubit.setValidatedAmount(BigInt.from(50001));
      expect(ok, isFalse);
      expect(cubit.state.amountSat, isNull);
      expect(cubit.state.error, isNotNull);
    });

    test('setValidatedAmount accepts an amount within the balance', () async {
      await cubit.load();
      final ok = cubit.setValidatedAmount(BigInt.from(49999));
      expect(ok, isTrue);
      expect(cubit.state.amountSat, BigInt.from(49999));
      expect(cubit.state.error, isNull);
    });
  });

  group('SP address send flow', () {
    test('previewRecipient sets RecipientView.sp for sp1... address', () async {
      cubit.previewRecipient('sp1qexampleaddress');
      expect(cubit.state.hasSendRecipient, true);
      expect(cubit.state.recipient, isA<RecipientView_Sp>());
    });

    test(
      'previewRecipient sets RecipientView.sp for tsp1... address',
      () async {
        cubit.previewRecipient('tsp1qexampleaddress');
        expect(cubit.state.hasSendRecipient, true);
        expect(cubit.state.recipient, isA<RecipientView_Sp>());
      },
    );

    test('prepare() calls PrepareSpPaymentUsecase and sets txSimulation', () async {
      await cubit.load();
      cubit.previewRecipient('sp1qexampleaddress');
      cubit.setAmount(BigInt.from(5000));

      await cubit.prepare();

      expect(cubit.state.txSimulation, isNotNull);
      expect(cubit.state.hasTxSimulation, true);
      verify(
        () => prepareUsecase.execute(
          recipients: any(named: 'recipients'),
          feerateSatVb: any(named: 'feerateSatVb'),
        ),
      ).called(1);
    });

    test('setMax(true) makes prepare() send a max RecipientView', () async {
      await cubit.load();
      cubit.previewRecipient('sp1qexampleaddress');
      cubit.setMax(true);
      expect(cubit.state.isMax, true);

      await cubit.prepare();

      final captured = verify(
        () => prepareUsecase.execute(
          recipients: captureAny(named: 'recipients'),
          feerateSatVb: any(named: 'feerateSatVb'),
        ),
      ).captured.single as List<RecipientView>;
      expect(captured.single, isA<RecipientView_Sp>());
      expect((captured.single as RecipientView_Sp).isMax, true);
    });

    test(
      'signAndBroadcast() completes full SP send flow and sets txid',
      () async {
        await cubit.load();
        cubit.previewRecipient('sp1qexampleaddress');
        cubit.setAmount(BigInt.from(5000));
        // signAndBroadcast requires a confirmed simulation. The UI flow only
        // exposes the Confirm button after prepare() succeeds, so tests that
        // drive Confirm directly must prepare first.
        await cubit.prepare();

        await cubit.signAndBroadcast();

        expect(cubit.state.txid, fakeTxid);
        expect(cubit.state.sendSuccess, true);
        // R4: send-flow inputs must be cleared on success so a back-pop to the
        // confirm page cannot re-enter signAndBroadcast against a stale pinned
        // simulation. txid stays so the success page can still render it.
        expect(cubit.state.recipient, isNull);
        expect(cubit.state.amountSat, isNull);
        expect(cubit.state.txSimulation, isNull);
        verify(
          () => sendUsecase.execute(simulation: any(named: 'simulation')),
        ).called(1);
      },
    );

    test(
      'signAndBroadcast() after a prior success refuses to re-broadcast (no resetSendFlow between calls)',
      () async {
        // R4 regression: simulates Android system-back / iOS swipe-back from
        // the success page landing on the confirm page, then a second tap on
        // "Sign & Broadcast". With the cubit-side clear-on-success fix, the
        // guard MUST short-circuit the second call.
        await cubit.load();
        cubit.previewRecipient('sp1qexampleaddress');
        cubit.setAmount(BigInt.from(5000));
        await cubit.prepare();

        // First broadcast succeeds.
        await cubit.signAndBroadcast();
        expect(cubit.state.txid, fakeTxid);
        expect(cubit.state.txSimulation, isNull);

        // Second tap — no resetSendFlow, no fresh prepare. Must NOT broadcast
        // again. The cubit clears recipient/amount/simulation on success, so
        // the FIRST defensive guard ("Recipient and amount required") fires
        // before the missing-simulation guard. Either short-circuit is
        // acceptable; the load-bearing assertion is the call-count below.
        await cubit.signAndBroadcast();

        expect(cubit.state.error, isNotNull);
        expect(
          cubit.state.error!.message,
          anyOf(
            contains('missing simulation'),
            contains('Recipient and amount required'),
          ),
        );
        // The irreversible send ran exactly once across both invocations.
        verify(
          () => sendUsecase.execute(simulation: any(named: 'simulation')),
        ).called(1);
      },
    );

    test(
      'signAndBroadcast() passes the stored TxSimulation (not rebuilt recipients) to the send usecase',
      () async {
        // Regression: the input/output set the user confirmed in prepare()
        // must be the same set passed to send. Rebuilding from
        // state.recipient/state.amountSat would let coin-store drift change
        // the signed tx between Confirm tap and broadcast.
        await cubit.load();
        cubit.previewRecipient('sp1qexampleaddress');
        cubit.setAmount(BigInt.from(5000));
        await cubit.prepare();

        final confirmed = cubit.state.txSimulation;
        expect(confirmed, isNotNull);

        await cubit.signAndBroadcast();

        final captured = verify(
          () =>
              sendUsecase.execute(simulation: captureAny(named: 'simulation')),
        ).captured;
        expect(captured.length, 1);
        // The exact simulation instance returned by prepare must be what the
        // send usecase receives — no intermediate transformation.
        expect(identical(captured.single, confirmed), isTrue);
      },
    );

    test(
      'signAndBroadcast() refuses to sign when no simulation has been confirmed',
      () async {
        // Defense-in-depth: if the cubit is driven outside the prepare→confirm
        // flow (e.g. a test or programmatic listener), send must not be
        // called at all.
        await cubit.load();
        cubit.previewRecipient('sp1qexampleaddress');
        cubit.setAmount(BigInt.from(5000));
        // Intentionally skip prepare().

        await cubit.signAndBroadcast();

        expect(cubit.state.error, isNotNull);
        expect(cubit.state.error!.message, contains('missing simulation'));
        verifyNever(
          () => sendUsecase.execute(simulation: any(named: 'simulation')),
        );
      },
    );

    test(
      'signAndBroadcast() survives cubit.close() mid-broadcast: txid is logged, no emit-after-close, send called once',
      () async {
        await cubit.load();
        cubit.previewRecipient('sp1qexampleaddress');
        cubit.setAmount(BigInt.from(5000));
        // confirm a simulation before driving Confirm.
        await cubit.prepare();

        // Capture log records emitted during this test. The repository's
        // `log.info(...)` writes through `Logger.root` (logging package),
        // so installing a listener on the root logger lets us assert that
        // the txid is captured in the device log even when the cubit is
        // closed before it can `emit` the success state.
        final records = <LogRecord>[];
        final previousLevel = Logger.root.level;
        Logger.root.level = Level.ALL;
        final logSub = Logger.root.onRecord.listen(records.add);

        // Gate the send so we control exactly when it resolves. We close the
        // cubit BEFORE releasing the gate, simulating the user popping the SP
        // route while the FRB broadcast worker is still running. Without the
        // `isClosed` guards, the post-await `emit(state.copyWith(txid: txid))`
        // would throw `StateError: emit was called after close`.
        final gate = Completer<String>();
        when(
          () => sendUsecase.execute(simulation: any(named: 'simulation')),
        ).thenAnswer((_) async {
          final txid = await gate.future;
          log.info('SP broadcast txid: $txid');
          return txid;
        });

        // Track any unhandled errors that escape from the in-flight future
        // (the cubit catches its own exceptions, but emit-after-close would
        // bubble as an async error).
        final asyncErrors = <Object>[];
        final inFlight = runZonedGuarded<Future<void>>(
          () => cubit.signAndBroadcast(),
          (error, _) => asyncErrors.add(error),
        )!;

        // Yield once so signAndBroadcast advances past the guards and is
        // awaiting on the send usecase.
        await Future<void>.delayed(Duration.zero);

        // Close mid-broadcast.
        await cubit.close();
        expect(cubit.isClosed, isTrue);

        // Now release the broadcast — tx hits the network AFTER the cubit is
        // gone. The post-await code path must not throw and must log the txid.
        gate.complete(fakeTxid);
        await inFlight;
        await Future<void>.delayed(Duration.zero);

        await logSub.cancel();
        Logger.root.level = previousLevel;

        // 1. No emit-after-close exception escaped.
        expect(asyncErrors, isEmpty);

        // 2. Txid was logged to the side channel that survives close().
        final infoLogs = records
            .where((r) => r.level == Level.INFO)
            .map((r) => r.message)
            .toList();
        expect(
          infoLogs.any((m) => m.contains(fakeTxid)),
          isTrue,
          reason:
              'Expected the broadcast txid to be logged at INFO level so it '
              'survives a cubit-close race. Got info logs: $infoLogs',
        );

        // 3. Send ran exactly once (no retry, no duplicate send).
        verify(
          () => sendUsecase.execute(simulation: any(named: 'simulation')),
        ).called(1);
      },
    );

    test(
      'signAndBroadcast() is re-entrancy guarded: concurrent calls broadcast once',
      () async {
        await cubit.load();
        cubit.previewRecipient('sp1qexampleaddress');
        cubit.setAmount(BigInt.from(5000));
        // confirm a simulation before driving Confirm.
        await cubit.prepare();

        // Make send block until we release the completer, so the second call
        // lands while the first is still in flight.
        final gate = Completer<String>();
        when(
          () => sendUsecase.execute(simulation: any(named: 'simulation')),
        ).thenAnswer((_) => gate.future);

        final first = cubit.signAndBroadcast();
        // Fire the second call without awaiting; it should observe
        // isBroadcasting=true and no-op.
        final second = cubit.signAndBroadcast();

        gate.complete(fakeTxid);
        await Future.wait([first, second]);

        // The irreversible send sequence must run exactly once even with
        // overlapping invocations.
        verify(
          () => sendUsecase.execute(simulation: any(named: 'simulation')),
        ).called(1);
        expect(cubit.state.txid, fakeTxid);
        expect(cubit.state.isBroadcasting, false);
      },
    );
  });

  group('Standard address send flow', () {
    test('previewRecipient sets RecipientView.standard for bc1... address', () {
      cubit.previewRecipient('bc1qexampleaddress');
      expect(cubit.state.hasSendRecipient, true);
      expect(cubit.state.recipient, isA<RecipientView_Standard>());
    });

    test('prepare() succeeds for standard address', () async {
      await cubit.load();
      cubit.previewRecipient('bc1qexampleaddress');
      cubit.setAmount(BigInt.from(5000));

      await cubit.prepare();

      expect(cubit.state.txSimulation, isNotNull);
      expect(cubit.state.error, isNull);
    });

    test('signAndBroadcast() completes full standard send flow', () async {
      await cubit.load();
      cubit.previewRecipient('bc1qexampleaddress');
      cubit.setAmount(BigInt.from(5000));
      // confirm a simulation before driving Confirm.
      await cubit.prepare();

      await cubit.signAndBroadcast();

      expect(cubit.state.txid, fakeTxid);
      expect(cubit.state.sendSuccess, true);
    });
  });

  group('Send error handling', () {
    test('prepare() sets error when recipient is null', () async {
      await cubit.prepare();
      expect(cubit.state.error, isNotNull);
    });

    test('prepare() sets error when the usecase throws', () async {
      when(
        () => prepareUsecase.execute(
          recipients: any(named: 'recipients'),
          feerateSatVb: any(named: 'feerateSatVb'),
        ),
      ).thenThrow(Exception('insufficient funds'));

      cubit.previewRecipient('sp1qtest');
      cubit.setAmount(BigInt.from(999999999));
      await cubit.prepare();

      expect(cubit.state.error, isNotNull);
      expect(cubit.state.isLoading, false);
    });

    test('resetSendFlow() clears all send state', () async {
      cubit.previewRecipient('sp1qtest');
      cubit.setAmount(BigInt.from(5000));

      cubit.resetSendFlow();

      expect(cubit.state.recipient, isNull);
      expect(cubit.state.amountSat, isNull);
      expect(cubit.state.txSimulation, isNull);
      expect(cubit.state.txid, '');
      expect(cubit.state.error, isNull);
    });
  });

  group('ScanSpWalletUsecase isolation', () {
    test('prepare() does not invoke ScanSpWalletUsecase', () async {
      cubit.previewRecipient('sp1qtest');
      cubit.setAmount(BigInt.from(5000));
      await cubit.prepare();

      verifyNever(() => scanUsecase.execute());
    });

    test('signAndBroadcast() does not invoke ScanSpWalletUsecase', () async {
      cubit.previewRecipient('sp1qtest');
      cubit.setAmount(BigInt.from(5000));
      // even when the missing-simulation guard rejects the call (no
      // prepare()), no scan must be triggered.
      await cubit.signAndBroadcast();

      verifyNever(() => scanUsecase.execute());
    });
  });
}
