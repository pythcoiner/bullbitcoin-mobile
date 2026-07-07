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
import 'package:bb_mobile/features/sp/ui/sp_scan_page.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

class _MockRevokeSpWalletUsecase extends Mock
    implements RevokeSpWalletUsecase {}

class _MockGenerateTaprootAddressUsecase extends Mock
    implements GenerateTaprootAddressUsecase {}

SpWalletData _walletData({
  bool isScanning = false,
  int? lastScannedHeight,
  int? chainTip,
  int minBirthdayHeight = 0,
}) => SpWalletData(
  wallet: SpWallet(
    spAddress: 'sp1qtest',
    balance: SpBalance(confirmedSat: BigInt.zero, totalUnifiedSat: BigInt.zero),
    isScanning: isScanning,
    lastScannedHeight: lastScannedHeight,
  ),
  history: const <SpPaymentView>[],
  coins: const [],
  network: SpNetwork.bitcoin,
  backendOnline: true,
  chainTip: chainTip,
  minBirthdayHeight: minBirthdayHeight,
);

Widget _buildPage(SpCubit cubit) => MaterialApp(
  home: BlocProvider<SpCubit>.value(value: cubit, child: const SpScanPage()),
);

void main() {
  late _MockLoadSpWalletDataUsecase loadUsecase;
  late _MockStopSpScanUsecase stopUsecase;
  late _MockScanSpWalletUsecase scanUsecase;
  late _MockWatchSpNotificationsUsecase watchUsecase;
  late SpCubit cubit;

  setUp(() {
    loadUsecase = _MockLoadSpWalletDataUsecase();
    when(() => loadUsecase.execute()).thenAnswer((_) async => _walletData());

    stopUsecase = _MockStopSpScanUsecase();
    when(() => stopUsecase.execute()).thenAnswer((_) async {});

    scanUsecase = _MockScanSpWalletUsecase();
    when(
      () => scanUsecase.execute(startHeight: any(named: 'startHeight')),
    ).thenAnswer((_) async {});

    watchUsecase = _MockWatchSpNotificationsUsecase();
    when(
      () => watchUsecase.execute(),
    ).thenAnswer((_) => openSpNotificationStream());

    cubit = SpCubit(
      loadSpWalletDataUsecase: loadUsecase,
      watchSpNotificationsUsecase: watchUsecase,
      scanSpWalletUsecase: scanUsecase,
      stopSpScanUsecase: stopUsecase,
      prepareSpPaymentUsecase: _MockPrepareSpPaymentUsecase(),
      sendSpPaymentUsecase: _MockSendSpPaymentUsecase(),
      revokeSpWalletUsecase: _MockRevokeSpWalletUsecase(),
      generateTaprootAddressUsecase: _MockGenerateTaprootAddressUsecase(),
    );
  });

  tearDown(() => cubit.close());

  Future<void> loadWith(WidgetTester tester, SpWalletData data) async {
    when(() => loadUsecase.execute()).thenAnswer((_) async => data);
    await cubit.load();
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();
  }

  testWidgets('renders scan page title', (tester) async {
    await tester.pumpWidget(_buildPage(cubit));
    expect(find.text('Scan'), findsOneWidget);
  });

  testWidgets('scanning shows progress indicator and Stop', (tester) async {
    await loadWith(tester, _walletData(isScanning: true));

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Stop'), findsOneWidget);
  });

  testWidgets('scan progress shows determinate circular and current/target', (
    tester,
  ) async {
    final controller = StreamController<SpNotification>.broadcast();
    addTearDown(controller.close);
    when(() => watchUsecase.execute()).thenAnswer((_) => controller.stream);

    await cubit.load();
    await tester.pumpWidget(_buildPage(cubit));

    controller.add(const SpNotification.scanStarted(from: 1, to: 9));
    await tester.pump();
    controller.add(const SpNotification.scanReceiveProgress(current: 5, end: 9));
    await tester.pump();

    expect(find.text('5 / 9'), findsOneWidget);
    expect(find.text('50%'), findsOneWidget);
    expect(find.text('Step 1 of 2: Receiving'), findsOneWidget);
    expect(find.textContaining('Elapsed'), findsOneWidget);
    final indicator = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(indicator.value, closeTo(0.5, 0.001));
  });

  testWidgets('Stop button calls stopScan usecase once', (tester) async {
    await loadWith(tester, _walletData(isScanning: true));

    await tester.tap(find.text('Stop'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    verify(() => stopUsecase.execute()).called(1);
  });

  testWidgets('never scanned with bounds shows the start-height chooser', (
    tester,
  ) async {
    await loadWith(
      tester,
      _walletData(chainTip: 900000, minBirthdayHeight: 709632),
    );

    expect(find.byType(Slider), findsOneWidget);
    expect(find.text('Earliest'), findsOneWidget);
    expect(find.text('Start scan from 709632'), findsOneWidget);
  });

  testWidgets('tapping Start from chosen height scans from that height', (
    tester,
  ) async {
    await loadWith(
      tester,
      _walletData(chainTip: 900000, minBirthdayHeight: 709632),
    );

    await tester.tap(find.text('Start scan from 709632'));
    await tester.pump();

    verify(() => scanUsecase.execute(startHeight: 709632)).called(1);
  });

  testWidgets('already scanned shows the next start read-only and resumes', (
    tester,
  ) async {
    await loadWith(
      tester,
      _walletData(lastScannedHeight: 800000, chainTip: 900000),
    );

    expect(find.text('100000 blocks behind'), findsOneWidget);
    expect(find.text('~1 year 10 months'), findsOneWidget);
    expect(find.byType(Slider), findsNothing);

    await tester.tap(find.text('Start scan'));
    await tester.pump();

    // Resume: no start height (null) is forwarded.
    verify(() => scanUsecase.execute(startHeight: null)).called(1);
  });

  testWidgets('caught up at the tip shows a working Start scan button', (
    tester,
  ) async {
    await loadWith(
      tester,
      _walletData(lastScannedHeight: 900000, chainTip: 900000),
    );

    expect(find.text('Caught up at block 900000'), findsOneWidget);
    // No height chooser after the initial scan; just a resume button.
    expect(find.byType(Slider), findsNothing);

    await tester.tap(find.text('Start scan'));
    await tester.pump();

    // Resume: no start height (null) is forwarded; bwk scans to the live tip.
    verify(() => scanUsecase.execute(startHeight: null)).called(1);
  });

  testWidgets('shows total scan duration after a completed scan', (
    tester,
  ) async {
    final controller = StreamController<SpNotification>.broadcast();
    addTearDown(controller.close);
    when(() => watchUsecase.execute()).thenAnswer((_) => controller.stream);
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => _walletData(lastScannedHeight: 900000, chainTip: 900000),
    );

    await cubit.load();
    await tester.pumpWidget(_buildPage(cubit));

    controller.add(const SpNotification.scanStarted(from: 800000, to: 900000));
    await tester.pump();
    controller.add(const SpNotification.scanCompleted());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Caught up at block 900000'), findsOneWidget);
    expect(find.textContaining('Scanned in'), findsOneWidget);
  });

  testWidgets('does not call stopScan on dispose', (tester) async {
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: Text('other'))),
    );
    await tester.pump();

    expect(find.text('other'), findsOneWidget);
    verifyNever(() => stopUsecase.execute());
  });
}
