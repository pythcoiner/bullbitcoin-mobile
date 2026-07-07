import 'package:bb_mobile/features/sp/presentation/cubit.dart';
import 'package:bb_mobile/features/sp/application/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_settings_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/state.dart';
import 'package:bb_mobile/features/sp/router.dart';
import 'package:bb_mobile/features/sp/ui/sp_settings_page.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockSpCubit extends Mock implements SpCubit {}

class _MockSpSettingsCubit extends Mock implements SpSettingsCubit {}

Widget _buildPage({
  required SpCubit spCubit,
  required SpSettingsCubit settingsCubit,
}) => MaterialApp(
  home: MultiBlocProvider(
    providers: [
      BlocProvider<SpCubit>.value(value: spCubit),
      BlocProvider<SpSettingsCubit>.value(value: settingsCubit),
    ],
    child: const SpSettingsPage(),
  ),
);

Widget _buildRouterPage({
  required SpCubit spCubit,
  required SpSettingsCubit settingsCubit,
}) {
  final router = GoRouter(
    initialLocation: SpRoute.spSettings.path,
    routes: [
      GoRoute(
        name: SpRoute.spSettings.name,
        path: SpRoute.spSettings.path,
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider<SpCubit>.value(value: spCubit),
            BlocProvider<SpSettingsCubit>.value(value: settingsCubit),
          ],
          child: const SpSettingsPage(),
        ),
      ),
      GoRoute(
        name: WalletRoute.walletHome.name,
        path: WalletRoute.walletHome.path,
        builder: (context, state) => const Scaffold(body: Text('Wallet home')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void main() {
  late _MockSpCubit spCubit;
  late _MockSpSettingsCubit settingsCubit;

  setUpAll(() {
    registerFallbackValue(SpNetwork.regtest);
  });

  setUp(() {
    spCubit = _MockSpCubit();
    settingsCubit = _MockSpSettingsCubit();
    when(
      () => spCubit.state,
    ).thenReturn(const SpState(network: SpNetwork.bitcoin));
    when(() => spCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => spCubit.load()).thenAnswer((_) async {});
    when(() => spCubit.scan()).thenAnswer((_) async {});
    when(() => spCubit.revokeWallet()).thenAnswer((_) async {});
    when(() => settingsCubit.state).thenReturn(
      const SpSettingsState(
        initialized: true,
        network: SpNetwork.bitcoin,
        blindbitUrl: 'https://blindbit.bullbitcoin.com',
        electrumUrl: 'ssl://electrum.bullbitcoin.com:50002',
        blindbitTest: SpConnTest.ok,
        electrumTest: SpConnTest.ok,
      ),
    );
    when(
      () => settingsCubit.stream,
    ).thenAnswer((_) => const Stream<SpSettingsState>.empty());
    when(() => settingsCubit.initFromNetwork(any())).thenAnswer((_) async {});
    when(() => settingsCubit.setNetwork(any())).thenReturn(null);
    when(() => settingsCubit.setBlindbitUrl(any())).thenReturn(null);
    when(() => settingsCubit.setElectrumUrl(any())).thenReturn(null);
    when(() => settingsCubit.fetchRegtestDefaults()).thenAnswer((_) async {});
    when(() => settingsCubit.saveBackendConfig()).thenAnswer((_) async {});
  });

  testWidgets('renders backend config and wallet management sections', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPage(spCubit: spCubit, settingsCubit: settingsCubit),
    );
    await tester.pump();

    expect(find.text('Backend config'), findsOneWidget);
    expect(find.text('Wallet management'), findsOneWidget);
    expect(find.text('Network'), findsOneWidget);
    expect(find.text('Blindbit URL'), findsOneWidget);
    expect(find.text('Electrum URL'), findsOneWidget);
    expect(find.text('Open wallet'), findsOneWidget);
    expect(find.text('Coins'), findsOneWidget);
    expect(find.text('Scan now'), findsOneWidget);
    expect(find.text('Delete SP wallet'), findsOneWidget);
  });

  testWidgets('network is read-only after wallet creation', (tester) async {
    await tester.pumpWidget(
      _buildPage(spCubit: spCubit, settingsCubit: settingsCubit),
    );

    // No editable network selector in settings.
    expect(find.byType(DropdownButtonFormField<SpNetwork>), findsNothing);
    // The current network is shown read-only.
    expect(find.text(SpNetwork.bitcoin.name), findsOneWidget);
    verifyNever(() => settingsCubit.setNetwork(any()));
  });

  testWidgets('regtest renders defaults action', (tester) async {
    when(() => settingsCubit.state).thenReturn(
      const SpSettingsState(
        initialized: true,
        network: SpNetwork.regtest,
        blindbitUrl: 'http://127.0.0.1:8000',
        electrumUrl: 'tcp://127.0.0.1:50001',
      ),
    );

    await tester.pumpWidget(
      _buildPage(spCubit: spCubit, settingsCubit: settingsCubit),
    );

    await tester.tap(find.text('Fetch regtest defaults'));
    await tester.pump();

    verify(() => settingsCubit.fetchRegtestDefaults()).called(1);
  });

  testWidgets('save requires confirmation before calling cubit', (
    tester,
  ) async {
    await tester.pumpWidget(
      _buildPage(spCubit: spCubit, settingsCubit: settingsCubit),
    );

    await tester.tap(find.text('Save backend config'), warnIfMissed: false);
    await tester.pumpAndSettle();

    verifyNever(() => settingsCubit.saveBackendConfig());
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    verify(() => settingsCubit.saveBackendConfig()).called(1);
  });

  testWidgets('empty fields disable save', (tester) async {
    when(() => settingsCubit.state).thenReturn(
      const SpSettingsState(
        initialized: true,
        network: SpNetwork.bitcoin,
        blindbitUrl: '',
        electrumUrl: '',
      ),
    );

    await tester.pumpWidget(
      _buildPage(spCubit: spCubit, settingsCubit: settingsCubit),
    );

    await tester.ensureVisible(find.text('Save backend config'));
    await tester.tap(find.text('Save backend config'), warnIfMissed: false);
    await tester.pump();

    verifyNever(() => settingsCubit.saveBackendConfig());
    expect(find.text('Save backend config?'), findsNothing);
  });

  testWidgets('delete requires confirmation before revoke', (tester) async {
    await tester.pumpWidget(
      _buildRouterPage(spCubit: spCubit, settingsCubit: settingsCubit),
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Delete SP wallet'));
    await tester.tap(find.text('Delete SP wallet'));
    await tester.pumpAndSettle();

    verifyNever(() => spCubit.revokeWallet());
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();

    verify(() => spCubit.revokeWallet()).called(1);
    expect(find.text('Wallet home'), findsOneWidget);
  });
}
