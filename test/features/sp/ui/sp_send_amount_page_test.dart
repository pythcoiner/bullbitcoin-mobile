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
import 'package:bb_mobile/features/sp/ui/sp_send_amount_page.dart';
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

SpWalletData _walletData() => SpWalletData(
  wallet: SpWallet(
    spAddress: 'sp1qtest',
    balance: SpBalance(
      confirmedSat: BigInt.from(10000),
      totalUnifiedSat: BigInt.from(10000),
    ),
    isScanning: false,
  ),
  history: const <SpPaymentView>[],
  coins: const [],
  network: SpNetwork.bitcoin,
  backendOnline: true,
);

Widget _buildPage(SpCubit cubit) => MaterialApp(
  home: BlocProvider<SpCubit>.value(
    value: cubit,
    child: const SpSendAmountPage(),
  ),
);

void main() {
  late SpCubit cubit;

  setUp(() {
    final loadUsecase = _MockLoadSpWalletDataUsecase();
    when(() => loadUsecase.execute()).thenAnswer((_) async => _walletData());

    final watchUsecase = _MockWatchSpNotificationsUsecase();
    when(
      () => watchUsecase.execute(),
    ).thenAnswer((_) => openSpNotificationStream());

    cubit = SpCubit(
      loadSpWalletDataUsecase: loadUsecase,
      watchSpNotificationsUsecase: watchUsecase,
      scanSpWalletUsecase: _MockScanSpWalletUsecase(),
      stopSpScanUsecase: _MockStopSpScanUsecase(),
      prepareSpPaymentUsecase: _MockPrepareSpPaymentUsecase(),
      sendSpPaymentUsecase: _MockSendSpPaymentUsecase(),
      revokeSpWalletUsecase: _MockRevokeSpWalletUsecase(),
      generateTaprootAddressUsecase: _MockGenerateTaprootAddressUsecase(),
    );
  });

  tearDown(() => cubit.close());

  testWidgets('renders Amount title', (tester) async {
    await tester.pumpWidget(_buildPage(cubit));

    expect(find.text('Amount'), findsOneWidget);
  });

  testWidgets('shows amount input field with sats hint', (tester) async {
    await tester.pumpWidget(_buildPage(cubit));

    expect(find.text('Amount (sats)'), findsOneWidget);
    expect(find.text('0'), findsOneWidget);
  });

  testWidgets('shows fee rate section', (tester) async {
    await tester.pumpWidget(_buildPage(cubit));

    expect(find.text('Fee rate'), findsOneWidget);
    expect(find.text('Slow'), findsOneWidget);
    expect(find.text('Normal'), findsOneWidget);
    expect(find.text('Fast'), findsOneWidget);
  });

  testWidgets('shows Continue button', (tester) async {
    await tester.pumpWidget(_buildPage(cubit));

    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('shows available balance', (tester) async {
    await cubit.load();
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    expect(find.textContaining('Available'), findsOneWidget);
    expect(find.textContaining('10000 sats'), findsOneWidget);
  });
}
