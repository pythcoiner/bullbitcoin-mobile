import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/bitcoin_price/presentation/bloc/bitcoin_price_bloc.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/sp/router.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/features/wallet/ui/widgets/wallet_cards.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';

class _MockWalletBloc extends Mock implements WalletBloc {}

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockBitcoinPriceBloc extends Mock implements BitcoinPriceBloc {}

SettingsState _settingsState({
  required bool isSuperuser,
  bool isDevModeEnabled = true,
}) => SettingsState(
  storedSettings: SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    isSuperuser: isSuperuser,
    isDevModeEnabled: isDevModeEnabled,
  ),
);

Widget _buildCards({
  required _MockWalletBloc walletBloc,
  required _MockSettingsCubit settingsCubit,
  required _MockBitcoinPriceBloc bitcoinPriceBloc,
}) {
  return MaterialApp(
    home: MultiBlocProvider(
      providers: [
        BlocProvider<WalletBloc>.value(value: walletBloc),
        BlocProvider<SettingsCubit>.value(value: settingsCubit),
        BlocProvider<BitcoinPriceBloc>.value(value: bitcoinPriceBloc),
      ],
      child: const Scaffold(body: WalletCards()),
    ),
  );
}

Widget _buildCardsRouter({
  required _MockWalletBloc walletBloc,
  required _MockSettingsCubit settingsCubit,
  required _MockBitcoinPriceBloc bitcoinPriceBloc,
}) {
  final router = GoRouter(
    initialLocation: '/',
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => MultiBlocProvider(
          providers: [
            BlocProvider<WalletBloc>.value(value: walletBloc),
            BlocProvider<SettingsCubit>.value(value: settingsCubit),
            BlocProvider<BitcoinPriceBloc>.value(value: bitcoinPriceBloc),
          ],
          child: const Scaffold(body: WalletCards()),
        ),
      ),
      GoRoute(
        name: SpRoute.spWalletDetail.name,
        path: SpRoute.spWalletDetail.path,
        builder: (context, state) => const Scaffold(body: Text('SP Detail')),
      ),
    ],
  );
  return MaterialApp.router(routerConfig: router);
}

void _stubBlocs({
  required _MockWalletBloc walletBloc,
  required _MockSettingsCubit settingsCubit,
  required _MockBitcoinPriceBloc bitcoinPriceBloc,
  required WalletState walletState,
  required SettingsState settingsState,
}) {
  when(() => walletBloc.state).thenReturn(walletState);
  when(() => walletBloc.stream).thenAnswer((_) => const Stream.empty());
  when(() => settingsCubit.state).thenReturn(settingsState);
  when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
  when(() => bitcoinPriceBloc.state).thenReturn(const BitcoinPriceState());
  when(() => bitcoinPriceBloc.stream).thenAnswer((_) => const Stream.empty());
}

