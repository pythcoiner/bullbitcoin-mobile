import 'package:bb_mobile/features/sp/application/usecases/generate_taproot_address_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/prepare_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/scan_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/send_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/stop_sp_scan_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/watch_sp_notifications_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/cubit.dart';
import 'package:bb_mobile/features/sp/ui/sp_send_recipient_page.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
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

Widget _buildPage(SpCubit cubit) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: BlocProvider<SpCubit>.value(
    value: cubit,
    child: const SpSendRecipientPage(),
  ),
);

void main() {
  late SpCubit cubit;

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

  testWidgets('renders Send title', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildPage(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Send'), findsOneWidget);
  });

  testWidgets('shows recipient address input hint', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildPage(cubit));
    await tester.pumpAndSettle();

    expect(
      find.text('Silent payment address or Bitcoin address'),
      findsOneWidget,
    );
  });

  testWidgets('shows Continue button', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildPage(cubit));
    await tester.pumpAndSettle();

    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('shows SP badge for sp1 address', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildPage(cubit));
    await tester.pumpAndSettle();

    // Enter a silent payment address
    await tester.enterText(find.byType(TextFormField), 'sp1qabcdef');
    await tester.pump();

    expect(find.text('Silent Payment'), findsOneWidget);
  });

  testWidgets('shows Bitcoin Address badge for bc1 address', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildPage(cubit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'bc1qabcdef');
    await tester.pump();

    expect(find.text('Bitcoin Address'), findsOneWidget);
  });

  testWidgets('shows Unrecognized badge for unknown input', (tester) async {
    tester.view.physicalSize = const Size(1080, 1920);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(_buildPage(cubit));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextFormField), 'xyz_not_an_address');
    await tester.pump();

    expect(find.text('Unrecognized'), findsOneWidget);
  });
}
