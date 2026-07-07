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
import 'package:bull_sdk/bwk.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// --- mocks ---

class _MockLoadSpWalletDataUsecase extends Mock
    implements LoadSpWalletDataUsecase {}

class _MockWatchSpNotificationsUsecase extends Mock
    implements WatchSpNotificationsUsecase {}

class _MockStopSpScanUsecase extends Mock implements StopSpScanUsecase {}

class _MockPrepareSpPaymentUsecase extends Mock
    implements PrepareSpPaymentUsecase {}

class _MockSendSpPaymentUsecase extends Mock implements SendSpPaymentUsecase {}

class _MockRevokeSpWalletUsecase extends Mock implements RevokeSpWalletUsecase {}

class _MockGenerateTaprootAddressUsecase extends Mock
    implements GenerateTaprootAddressUsecase {}

// Dart-side call counter — the simpler alternative to a Rust-level counter.
// Counts how many times ScanSpWalletUsecase.execute() is invoked.
// The count stays 0 unless the user explicitly triggers scan().
class _CountingScanUsecase implements ScanSpWalletUsecase {
  int callCount = 0;

  @override
  Future<void> execute({int? startHeight}) async {
    callCount++;
  }
}

void main() {
  late _MockLoadSpWalletDataUsecase loadUsecase;
  late _MockWatchSpNotificationsUsecase watchUsecase;
  late _CountingScanUsecase scanUsecase;
  late SpCubit cubit;
  late StreamController<SpNotification> notifController;

  final fakeWallet = SpWallet(
    spAddress: 'sp1qtest',
    balance: SpBalance(
      confirmedSat: BigInt.from(5000),
      totalUnifiedSat: BigInt.from(5000),
    ),
    isScanning: false,
  );

  setUp(() {
    loadUsecase = _MockLoadSpWalletDataUsecase();
    watchUsecase = _MockWatchSpNotificationsUsecase();
    scanUsecase = _CountingScanUsecase();
    notifController = StreamController<SpNotification>.broadcast();

    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => SpWalletData(
        wallet: fakeWallet,
        history: const <SpPaymentView>[],
        coins: const <UnifiedCoinView>[],
        network: SpNetwork.regtest,
        backendOnline: true,
      ),
    );
    when(() => watchUsecase.execute()).thenAnswer((_) => notifController.stream);

    cubit = SpCubit(
      loadSpWalletDataUsecase: loadUsecase,
      watchSpNotificationsUsecase: watchUsecase,
      scanSpWalletUsecase: scanUsecase,
      stopSpScanUsecase: _MockStopSpScanUsecase(),
      prepareSpPaymentUsecase: _MockPrepareSpPaymentUsecase(),
      sendSpPaymentUsecase: _MockSendSpPaymentUsecase(),
      revokeSpWalletUsecase: _MockRevokeSpWalletUsecase(),
      generateTaprootAddressUsecase: _MockGenerateTaprootAddressUsecase(),
    );
  });

  tearDown(() async {
    await cubit.close();
    await notifController.close();
  });

  group('SP no-autoscan invariant (integration)', () {
    test('counter is 0 after init — scan was not auto-triggered', () async {
      expect(scanUsecase.callCount, 0);
      await cubit.load();
      await Future.delayed(Duration.zero);
      // Counter is still 0 after navigating (receive tabs, settings, about).
      cubit.setReceiveTab(0); // SP tab
      cubit.setReceiveTab(1); // Segwit tab
      cubit.setReceiveTab(2); // Taproot tab
      cubit.setReceiveTab(0);
      await Future.delayed(Duration.zero);
      expect(scanUsecase.callCount, 0);
    });

    test('Electrum tx push does not increment counter', () async {
      await cubit.load();
      notifController.add(
        SpNotification.electrumTx(
          kind: CoinSource.segwit,
          txid: 'aabbcc',
          amountSat: BigInt.from(1000),
        ),
      );
      await Future.delayed(Duration.zero);
      expect(scanUsecase.callCount, 0);
    });

    test('NewOutput notification does not increment counter', () async {
      await cubit.load();
      notifController.add(
        SpNotification.newOutput(outpoint: 'abc:0', amountSat: BigInt.zero),
      );
      await Future.delayed(Duration.zero);
      expect(scanUsecase.callCount, 0);
    });

    test('ScanCompleted notification does not re-trigger scan', () async {
      await cubit.load();
      notifController.add(const SpNotification.scanCompleted());
      await Future.delayed(Duration.zero);
      expect(scanUsecase.callCount, 0);
    });

    test('explicit scan() increments counter to 1', () async {
      await cubit.load();
      expect(scanUsecase.callCount, 0);

      await cubit.scan();

      expect(scanUsecase.callCount, 1);
    });

    test('counter stays at 1 after scan() — no second auto-invocation', () async {
      await cubit.load();
      await cubit.scan();
      expect(scanUsecase.callCount, 1);

      notifController.add(
        const SpNotification.scanStarted(from: 800000, to: 850000),
      );
      await Future.delayed(Duration.zero);
      notifController.add(const SpNotification.scanCompleted());
      await Future.delayed(Duration.zero);

      expect(scanUsecase.callCount, 1);
    });

    test('second explicit scan() increments counter to 2', () async {
      await cubit.load();
      await cubit.scan();
      await cubit.scan();
      expect(scanUsecase.callCount, 2);
    });
  });
}