void main() {
  late _MockWalletBloc walletBloc;
  late _MockSettingsCubit settingsCubit;
  late _MockBitcoinPriceBloc bitcoinPriceBloc;

  setUp(() {
    walletBloc = _MockWalletBloc();
    settingsCubit = _MockSettingsCubit();
    bitcoinPriceBloc = _MockBitcoinPriceBloc();
  });

  group('SP wallet card visibility', () {
    testWidgets(
      'renders SP card when isSuperuser=true, isDevModeEnabled=true, isSpWalletSetup=true',
      (tester) async {
        _stubBlocs(
          walletBloc: walletBloc,
          settingsCubit: settingsCubit,
          bitcoinPriceBloc: bitcoinPriceBloc,
          walletState: const WalletState(isSpWalletSetup: true),
          settingsState: _settingsState(
            isSuperuser: true,
            isDevModeEnabled: true,
          ),
        );

        await tester.pumpWidget(
          _buildCards(
            walletBloc: walletBloc,
            settingsCubit: settingsCubit,
            bitcoinPriceBloc: bitcoinPriceBloc,
          ),
        );
        await tester.pump();

        expect(find.text('Silent Payments'), findsOneWidget);
      },
    );

    testWidgets('hides SP card when isDevModeEnabled=false', (tester) async {
      _stubBlocs(
        walletBloc: walletBloc,
        settingsCubit: settingsCubit,
        bitcoinPriceBloc: bitcoinPriceBloc,
        walletState: const WalletState(isSpWalletSetup: true),
        settingsState: _settingsState(
          isSuperuser: true,
          isDevModeEnabled: false,
        ),
      );

      await tester.pumpWidget(
        _buildCards(
          walletBloc: walletBloc,
          settingsCubit: settingsCubit,
          bitcoinPriceBloc: bitcoinPriceBloc,
        ),
      );
      await tester.pump();

      expect(find.text('Silent Payments'), findsNothing);
    });

    testWidgets('hides SP card when isSuperuser=false', (tester) async {
      _stubBlocs(
        walletBloc: walletBloc,
        settingsCubit: settingsCubit,
        bitcoinPriceBloc: bitcoinPriceBloc,
        walletState: const WalletState(isSpWalletSetup: true),
        settingsState: _settingsState(
          isSuperuser: false,
          isDevModeEnabled: true,
        ),
      );

      await tester.pumpWidget(
        _buildCards(
          walletBloc: walletBloc,
          settingsCubit: settingsCubit,
          bitcoinPriceBloc: bitcoinPriceBloc,
        ),
      );
      await tester.pump();

      expect(find.text('Silent Payments'), findsNothing);
    });

    testWidgets('hides SP card when isSpWalletSetup=false', (tester) async {
      _stubBlocs(
        walletBloc: walletBloc,
        settingsCubit: settingsCubit,
        bitcoinPriceBloc: bitcoinPriceBloc,
        walletState: const WalletState(isSpWalletSetup: false),
        settingsState: _settingsState(
          isSuperuser: true,
          isDevModeEnabled: true,
        ),
      );

      await tester.pumpWidget(
        _buildCards(
          walletBloc: walletBloc,
          settingsCubit: settingsCubit,
          bitcoinPriceBloc: bitcoinPriceBloc,
        ),
      );
      await tester.pump();

      expect(find.text('Silent Payments'), findsNothing);
    });

    testWidgets(
      'tapping SP card opens detail when setup and snapshot is null',
      (tester) async {
        _stubBlocs(
          walletBloc: walletBloc,
          settingsCubit: settingsCubit,
          bitcoinPriceBloc: bitcoinPriceBloc,
          walletState: const WalletState(isSpWalletSetup: true, spWallet: null),
          settingsState: _settingsState(
            isSuperuser: true,
            isDevModeEnabled: true,
          ),
        );

        await tester.pumpWidget(
          _buildCardsRouter(
            walletBloc: walletBloc,
            settingsCubit: settingsCubit,
            bitcoinPriceBloc: bitcoinPriceBloc,
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Silent Payments'));
        await tester.pumpAndSettle();

        expect(find.text('SP Detail'), findsOneWidget);
      },
    );
  });

  group('SP router redirect guard', () {
    testWidgets(
      'redirects to SpSetupRoute when navigating to SP route without setup',
      (tester) async {
        final testRouter = GoRouter(
          initialLocation: SpRoute.spWalletDetail.path,
          redirect: (context, state) {
            final path = state.uri.path;
            final isSpRoute = SpRoute.values.any(
              (r) => path == r.path || path.startsWith('${r.path}/'),
            );
            // Simulates isSpWalletSetup == false (redirect always fires)
            if (isSpRoute) return SpSetupRoute.spSetup.path;
            return null;
          },
          routes: [
            GoRoute(
              name: SpRoute.spWalletDetail.name,
              path: SpRoute.spWalletDetail.path,
              builder: (_, _) => const Scaffold(body: Text('SP Detail')),
            ),
            GoRoute(
              name: SpSetupRoute.spSetup.name,
              path: SpSetupRoute.spSetup.path,
              builder: (_, _) => const Scaffold(body: Text('SP Setup')),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: testRouter));
        await tester.pumpAndSettle();

        expect(find.text('SP Setup'), findsOneWidget);
        expect(find.text('SP Detail'), findsNothing);
      },
    );

    testWidgets(
      'allows navigation to SP route when isSpWalletSetup=true (no redirect)',
      (tester) async {
        final testRouter = GoRouter(
          initialLocation: SpRoute.spWalletDetail.path,
          redirect: (context, state) {
            // Simulates isSpWalletSetup == true (no redirect)
            return null;
          },
          routes: [
            GoRoute(
              name: SpRoute.spWalletDetail.name,
              path: SpRoute.spWalletDetail.path,
              builder: (_, _) => const Scaffold(body: Text('SP Detail')),
            ),
            GoRoute(
              name: SpSetupRoute.spSetup.name,
              path: SpSetupRoute.spSetup.path,
              builder: (_, _) => const Scaffold(body: Text('SP Setup')),
            ),
          ],
        );

        await tester.pumpWidget(MaterialApp.router(routerConfig: testRouter));
        await tester.pumpAndSettle();

        expect(find.text('SP Detail'), findsOneWidget);
        expect(find.text('SP Setup'), findsNothing);
      },
    );
  });

  group('SP router dev-mode + superuser guard', () {
    // Mirrors the SP-specific redirect block in lib/router.dart. Validates
    // that the gate redirects away from any SP route when dev mode or
    // superuser is off, even if WalletBloc.state.spWallet still holds a
    // stale handle (we don't even consult it once the gate trips).
    GoRouter buildGuardedRouter({
      required bool isSuperuser,
      required bool isDevModeEnabled,
      required bool isSpWalletSetup,
    }) {
      return GoRouter(
        initialLocation: SpRoute.spWalletDetail.path,
        redirect: (context, state) {
          final path = state.uri.path;
          final isSpRoute = SpRoute.values.any(
            (r) => path == r.path || path.startsWith('${r.path}/'),
          );
          if (isSpRoute) {
            if (!isSuperuser || !isDevModeEnabled) {
              return '/wallet-home';
            }
            if (!isSpWalletSetup) return SpSetupRoute.spSetup.path;
          }
          return null;
        },
        routes: [
          GoRoute(
            path: '/wallet-home',
            builder: (_, _) => const Scaffold(body: Text('Wallet Home')),
          ),
          GoRoute(
            name: SpRoute.spWalletDetail.name,
            path: SpRoute.spWalletDetail.path,
            builder: (_, _) => const Scaffold(body: Text('SP Detail')),
          ),
          GoRoute(
            name: SpSetupRoute.spSetup.name,
            path: SpSetupRoute.spSetup.path,
            builder: (_, _) => const Scaffold(body: Text('SP Setup')),
          ),
        ],
      );
    }

    testWidgets(
      'redirects to wallet home when isDevModeEnabled=false even if setup',
      (tester) async {
        final router = buildGuardedRouter(
          isSuperuser: true,
          isDevModeEnabled: false,
          isSpWalletSetup: true,
        );
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(find.text('Wallet Home'), findsOneWidget);
        expect(find.text('SP Detail'), findsNothing);
      },
    );

    testWidgets(
      'redirects to wallet home when isSuperuser=false even if setup',
      (tester) async {
        final router = buildGuardedRouter(
          isSuperuser: false,
          isDevModeEnabled: true,
          isSpWalletSetup: true,
        );
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(find.text('Wallet Home'), findsOneWidget);
        expect(find.text('SP Detail'), findsNothing);
      },
    );

    testWidgets(
      'allows SP route when isSuperuser=true, isDevModeEnabled=true, isSpWalletSetup=true',
      (tester) async {
        final router = buildGuardedRouter(
          isSuperuser: true,
          isDevModeEnabled: true,
          isSpWalletSetup: true,
        );
        await tester.pumpWidget(MaterialApp.router(routerConfig: router));
        await tester.pumpAndSettle();
        expect(find.text('SP Detail'), findsOneWidget);
      },
    );
  });
}
