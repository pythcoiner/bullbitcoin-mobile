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
import 'package:bb_mobile/features/sp/ui/sp_receive_page.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
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

class _MockSpCubit extends Mock implements SpCubit {}

SpWalletData _walletData({
  SpBalance? balance,
  List<SpPaymentView> history = const <SpPaymentView>[],
  bool isScanning = false,
  int? lastScannedHeight,
}) => SpWalletData(
  wallet: SpWallet(
    spAddress: 'sp1qtestaddress',
    balance:
        balance ??
        SpBalance(confirmedSat: BigInt.zero, totalUnifiedSat: BigInt.zero),
    isScanning: isScanning,
    lastScannedHeight: lastScannedHeight,
  ),
  history: history,
  coins: const [],
  network: SpNetwork.bitcoin,
  backendOnline: true,
);

Widget _buildPage(SpCubit cubit) => MaterialApp(
  home: BlocProvider<SpCubit>.value(value: cubit, child: const SpReceivePage()),
);

Widget _buildMockPage(_MockSpCubit cubit) => MaterialApp(
  home: BlocProvider<SpCubit>.value(value: cubit, child: const SpReceivePage()),
);

void main() {
  late _MockLoadSpWalletDataUsecase loadUsecase;
  late _MockGenerateTaprootAddressUsecase generateUsecase;
  late SpCubit cubit;

  setUp(() {
    loadUsecase = _MockLoadSpWalletDataUsecase();
    when(() => loadUsecase.execute()).thenAnswer((_) async => _walletData());

    final watchUsecase = _MockWatchSpNotificationsUsecase();
    when(
      () => watchUsecase.execute(),
    ).thenAnswer((_) => openSpNotificationStream());

    generateUsecase = _MockGenerateTaprootAddressUsecase();

    cubit = SpCubit(
      loadSpWalletDataUsecase: loadUsecase,
      watchSpNotificationsUsecase: watchUsecase,
      scanSpWalletUsecase: _MockScanSpWalletUsecase(),
      stopSpScanUsecase: _MockStopSpScanUsecase(),
      prepareSpPaymentUsecase: _MockPrepareSpPaymentUsecase(),
      sendSpPaymentUsecase: _MockSendSpPaymentUsecase(),
      revokeSpWalletUsecase: _MockRevokeSpWalletUsecase(),
      generateTaprootAddressUsecase: generateUsecase,
    );
  });

  tearDown(() => cubit.close());

  testWidgets('renders Receive title', (tester) async {
    await tester.pumpWidget(_buildPage(cubit));

    expect(find.text('Receive'), findsOneWidget);
  });

  testWidgets('renders Silent Payment and Taproot tabs (no Segwit)', (
    tester,
  ) async {
    await tester.pumpWidget(_buildPage(cubit));

    expect(find.text('Silent Payment'), findsOneWidget);
    expect(find.text('Taproot'), findsOneWidget);
    expect(find.text('Segwit'), findsNothing);
  });

  testWidgets('shows manual scan callout on SP tab', (tester) async {
    await cubit.load();
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    expect(find.text('Manual scan required'), findsOneWidget);
    expect(
      find.text('This address is reusable. Funds arrive after you tap Scan.'),
      findsOneWidget,
    );
  });

  testWidgets('SP tab shows the reusable address', (tester) async {
    await cubit.load();
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    expect(find.byType(TabBar), findsOneWidget);
    expect(find.text('sp1qtestaddress'), findsOneWidget);
  });

  testWidgets('SP tab shows loading content without empty address widgets', (
    tester,
  ) async {
    final mockCubit = _MockSpCubit();
    when(() => mockCubit.state).thenReturn(const SpState(isLoading: true));
    when(() => mockCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockCubit.setReceiveTab(any())).thenReturn(null);

    await tester.pumpWidget(_buildMockPage(mockCubit));
    await tester.pump();

    expect(find.byType(LoadingBoxContent), findsOneWidget);
    expect(find.byType(QrDisplayWidget), findsNothing);
    expect(find.byType(CopyInput), findsNothing);
  });

  testWidgets('SP tab empty address state does not render QR or copy input', (
    tester,
  ) async {
    final mockCubit = _MockSpCubit();
    when(() => mockCubit.state).thenReturn(const SpState());
    when(() => mockCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => mockCubit.setReceiveTab(any())).thenReturn(null);

    await tester.pumpWidget(_buildMockPage(mockCubit));
    await tester.pump();

    expect(
      find.text(
        'Reusable address unavailable. Pull to refresh or reopen the wallet.',
      ),
      findsOneWidget,
    );
    expect(find.byType(QrDisplayWidget), findsNothing);
    expect(find.byType(CopyInput), findsNothing);
  });

  testWidgets(
    'Taproot tab initially shows a Generate address button (no address)',
    (tester) async {
      await tester.pumpWidget(_buildPage(cubit));
      await tester.pump();

      await tester.tap(find.text('Taproot'));
      await tester.pumpAndSettle();

      expect(find.text('Generate address'), findsOneWidget);
      // No address revealed yet.
      expect(find.text('bcrt1ptaprootnew'), findsNothing);
    },
  );

  testWidgets(
    'tapping Generate address calls the usecase and reveals the address',
    (tester) async {
      when(
        () => generateUsecase.execute(),
      ).thenAnswer((_) async => 'bcrt1ptaprootnew');

      await tester.pumpWidget(_buildPage(cubit));
      await tester.pump();

      await tester.tap(find.text('Taproot'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Generate address'));
      await tester.pumpAndSettle();

      verify(() => generateUsecase.execute()).called(1);
      // The freshly generated address is rendered (QR + copy input).
      expect(find.text('bcrt1ptaprootnew'), findsWidgets);
      // Button now offers a fresh address.
      expect(find.text('Generate new address'), findsOneWidget);
    },
  );
}
