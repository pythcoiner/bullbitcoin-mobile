import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_state.dart';
import 'package:bb_mobile/features/sp/ui/sp_backend_url_field.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SpSetupPage extends StatelessWidget {
  const SpSetupPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create SP Wallet')),
      body: BlocConsumer<SpSetupCubit, SpSetupState>(
        listenWhen: (prev, curr) => !prev.created && curr.created,
        listener: (context, state) => Navigator.of(context).pop(),
        builder: (context, state) {
          final cubit = context.read<SpSetupCubit>();
          return Column(
            children: [
              if (state.isCreating || state.isFetchingDefaults)
                LinearProgressIndicator(
                  backgroundColor: context.appColors.surface,
                  color: context.appColors.primary,
                ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      DropdownButtonFormField<SpNetwork>(
                        key: ValueKey('network_${state.network.name}'),
                        initialValue: state.network,
                        decoration: const InputDecoration(labelText: 'Network'),
                        items: SpNetwork.values
                            .map(
                              (n) => DropdownMenuItem(
                                value: n,
                                child: Text(n.name),
                              ),
                            )
                            .toList(),
                        onChanged: (n) {
                          if (n != null) cubit.setNetwork(n);
                        },
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
                          disabled: state.isFetchingDefaults,
                        ),
                        const Gap(16),
                      ],
                      SpBackendUrlField(
                        label: 'Blindbit URL',
                        fieldKey: ValueKey('blindbit_${state.network.name}'),
                        initialValue: state.blindbitUrl,
                        onChanged: cubit.setBlindbitUrl,
                        test: state.blindbitTest,
                        testError: state.blindbitTestError,
                        onTest: cubit.testBlindbit,
                        enabled: !state.isCreating,
                      ),
                      const Gap(12),
                      SpBackendUrlField(
                        label: 'Electrum URL',
                        fieldKey: ValueKey('electrum_${state.network.name}'),
                        initialValue: state.electrumUrl,
                        onChanged: cubit.setElectrumUrl,
                        test: state.electrumTest,
                        testError: state.electrumTestError,
                        onTest: cubit.testElectrum,
                        enabled: !state.isCreating,
                      ),
                      const Gap(24),
                      if (state.error != null) ...[
                        Text(
                          state.error!,
                          style: TextStyle(color: context.appColors.error),
                        ),
                        const Gap(16),
                      ],
                      BBButton.big(
                        onPressed: cubit.create,
                        label: 'Create',
                        bgColor: context.appColors.primary,
                        textColor: context.appColors.onPrimary,
                        disabled: !state.canCreate,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
