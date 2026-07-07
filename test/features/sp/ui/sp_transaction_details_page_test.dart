import 'package:bb_mobile/features/sp/application/usecases/generate_taproot_address_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/prepare_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/scan_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/send_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/stop_sp_scan_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/watch_sp_notifications_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/cubit.dart';
import 'package:bb_mobile/features/sp/ui/sp_transaction_details_page.dart';
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

Widget _buildPage(SpCubit cubit, SpPaymentView payment) => MaterialApp(
  home: BlocProvider<SpCubit>.value(
    value: cubit,
    child: SpTransactionDetailsPage(payment: payment),
  ),
);

void main() {
  late SpCubit cubit;

  final incomingPayment = SpPaymentView(
    txid: 'aabbccdd' * 8,
    direction: SpPaymentDirection.receive,
    amountSat: BigInt.from(5000),
    height: 800000,
  );

  final outgoingPayment = SpPaymentView(
    txid: '11223344' * 8,
    direction: SpPaymentDirection.send,
    amountSat: BigInt.from(2500),
    feeSat: BigInt.from(150),
  );

  setUp(() {
    final loadUsecase = _MockLoadSpWalletDataUsecase();
    final watchUsecase = _MockWatchSpNotificationsUsecase();
    when(() => watchUsecase.execute()).thenAnswer((_) => const Stream.empty());

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

  testWidgets('renders transaction title', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, incomingPayment));

    expect(find.text('Transaction'), findsOneWidget);
  });

  testWidgets('shows amount for incoming payment', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, incomingPayment));

    expect(find.text('5 000 sats'), findsWidgets);
  });

  testWidgets('shows Confirmed when block height is set', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, incomingPayment));

    expect(find.text('Confirmed'), findsOneWidget);
  });

  testWidgets('shows Unconfirmed when no height', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, outgoingPayment));

    expect(find.text('Unconfirmed'), findsOneWidget);
  });

  testWidgets('shows fee when present', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, outgoingPayment));

    expect(find.text('Fee'), findsOneWidget);
  });

  testWidgets('shows close button', (tester) async {
    await tester.pumpWidget(_buildPage(cubit, incomingPayment));

    expect(find.byIcon(Icons.close), findsOneWidget);
  });
}
