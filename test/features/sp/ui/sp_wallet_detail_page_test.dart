import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
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
import 'package:bb_mobile/features/sp/router.dart';
import 'package:bb_mobile/features/sp/ui/sp_wallet_detail_page.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_detail_balance_card.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockBitcoinPriceBloc extends Mock implements BitcoinPriceBloc {}

SettingsState _settingsState() => SettingsState(
  storedSettings: SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    hideAmounts: false,
  ),
);

SpWalletData _walletData({
  List<SpPaymentView> history = const <SpPaymentView>[],
  List<UnifiedCoinView> coins = const <UnifiedCoinView>[],
  bool isScanning = false,
  int? lastScannedHeight,
}) => SpWalletData(
  wallet: SpWallet(
    spAddress: 'sp1qtest',
    balance: SpBalance(
      confirmedSat: BigInt.from(5000),
      totalUnifiedSat: BigInt.from(5000),
    ),
    isScanning: isScanning,
    lastScannedHeight: lastScannedHeight,
  ),
  history: history,
  coins: coins,
  network: SpNetwork.bitcoin,
  backendOnline: true,
);

Widget _buildPage({
  required SpCubit cubit,
  required SettingsCubit settingsCubit,
  required BitcoinPriceBloc bitcoinPriceBloc,
}) => MaterialApp(
  home: MultiBlocProvider(
    providers: [
      BlocProvider<SpCubit>.value(value: cubit),
      BlocProvider<SettingsCubit>.value(value: settingsCubit),
      BlocProvider<BitcoinPriceBloc>.value(value: bitcoinPriceBloc),
    ],
    child: const SpWalletDetailPage(),
  ),
);

void main() {
  late _MockLoadSpWalletDataUsecase loadUsecase;
  late _MockSettingsCubit settingsCubit;
  late _MockBitcoinPriceBloc bitcoinPriceBloc;
  late _MockScanSpWalletUsecase scanUsecase;
  late SpCubit cubit;

  setUp(() {
    loadUsecase = _MockLoadSpWalletDataUsecase();
    scanUsecase = _MockScanSpWalletUsecase();
    settingsCubit = _MockSettingsCubit();
    bitcoinPriceBloc = _MockBitcoinPriceBloc();
    when(() => settingsCubit.state).thenReturn(_settingsState());
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => bitcoinPriceBloc.state).thenReturn(const BitcoinPriceState());
    when(() => bitcoinPriceBloc.stream).thenAnswer((_) => const Stream.empty());
    when(() => loadUsecase.execute()).thenAnswer((_) async => _walletData());

    final watchUsecase = _MockWatchSpNotificationsUsecase();
    when(
      () => watchUsecase.execute(),
    ).thenAnswer((_) => openSpNotificationStream());

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

  tearDown(() => cubit.close());

  Future<void> pumpPage(WidgetTester tester) async {
    await tester.pumpWidget(
      _buildPage(
        cubit: cubit,
        settingsCubit: settingsCubit,
        bitcoinPriceBloc: bitcoinPriceBloc,
      ),
    );
  }

  testWidgets('renders wallet title', (tester) async {
    await pumpPage(tester);

    expect(find.text('Silent Payment Wallet'), findsOneWidget);
  });

  testWidgets('renders bottom action buttons', (tester) async {
    await pumpPage(tester);

    expect(find.text('Receive'), findsOneWidget);
    expect(find.text('Send'), findsOneWidget);
    expect(find.text('Scan'), findsOneWidget);
  });

  testWidgets('uses wallet detail balance card', (tester) async {
    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(find.byType(WalletDetailBalanceCard), findsOneWidget);
  });

  testWidgets('shows Activity section header', (tester) async {
    await pumpPage(tester);
    await tester.pump();

    expect(find.text('Activity'), findsOneWidget);
  });

  testWidgets('shows empty state message when no history', (tester) async {
    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(
      find.text('Tap Scan to look for incoming silent payments'),
      findsOneWidget,
    );
  });

  testWidgets('shows payment tiles when history is non-empty', (tester) async {
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => _walletData(
        history: [
          SpPaymentView(
            txid: 'aa' * 32,
            direction: SpPaymentDirection.receive,
            amountSat: BigInt.from(1000),
          ),
        ],
      ),
    );
    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(find.text('1 000 sats'), findsOneWidget);
  });

  testWidgets('shows scan strip when scanning', (tester) async {
    when(() => loadUsecase.execute()).thenAnswer(
      (_) async => _walletData(isScanning: true, lastScannedHeight: 800000),
    );
    await cubit.load();
    await pumpPage(tester);
    await tester.pump();

    expect(find.byType(LinearProgressIndicator), findsWidgets);
  });

  testWidgets('Scan button navigates to the scan page without scanning', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/detail',
      routes: [
        GoRoute(
          path: '/detail',
          builder: (context, state) => MultiBlocProvider(
            providers: [
              BlocProvider<SpCubit>.value(value: cubit),
              BlocProvider<SettingsCubit>.value(value: settingsCubit),
              BlocProvider<BitcoinPriceBloc>.value(value: bitcoinPriceBloc),
            ],
            child: const SpWalletDetailPage(),
          ),
        ),
        GoRoute(
          name: SpRoute.spScan.name,
          path: '/scan',
          builder: (context, state) =>
              const Scaffold(body: Text('scan page reached')),
        ),
      ],
    );
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pump();

    await tester.tap(find.text('Scan'));
    await tester.pumpAndSettle();

    expect(find.text('scan page reached'), findsOneWidget);
    // The button must only navigate; starting the scan is the scan view's job.
    verifyNever(() => scanUsecase.execute());
  });
}
