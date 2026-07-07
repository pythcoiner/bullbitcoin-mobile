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
import 'package:bb_mobile/features/sp/ui/sp_send_success_page.dart';
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
    child: const SpSendSuccessPage(),
  ),
);

void main() {
  late _TestSpCubit cubit;

  setUp(() {
    final loadUsecase = _MockLoadSpWalletDataUsecase();
    final watchUsecase = _MockWatchSpNotificationsUsecase();
    when(() => watchUsecase.execute()).thenAnswer((_) => const Stream.empty());

    cubit = _TestSpCubit(
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

  testWidgets('renders Sent text', (tester) async {
    cubit.emitTestState(const SpState(txid: 'aabbccddeeff00112233'));
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    expect(find.text('Sent'), findsOneWidget);
  });

  testWidgets('renders check circle icon', (tester) async {
    cubit.emitTestState(const SpState(txid: 'aabbccddeeff00112233'));
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    expect(find.byIcon(Icons.check_circle), findsOneWidget);
  });

  testWidgets('shows Done button', (tester) async {
    cubit.emitTestState(const SpState(txid: 'aabbccddeeff00112233'));
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    expect(find.text('Done'), findsOneWidget);
  });

  testWidgets('shows txid copy widget', (tester) async {
    cubit.emitTestState(
      const SpState(
        txid:
            'aabbccddeeff001122334455667788990011223344556677889900112233445566',
      ),
    );
    await tester.pumpWidget(_buildPage(cubit));
    await tester.pump();

    // CopyInput is shown with the truncated txid
    expect(find.textContaining('...'), findsOneWidget);
  });

  testWidgets(
    'R4: wraps body in PopScope with canPop=false so system-back cannot land on the confirm page with a stale simulation',
    (tester) async {
      // Seed a "post-broadcast" state that still has txid set, mimicking the
      // moment the user lands on the success page.
      cubit.emitTestState(const SpState(txid: 'aabbccddeeff00112233'));
      await tester.pumpWidget(_buildPage(cubit));
      await tester.pump();

      // MaterialApp installs its own PopScope internally, so scope the find
      // to the canPop=false one our page declares.
      final blockingPopScope = find.byWidgetPredicate(
        (w) => w is PopScope && w.canPop == false,
      );
      expect(
        blockingPopScope,
        findsOneWidget,
        reason: 'success page must block raw pops so we can clear send flow '
            'and route to wallet detail instead of stranding the user on '
            'the confirm page.',
      );
      final popScope = tester.widget<PopScope>(blockingPopScope);
      expect(popScope.onPopInvokedWithResult, isNotNull);
    },
  );
}
