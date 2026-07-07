import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/features/sp/presentation/cubit.dart';
import 'package:bb_mobile/features/sp/router.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SpSendSuccessPage extends StatelessWidget {
  const SpSendSuccessPage({super.key});

  @override
  Widget build(BuildContext context) {
    final txid = context.select((SpCubit c) => c.state.txid);
    final truncatedTxid = txid.length > 16
        ? '${txid.substring(0, 8)}...${txid.substring(txid.length - 8)}'
        : txid;

    // R4: intercept system back / iOS swipe-back. Without this, the user
    // lands on the confirm page where a stale simulation + a second tap on
    // Sign & Broadcast could re-enter the broadcast path. The cubit-side
    // fix (clearing simulation on success) is the bedrock; this PopScope is
    // the UX layer that routes the user cleanly back to the wallet detail
    // instead of stranding them on a now-empty confirm page.
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        context.read<SpCubit>().resetSendFlow();
        context.goNamed(SpRoute.spWalletDetail.name);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          title: const SizedBox.shrink(),
          actions: [
            CloseButton(
              onPressed: () {
                context.read<SpCubit>().resetSendFlow();
                context.goNamed(SpRoute.spWalletDetail.name);
              },
            ),
          ],
        ),
        body: SafeArea(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle,
                  color: context.appColors.success,
                  size: 72,
                ),
                const Gap(24),
                Text('Sent', style: context.font.headlineMedium),
                const Gap(24),
                if (txid.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: CopyInput(
                      text: truncatedTxid,
                      clipboardText: txid,
                      canShowValueModal: true,
                      modalTitle: 'Transaction ID',
                      modalContent: txid,
                    ),
                  ),
                const Gap(40),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: BBButton.big(
                    label: 'Done',
                    onPressed: () {
                      context.read<SpCubit>().resetSendFlow();
                      context.goNamed(SpRoute.spWalletDetail.name);
                    },
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
