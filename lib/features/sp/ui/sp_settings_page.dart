import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/sp/presentation/cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_settings_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/state.dart';
import 'package:bb_mobile/features/sp/router.dart';
import 'package:bb_mobile/features/sp/ui/sp_backend_url_field.dart';
import 'package:bb_mobile/features/wallet/ui/wallet_router.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';

class SpSettingsPage extends StatefulWidget {
  const SpSettingsPage({super.key});

  @override
  State<SpSettingsPage> createState() => _SpSettingsPageState();
}

class _SpSettingsPageState extends State<SpSettingsPage> {
  @override
  void initState() {
    super.initState();
    scheduleMicrotask(() {
      if (!mounted) return;
      context.read<SpSettingsCubit>().initFromNetwork(
        context.read<SpCubit>().state.network,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<SpCubit, SpState>(
      listenWhen: (previous, current) => previous.network != current.network,
      listener: (context, state) {
        context.read<SpSettingsCubit>().initFromNetwork(state.network);
      },
      child: BlocConsumer<SpSettingsCubit, SpSettingsState>(
        listenWhen: (previous, current) => !previous.saved && current.saved,
        listener: (context, state) {
          unawaited(context.read<SpCubit>().load());
        },
        builder: (context, state) {
          return Scaffold(
            appBar: AppBar(title: const Text('SP Wallet Settings')),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _BackendConfigSection(),
                    const Gap(24),
                    const _WalletManagementSection(),
                    const Gap(24),
                    const _NotificationConsoleSection(),
                    if (state.isSaving || state.isFetchingDefaults) ...[
                      const Gap(16),
                      LinearProgressIndicator(
                        backgroundColor: context.appColors.surface,
                        color: context.appColors.primary,
                      ),
                    ],
                    if (state.error != null) ...[
                      const Gap(16),
                      Text(
                        state.error!,
                        style: TextStyle(color: context.appColors.error),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BackendConfigSection extends StatelessWidget {
  const _BackendConfigSection();

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SpSettingsCubit>().state;
    final cubit = context.read<SpSettingsCubit>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Backend config', style: context.font.titleMedium),
        const Gap(12),
        // Network is fixed once the wallet exists: changing it would be a
        // different wallet. Read-only in settings; only editable at creation.
        TextFormField(
          key: ValueKey('settings_network_${state.network.name}'),
          initialValue: state.network.name,
          enabled: false,
          decoration: const InputDecoration(
            labelText: 'Network',
            helperText: 'Network is fixed after wallet creation',
          ),
        ),
        const Gap(16),
        if (state.network == SpNetwork.regtest) ...[
          BBButton.big(
            onPressed: state.isFetchingDefaults
                ? () {}
                : cubit.fetchRegtestDefaults,
            label: 'Fetch regtest defaults',
            bgColor: context.appColors.surface,
            textColor: context.appColors.onSurface,
            disabled: state.isFetchingDefaults || state.isSaving,
          ),
          const Gap(16),
        ],
        SpBackendUrlField(
          label: 'Blindbit URL',
          fieldKey: ValueKey('settings_blindbit_${state.formRevision}'),
          initialValue: state.blindbitUrl,
          onChanged: cubit.setBlindbitUrl,
          test: state.blindbitTest,
          testError: state.blindbitTestError,
          onTest: cubit.testBlindbit,
          enabled: !state.isSaving,
        ),
        const Gap(12),
        SpBackendUrlField(
          label: 'Electrum URL',
          fieldKey: ValueKey('settings_electrum_${state.formRevision}'),
          initialValue: state.electrumUrl,
          onChanged: cubit.setElectrumUrl,
          test: state.electrumTest,
          testError: state.electrumTestError,
          onTest: cubit.testElectrum,
          enabled: !state.isSaving,
        ),
        const Gap(24),
        BBButton.big(
          onPressed: () async {
            final confirmed = await _confirm(
              context,
              title: 'Save backend config?',
              content:
                  'The SP wallet will be recreated with the selected backend config.',
              confirmLabel: 'Save',
            );
            if (!confirmed || !context.mounted) return;
            await cubit.saveBackendConfig();
          },
          label: 'Save backend config',
          bgColor: context.appColors.primary,
          textColor: context.appColors.onPrimary,
          disabled: !state.canSave,
        ),
      ],
    );
  }
}

class _WalletManagementSection extends StatelessWidget {
  const _WalletManagementSection();

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select((SpCubit cubit) => cubit.state.isLoading);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Wallet management', style: context.font.titleMedium),
        const Gap(12),
        BBButton.big(
          iconData: Icons.account_balance_wallet,
          iconFirst: true,
          label: 'Open wallet',
          onPressed: () => context.pushNamed(SpRoute.spWalletDetail.name),
          bgColor: context.appColors.onSurface,
          textColor: context.appColors.surface,
        ),
        const Gap(8),
        BBButton.big(
          iconData: Icons.toll,
          iconFirst: true,
          label: 'Coins',
          onPressed: () => context.pushNamed(SpRoute.spCoins.name),
          bgColor: context.appColors.onSurface,
          textColor: context.appColors.surface,
        ),
        const Gap(8),
        BBButton.big(
          iconData: Icons.search,
          iconFirst: true,
          label: 'Scan now',
          onPressed: () {
            unawaited(context.read<SpCubit>().scan());
            context.pushNamed(SpRoute.spScan.name);
          },
          bgColor: context.appColors.onSurface,
          textColor: context.appColors.surface,
        ),
        const Gap(8),
        BBButton.big(
          iconData: Icons.delete_outline,
          iconFirst: true,
          label: 'Delete SP wallet',
          onPressed: () async {
            final confirmed = await _confirm(
              context,
              title: 'Delete SP wallet?',
              content:
                  'This removes the local SP wallet and revokes its secret.',
              confirmLabel: 'Delete',
            );
            if (!confirmed || !context.mounted) return;
            await context.read<SpCubit>().revokeWallet();
            if (!context.mounted) return;
            context.goNamed(WalletRoute.walletHome.name);
          },
          bgColor: context.appColors.error,
          textColor: context.appColors.onPrimary,
          disabled: isLoading,
        ),
      ],
    );
  }
}

/// Debug console: live list of every notification received from the Rust side.
class _NotificationConsoleSection extends StatelessWidget {
  const _NotificationConsoleSection();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SpSettingsCubit>();
    final console = context.select(
      (SpSettingsCubit c) => c.state.console,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Notifications (debug)', style: context.font.titleMedium),
            TextButton(
              onPressed: console.isEmpty ? null : cubit.clearConsole,
              child: const Text('Clear'),
            ),
          ],
        ),
        const Gap(8),
        Container(
          height: 240,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: context.appColors.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: context.appColors.border),
          ),
          child: console.isEmpty
              ? Center(
                  child: Text(
                    'No notifications yet.',
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                )
              : ListView.builder(
                  reverse: true,
                  itemCount: console.length,
                  itemBuilder: (context, i) {
                    // Newest first.
                    final line = console[console.length - 1 - i];
                    return Text(
                      '${_hms(line.time)}  ${line.text}',
                      style: context.font.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        fontSize: 12,
                        color: context.appColors.onSurface,
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  static String _hms(DateTime t) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(t.hour)}:${two(t.minute)}:${two(t.second)}';
  }
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String content,
  required String confirmLabel,
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(content),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}
