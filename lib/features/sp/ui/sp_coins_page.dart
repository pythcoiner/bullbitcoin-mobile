import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/features/sp/presentation/cubit.dart';
import 'package:bb_mobile/features/sp/ui/coin_source_label.dart';
import 'package:bb_mobile/features/sp/presentation/state.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SpCoinsPage extends StatelessWidget {
  const SpCoinsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Coins', style: context.font.headlineMedium),
      ),
      body: SafeArea(
        child: BlocBuilder<SpCubit, SpState>(
          builder: (context, state) {
            final coins = state.coins;
            if (coins.isEmpty) {
              return Center(
                child: Text(
                  'No coins yet',
                  style: context.font.bodyMedium?.copyWith(
                    color: context.appColors.textMuted,
                  ),
                ),
              );
            }
            return ListView.builder(
              itemCount: coins.length,
              itemBuilder: (context, i) => _SpCoinTile(coin: coins[i]),
            );
          },
        ),
      ),
    );
  }
}

class _SpCoinTile extends StatelessWidget {
  const _SpCoinTile({required this.coin});
  final UnifiedCoinView coin;

  @override
  Widget build(BuildContext context) {
    final color = _sourceColor(context, coin.source);
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: color),
        ),
        child: Text(
          coin.source.shortLabel,
          style: context.font.bodySmall?.copyWith(color: color),
        ),
      ),
      title: Text(FormatAmount.satsSpaced(coin.amountSat.toInt())),
      subtitle: Text(
        '${_short(coin.outpoint)} · '
        '${coin.height != null ? 'Block ${coin.height}' : 'Unconfirmed'}',
        style: context.font.bodySmall?.copyWith(
          color: context.appColors.textMuted,
        ),
      ),
      trailing: _statusIcon(context, coin.status),
    );
  }

  Widget _statusIcon(BuildContext context, UnifiedCoinStatus status) {
    final (icon, color, tooltip) = switch (status) {
      UnifiedCoinStatus.unconfirmed => (
        Icons.schedule,
        context.appColors.textMuted,
        'Unconfirmed',
      ),
      UnifiedCoinStatus.unspent => (
        Icons.check_circle,
        context.appColors.success,
        'Unspent',
      ),
      UnifiedCoinStatus.spent => (
        Icons.remove_circle,
        context.appColors.textMuted,
        'Spent',
      ),
    };
    return Tooltip(message: tooltip, child: Icon(icon, color: color));
  }

  Color _sourceColor(BuildContext context, CoinSource source) => switch (source) {
    CoinSource.sp => context.appColors.success,
    CoinSource.segwit => context.appColors.primary,
    CoinSource.taproot => context.appColors.tertiary,
    CoinSource.other => context.appColors.textMuted,
  };

  String _short(String outpoint) => outpoint.length > 20
      ? '${outpoint.substring(0, 10)}…${outpoint.substring(outpoint.length - 8)}'
      : outpoint;
}
