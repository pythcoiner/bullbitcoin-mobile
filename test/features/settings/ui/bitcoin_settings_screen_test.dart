import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/features/settings/presentation/bloc/settings_cubit.dart';
import 'package:bb_mobile/features/settings/ui/screens/bitcoin/bitcoin_settings_screen.dart';
import 'package:bb_mobile/features/wallet/presentation/bloc/wallet_bloc.dart';
import 'package:bb_mobile/generated/l10n/localization.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockSettingsCubit extends Mock implements SettingsCubit {}

class _MockWalletBloc extends Mock implements WalletBloc {}

SettingsState _settingsState() => SettingsState(
  storedSettings: SettingsEntity(
    environment: Environment.mainnet,
    bitcoinUnit: BitcoinUnit.sats,
    currencyCode: 'USD',
    isSuperuser: true,
    isDevModeEnabled: true,
  ),
);

Widget _buildPage({
  required SettingsCubit settingsCubit,
  required WalletBloc walletBloc,
}) => MaterialApp(
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: MultiBlocProvider(
    providers: [
      BlocProvider<SettingsCubit>.value(value: settingsCubit),
      BlocProvider<WalletBloc>.value(value: walletBloc),
    ],
    child: const BitcoinSettingsScreen(),
  ),
);

void main() {
  late _MockSettingsCubit settingsCubit;
  late _MockWalletBloc walletBloc;

  setUp(() {
    settingsCubit = _MockSettingsCubit();
    walletBloc = _MockWalletBloc();
    when(() => settingsCubit.state).thenReturn(_settingsState());
    when(() => settingsCubit.stream).thenAnswer((_) => const Stream.empty());
    when(() => walletBloc.stream).thenAnswer((_) => const Stream.empty());
  });

  testWidgets('not setup shows Create SP Wallet', (tester) async {
    when(
      () => walletBloc.state,
    ).thenReturn(const WalletState(isSpWalletSetup: false));

    await tester.pumpWidget(
      _buildPage(settingsCubit: settingsCubit, walletBloc: walletBloc),
    );

    expect(find.text('Create SP Wallet'), findsOneWidget);
    expect(find.text('SP Wallet Settings'), findsNothing);
    expect(find.text('Open SP Wallet'), findsNothing);
  });

  testWidgets('setup shows SP Wallet Settings', (tester) async {
    when(
      () => walletBloc.state,
    ).thenReturn(const WalletState(isSpWalletSetup: true));

    await tester.pumpWidget(
      _buildPage(settingsCubit: settingsCubit, walletBloc: walletBloc),
    );

    expect(find.text('SP Wallet Settings'), findsOneWidget);
    expect(find.text('Create SP Wallet'), findsNothing);
    expect(find.text('Open SP Wallet'), findsNothing);
  });
}
