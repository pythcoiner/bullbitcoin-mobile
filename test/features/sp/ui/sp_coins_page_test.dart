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
import 'package:bb_mobile/features/sp/ui/sp_coins_page.dart';
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

class _MockRevokeSpWalletUsecase extends Mock implements RevokeSpWalletUsecase {}

class _MockGenerateTaprootAddressUsecase extends Mock
    implements GenerateTaprootAddressUsecase {}

SpWalletData _walletData(List<UnifiedCoinView> coins) => SpWalletData(
  wallet: SpWallet(
    spAddress: 'sp1qtest',
    balance: SpBalance(confirmedSat: BigInt.zero, totalUnifiedSat: BigInt.zero),
    isScanning: false,
  ),
  history: const <SpPaymentView>[],
  coins: coins,
  network: SpNetwork.bitcoin,
  backendOnline: true,
);

Widget _buildPage(SpCubit cubit) => MaterialApp(
  home: BlocProvider<SpCubit>.value(value: cubit, child: const SpCoinsPage()),
);

void main() {
  late _MockLoadSpWalletDataUsecase loadUsecase;
  late SpCubit cubit;

  setUp(() {
    loadUsecase = _MockLoadSpWalletDataUsecase();
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

  Future<void> loadWith(WidgetTester tester, List<UnifiedCoinView> coins) async {
    when(() => loadUsecase.execute()).thenAnswer((_) async => _walletData(coins));
    await cubit.load();
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();
  }

  testWidgets('renders coins with amount, source badge, and confirmation', (
    tester,
  ) async {
    await loadWith(tester, [
      UnifiedCoinView(
        source: CoinSource.taproot,
        outpoint: 'aabbccddeeff00112233:0',
        amountSat: BigInt.from(50000),
        height: 850000,
        status: UnifiedCoinStatus.unspent,
      ),
      UnifiedCoinView(
        source: CoinSource.sp,
        outpoint: 'ffeeddccbbaa99887766:1',
        amountSat: BigInt.from(1000),
        height: null,
        status: UnifiedCoinStatus.unconfirmed,
      ),
      UnifiedCoinView(
        source: CoinSource.sp,
        outpoint: 'cafebabedeadbeef0011:2',
        amountSat: BigInt.from(7000),
        height: 840000,
        status: UnifiedCoinStatus.spent,
      ),
    ]);

    expect(find.text('50 000 sats'), findsOneWidget);
    expect(find.text('1 000 sats'), findsOneWidget);
    expect(find.text('TR'), findsOneWidget);
    expect(find.text('SP'), findsNWidgets(2));
    expect(find.textContaining('Block 850000'), findsOneWidget);
    // Status icons with tooltips, one per status.
    expect(find.byTooltip('Unspent'), findsOneWidget);
    expect(find.byTooltip('Unconfirmed'), findsOneWidget);
    expect(find.byTooltip('Spent'), findsOneWidget);
  });

  testWidgets('shows empty state when there are no coins', (tester) async {
    await loadWith(tester, const []);

    expect(find.text('No coins yet'), findsOneWidget);
  });
}
