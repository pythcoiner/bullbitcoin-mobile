import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/sp/presentation/cubit.dart';
import 'package:bb_mobile/features/sp/presentation/state.dart';
import 'package:bb_mobile/features/sp/ui/coin_source_label.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SpSendConfirmPage extends StatelessWidget {
  const SpSendConfirmPage({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SpCubit>().state;
    final simulation = state.txSimulation;
    final recipient = state.recipient;

    final recipientAddress = switch (recipient) {
      RecipientView_Sp(:final address) => address,
      RecipientView_Standard(:final address) => address,
      null => '',
    };
    final truncatedRecipient = recipientAddress.length > 20
        ? '${recipientAddress.substring(0, 10)}...${recipientAddress.substring(recipientAddress.length - 10)}'
        : recipientAddress;

    return Scaffold(
      appBar: AppBar(
        title: Text('Confirm', style: context.font.headlineMedium),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(3),
          child: BlocSelector<SpCubit, SpState, bool>(
            selector: (s) => s.isLoading,
            builder: (context, isLoading) => isLoading
                ? FadingLinearProgress(
                    height: 3,
                    trigger: isLoading,
                    backgroundColor: context.appColors.surface,
                    foregroundColor: context.appColors.primary,
                  )
                : const SizedBox(height: 3),
          ),
        ),
      ),
      body: SafeArea(
        child: ScrollableColumn(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Gap(24),
                Center(
                  child: Text(
                    '${state.amountSat ?? BigInt.zero} sats',
                    style: context.font.displaySmall,
                  ),
                ),
                const Gap(16),
                _SpDetailRow(
                  label: 'To',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        truncatedRecipient,
                        textAlign: TextAlign.end,
                        style: context.font.bodyMedium?.copyWith(
                          color: context.appColors.onSurface,
                        ),
                      ),
                      const Gap(2),
                      _RecipientTypeBadge(recipient: recipient),
                    ],
                  ),
                ),
                if (simulation != null) ...[
                  _SpCollapsibleSection(
                    title: 'Inputs (${simulation.inputs.length})',
                    initiallyExpanded: true,
                    children: simulation.inputs
                        .map(
                          (coin) => _SpDetailRow(
                            label: '',
                            child: _CoinInputRow(coin: coin),
                          ),
                        )
                        .toList(),
                  ),
                  _SpCollapsibleSection(
                    title: 'Outputs (${simulation.outputs.length})',
                    initiallyExpanded: false,
                    children: simulation.outputs
                        .map(
                          (out) => _SpDetailRow(
                            label: '',
                            child: _OutputRow(recipient: out),
                          ),
                        )
                        .toList(),
                  ),
                  _SpDetailRow(
                    label: 'Fee',
                    value:
                        '${simulation.feeSat} sats (${state.feerate} sat/vB)',
                  ),
                  if (simulation.changeSat > BigInt.zero)
                    _SpDetailRow(
                      label: 'Change',
                      value: '${simulation.changeSat} sats',
                    ),
                ],
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                BlocSelector<SpCubit, SpState, String?>(
                  selector: (s) => s.error?.message,
                  builder: (context, errorMsg) {
                    if (errorMsg == null || errorMsg.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        errorMsg,
                        style: context.font.bodyMedium?.copyWith(
                          color: context.appColors.error,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    );
                  },
                ),
                BlocSelector<SpCubit, SpState, bool>(
                  selector: (s) => s.isLoading,
                  builder: (context, isLoading) => BBButton.big(
                    label: 'Sign & Broadcast',
                    onPressed: () =>
                        context.read<SpCubit>().signAndBroadcast(),
                    disabled: isLoading,
                    bgColor: context.appColors.secondary,
                    textColor: context.appColors.onSecondary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SpDetailRow extends StatelessWidget {
  const _SpDetailRow({required this.label, this.value, this.child});
  final String label;
  final String? value;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              if (label.isNotEmpty)
                Text(
                  label,
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              const Gap(8),
              Expanded(
                child: child ??
                    Text(
                      value ?? '',
                      textAlign: TextAlign.end,
                      style: context.font.bodyMedium?.copyWith(
                        color: context.appColors.onSurface,
                      ),
                    ),
              ),
            ],
          ),
        ),
        Divider(height: 1, color: context.appColors.outlineVariant),
      ],
    );
  }
}

class _SpCollapsibleSection extends StatelessWidget {
  const _SpCollapsibleSection({
    required this.title,
    required this.initiallyExpanded,
    required this.children,
  });

  final String title;
  final bool initiallyExpanded;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      title: Text(title, style: context.font.bodyMedium),
      initiallyExpanded: initiallyExpanded,
      children: children,
    );
  }
}

class _RecipientTypeBadge extends StatelessWidget {
  const _RecipientTypeBadge({required this.recipient});
  final RecipientView? recipient;

  @override
  Widget build(BuildContext context) {
    if (recipient == null) return const SizedBox.shrink();
    final isSp = recipient is RecipientView_Sp;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: (isSp ? context.appColors.success : context.appColors.primary)
            .withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(
          color: isSp ? context.appColors.success : context.appColors.primary,
        ),
      ),
      child: Text(
        isSp ? 'Silent Payment' : 'Bitcoin',
        style: context.font.bodySmall?.copyWith(
          color: isSp ? context.appColors.success : context.appColors.primary,
        ),
      ),
    );
  }
}

class _CoinInputRow extends StatelessWidget {
  const _CoinInputRow({required this.coin});
  final UnifiedCoinView coin;

  @override
  Widget build(BuildContext context) {
    final sourceColor = switch (coin.source) {
      CoinSource.sp => context.appColors.success,
      CoinSource.segwit => context.appColors.primary,
      CoinSource.taproot => context.appColors.tertiary,
      CoinSource.other => throw StateError('unexpected CoinSource.other'),
    };
    final truncated = coin.outpoint.length > 16
        ? '${coin.outpoint.substring(0, 8)}...'
        : coin.outpoint;
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: sourceColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(4),
            border: Border.all(color: sourceColor),
          ),
          child: Text(
            coin.source.shortLabel,
            style: context.font.bodySmall?.copyWith(color: sourceColor),
          ),
        ),
        const Gap(8),
        Text(
          '$truncated · ${coin.amountSat} sats',
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.onSurface,
          ),
        ),
      ],
    );
  }
}

class _OutputRow extends StatelessWidget {
  const _OutputRow({required this.recipient});
  final RecipientView recipient;

  @override
  Widget build(BuildContext context) {
    final address = switch (recipient) {
      RecipientView_Sp(:final address) => address,
      RecipientView_Standard(:final address) => address,
    };
    final amount = switch (recipient) {
      RecipientView_Sp(:final amountSat) => amountSat,
      RecipientView_Standard(:final amountSat) => amountSat,
    };
    final truncated = address.length > 16
        ? '${address.substring(0, 8)}...${address.substring(address.length - 8)}'
        : address;
    return Text(
      '$truncated · $amount sats',
      textAlign: TextAlign.end,
      style: context.font.bodySmall?.copyWith(color: context.appColors.onSurface),
    );
  }
}
