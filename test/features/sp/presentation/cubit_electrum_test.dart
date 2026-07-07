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
    confirmedSat: BigInt.from(3000),
    totalUnifiedSat: BigInt.from(3000),
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

  test('ElectrumTx notification triggers wallet data reload', () async {
    await cubit.load();
    clearInteractions(loadUsecase);

    notifController.add(
      SpNotification.electrumTx(
        kind: CoinSource.segwit,
        txid: 'aabbcc',
        amountSat: BigInt.from(1000),
      ),
    );
    await Future.delayed(Duration.zero);

    verify(() => loadUsecase.execute()).called(greaterThanOrEqualTo(1));
  });

  test('ElectrumTx notification does NOT invoke ScanSpWalletUsecase.execute', () async {
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

  test('NewOutput notification triggers data reload without scan', () async {
    await cubit.load();
    clearInteractions(loadUsecase);

    notifController.add(
      SpNotification.newOutput(
        outpoint: 'abc:0',
        amountSat: BigInt.zero,
      ),
    );
    await Future.delayed(Duration.zero);

    verify(() => loadUsecase.execute()).called(greaterThanOrEqualTo(1));
    verifyNever(() => scanUsecase.execute());
  });

  test('OutputSpent notification triggers data reload without scan', () async {
    await cubit.load();
    clearInteractions(loadUsecase);

    notifController.add(
      const SpNotification.outputSpent(outpoint: 'abc:0'),
    );
    await Future.delayed(Duration.zero);

    verify(() => loadUsecase.execute()).called(greaterThanOrEqualTo(1));
    verifyNever(() => scanUsecase.execute());
  });

  test('BackendOffline notification does not change isScanning state', () async {
    await cubit.load();

    notifController.add(const SpNotification.backendOffline());
    await Future.delayed(Duration.zero);

    expect(cubit.state.isScanning, false);
    verifyNever(() => scanUsecase.execute());
  });
}
