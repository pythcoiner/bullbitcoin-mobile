import 'package:bb_mobile/features/sp/application/usecases/generate_taproot_address_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/prepare_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/scan_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/send_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/stop_sp_scan_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/watch_sp_notifications_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/cubit.dart';
import 'package:bb_mobile/features/sp/presentation/state.dart';
import 'package:bb_mobile/features/sp/ui/sp_send_confirm_page.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

class _MockRevokeSpWalletUsecase extends Mock
    implements RevokeSpWalletUsecase {}

class _MockGenerateTaprootAddressUsecase extends Mock
    implements GenerateTaprootAddressUsecase {}

// Exposes emit for testing
class _TestSpCubit extends SpCubit {
  _TestSpCubit({
    required super.loadSpWalletDataUsecase,
    required super.watchSpNotificationsUsecase,
    required super.scanSpWalletUsecase,
    required super.stopSpScanUsecase,
    required super.prepareSpPaymentUsecase,
    required super.sendSpPaymentUsecase,
    required super.revokeSpWalletUsecase,
    required super.generateTaprootAddressUsecase,
  });

  void emitTestState(SpState state) => emit(state);
}

Widget _buildPage(_TestSpCubit cubit) => MaterialApp(
  home: BlocProvider<SpCubit>.value(
    value: cubit,
    child: const SpSendConfirmPage(),
  ),
);

void main() {
  setUpAll(() {
    registerFallbackValue(<RecipientView>[]);
    registerFallbackValue(BigInt.zero);
  });

  late _TestSpCubit cubit;

  final fakeTxSimulation = TxSimulation(
    inputs: [
      UnifiedCoinView(
        source: CoinSource.segwit,
        outpoint: 'abc123:0',
        amountSat: BigInt.from(10000),
        status: UnifiedCoinStatus.unspent,
      ),
    ],
    outputs: [],
    feeSat: BigInt.from(200),
    changeSat: BigInt.from(4800),
  );

  setUp(() {
    final watchUsecase = _MockWatchSpNotificationsUsecase();
    when(() => watchUsecase.execute()).thenAnswer((_) => const Stream.empty());

    cubit = _TestSpCubit(
      loadSpWalletDataUsecase: _MockLoadSpWalletDataUsecase(),
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

  testWidgets('renders Confirm title', (tester) async {
    await tester.pumpWidget(_buildPage(cubit));

    expect(find.text('Confirm'), findsOneWidget);
  });

  testWidgets('shows Sign and Broadcast button', (tester) async {
    await tester.pumpWidget(_buildPage(cubit));

    expect(find.text('Sign & Broadcast'), findsOneWidget);
  });

  testWidgets('shows amount from state', (tester) async {
    cubit.emitTestState(
      SpState(
        amountSat: BigInt.from(5000),
        recipient: RecipientView.standard(
          address: 'bc1qtestrecipient',
          amountSat: BigInt.from(5000),
          isMax: false,
        ),
        txSimulation: fakeTxSimulation,
      ),
    );
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    expect(find.textContaining('5000 sats'), findsWidgets);
  });

  testWidgets('shows input source badge in inputs section', (tester) async {
    cubit.emitTestState(
      SpState(
        amountSat: BigInt.from(5000),
        recipient: RecipientView.standard(
          address: 'bc1qtestrecipient',
          amountSat: BigInt.from(5000),
          isMax: false,
        ),
        txSimulation: fakeTxSimulation,
      ),
    );
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    // Inputs section header is visible
    expect(find.textContaining('Inputs'), findsOneWidget);
  });

  testWidgets('shows fee row', (tester) async {
    cubit.emitTestState(
      SpState(
        amountSat: BigInt.from(5000),
        txSimulation: fakeTxSimulation,
      ),
    );
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    expect(find.text('Fee'), findsOneWidget);
  });
}
