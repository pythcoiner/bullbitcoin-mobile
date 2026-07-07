import 'package:bb_mobile/features/sp/presentation/cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_settings_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/state.dart';
import 'package:bb_mobile/features/sp/ui/sp_coins_page.dart';
import 'package:bb_mobile/features/sp/ui/sp_receive_page.dart';
import 'package:bb_mobile/features/sp/ui/sp_scan_page.dart';
import 'package:bb_mobile/features/sp/ui/sp_send_amount_page.dart';
import 'package:bb_mobile/features/sp/ui/sp_send_confirm_page.dart';
import 'package:bb_mobile/features/sp/ui/sp_send_recipient_page.dart';
import 'package:bb_mobile/features/sp/ui/sp_send_success_page.dart';
import 'package:bb_mobile/features/sp/ui/sp_settings_page.dart';
import 'package:bb_mobile/features/sp/ui/sp_setup_page.dart';
import 'package:bb_mobile/features/sp/ui/sp_transaction_details_page.dart';
import 'package:bb_mobile/features/sp/ui/sp_wallet_detail_page.dart';
import 'package:bb_mobile/locator.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

enum SpRoute {
  spWalletDetail('/sp-wallet-detail'),
  spSettings('/sp-settings'),
  spCoins('/sp-coins'),
  spTransactionDetails('/sp-transaction-details'),
  spReceive('/sp-receive'),
  spScan('/sp-scan'),
  spSendRecipient('/sp-send'),
  spSendAmount('/sp-send/amount'),
  spSendConfirm('/sp-send/confirm'),
  spSendSuccess('/sp-send/success');

  final String path;
  const SpRoute(this.path);
}

enum SpSetupRoute {
  spSetup('/sp-setup');

  final String path;
  const SpSetupRoute(this.path);
}

class SpSetupRouter {
  static final route = GoRoute(
    name: SpSetupRoute.spSetup.name,
    path: SpSetupRoute.spSetup.path,
    builder: (context, state) => BlocProvider(
      create: (_) => locator<SpSetupCubit>(),
      child: const SpSetupPage(),
    ),
  );
}

class SpRouter {
  static final route = ShellRoute(
    builder: (context, state, child) {
      // The SP session lives in the SpAccountRepository (lazySingleton); the
      // top-level GoRouter redirect already gates entry on
      // superuser + dev-mode + isSpWalletSetup, so we just provide the cubit.
      return BlocProvider(
        create: (context) => locator<SpCubit>()..load(),
        child: child,
      );
    },
    routes: [
      GoRoute(
        name: SpRoute.spWalletDetail.name,
        path: SpRoute.spWalletDetail.path,
        builder: (context, state) => const SpWalletDetailPage(),
      ),
      GoRoute(
        name: SpRoute.spSettings.name,
        path: SpRoute.spSettings.path,
        builder: (context, state) => BlocProvider(
          create: (_) => locator<SpSettingsCubit>(),
          child: const SpSettingsPage(),
        ),
      ),
      GoRoute(
        name: SpRoute.spCoins.name,
        path: SpRoute.spCoins.path,
        builder: (context, state) => const SpCoinsPage(),
      ),
      GoRoute(
        name: SpRoute.spTransactionDetails.name,
        path: SpRoute.spTransactionDetails.path,
        builder: (context, state) {
          final payment = state.extra! as SpPaymentView;
          return SpTransactionDetailsPage(payment: payment);
        },
      ),
      GoRoute(
        name: SpRoute.spReceive.name,
        path: SpRoute.spReceive.path,
        builder: (context, state) => const SpReceivePage(),
      ),
      GoRoute(
        name: SpRoute.spScan.name,
        path: SpRoute.spScan.path,
        builder: (context, state) => const SpScanPage(),
      ),
      GoRoute(
        name: SpRoute.spSendRecipient.name,
        path: SpRoute.spSendRecipient.path,
        builder: (context, state) => BlocListener<SpCubit, SpState>(
          listenWhen: (previous, current) =>
              !previous.hasSendRecipient && current.hasSendRecipient,
          listener: (context, state) {
            context.pushNamed(SpRoute.spSendAmount.name);
          },
          child: const SpSendRecipientPage(),
        ),
      ),
      GoRoute(
        name: SpRoute.spSendAmount.name,
        path: SpRoute.spSendAmount.path,
        builder: (context, state) => BlocListener<SpCubit, SpState>(
          listenWhen: (previous, current) =>
              !previous.hasTxSimulation && current.hasTxSimulation,
          listener: (context, state) {
            context.pushNamed(SpRoute.spSendConfirm.name);
          },
          child: const SpSendAmountPage(),
        ),
      ),
      GoRoute(
        name: SpRoute.spSendConfirm.name,
        path: SpRoute.spSendConfirm.path,
        builder: (context, state) => BlocListener<SpCubit, SpState>(
          listenWhen: (previous, current) =>
              !previous.sendSuccess && current.sendSuccess,
          listener: (context, state) {
            context.goNamed(SpRoute.spSendSuccess.name);
          },
          child: const SpSendConfirmPage(),
        ),
      ),
      GoRoute(
        name: SpRoute.spSendSuccess.name,
        path: SpRoute.spSendSuccess.path,
        builder: (context, state) => const SpSendSuccessPage(),
      ),
    ],
  );
}
