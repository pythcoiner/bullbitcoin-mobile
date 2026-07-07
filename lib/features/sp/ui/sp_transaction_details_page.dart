import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/utils/amount_formatting.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

String _directionLabel(SpPaymentDirection direction) {
  switch (direction) {
    case SpPaymentDirection.receive:
      return 'Received';
    case SpPaymentDirection.send:
      return 'Sent';
    case SpPaymentDirection.selfSend:
      return 'Self-send';
  }
}

class SpTransactionDetailsPage extends StatelessWidget {
  const SpTransactionDetailsPage({super.key, required this.payment});

  final SpPaymentView payment;

  @override
  Widget build(BuildContext context) {
    final isIncoming = payment.direction == SpPaymentDirection.receive;
    final truncatedTxid = payment.txid.length > 16
        ? '${payment.txid.substring(0, 8)}...${payment.txid.substring(payment.txid.length - 8)}'
        : payment.txid;

    return Scaffold(
      appBar: AppBar(
        title: Text('Transaction', style: context.font.headlineMedium),
        leading: const SizedBox.shrink(),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => context.pop(),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Column(
              children: [
                Icon(
                  isIncoming ? Icons.arrow_downward : Icons.arrow_upward,
                  size: 48,
                  color:
                      isIncoming
                          ? context.appColors.success
                          : context.appColors.error,
                ),
                const Gap(24),
                Text(
                  payment.height != null ? 'Confirmed' : 'Unconfirmed',
                  style: context.font.titleMedium,
                ),
                const Gap(8),
                Text(
                  FormatAmount.satsSpaced(payment.amountSat.toInt()),
                  style: context.font.displaySmall?.copyWith(
                    color: context.appColors.onSurface,
                  ),
                ),
                const Gap(24),
                _DetailRow(
                  label: 'Direction',
                  value: _directionLabel(payment.direction),
                ),
                _DetailRow(
                  label: 'Amount',
                  value: FormatAmount.satsSpaced(payment.amountSat.toInt()),
                ),
                if (payment.feeSat != null)
                  _DetailRow(
                    label: 'Fee',
                    value: FormatAmount.satsSpaced(payment.feeSat!.toInt()),
                  ),
                if (payment.height != null)
                  _DetailRow(label: 'Block', value: '${payment.height}'),
                if (payment.timestamp != null)
                  _DetailRow(
                    label: 'Date',
                    value: DateFormat('MMM d, y, h:mm a').format(
                      DateTime.fromMillisecondsSinceEpoch(
                        payment.timestamp!.toInt() * 1000,
                      ),
                    ),
                  ),
                const Gap(16),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Transaction ID',
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                ),
                const Gap(4),
                CopyInput(
                  text: truncatedTxid,
                  clipboardText: payment.txid,
                  canShowValueModal: true,
                  modalTitle: 'Transaction ID',
                  modalContent: payment.txid,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                label,
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.textMuted,
                ),
              ),
              const Gap(8),
              Expanded(
                child: Text(
                  value,
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
