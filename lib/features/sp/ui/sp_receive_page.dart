import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/inputs/copy_input.dart';
import 'package:bb_mobile/core/widgets/loading/loading_box_content.dart';
import 'package:bb_mobile/core/widgets/qr_display_widget.dart';
import 'package:bb_mobile/features/sp/presentation/cubit.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SpReceivePage extends StatefulWidget {
  const SpReceivePage({super.key});

  @override
  State<SpReceivePage> createState() => _SpReceivePageState();
}

class _SpReceivePageState extends State<SpReceivePage>
    with TickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    // Two tabs now (segwit dropped). Clamp any previously-stored index.
    final initialIndex = context.read<SpCubit>().state.receiveTabIndex.clamp(
      0,
      1,
    );
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: initialIndex,
    );
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        context.read<SpCubit>().setReceiveTab(_tabController.index);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<SpCubit>().state;

    return Scaffold(
      appBar: AppBar(
        title: Text('Receive', style: context.font.headlineMedium),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Silent Payment'),
            Tab(text: 'Taproot'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _SpReusableAddressTab(
            address: state.spAddress,
            isLoading: state.isLoading,
          ),
          const _SpTaprootReceiveTab(),
        ],
      ),
    );
  }
}

/// The reusable Silent Payments address. Shown by default, safe to reuse.
class _SpReusableAddressTab extends StatelessWidget {
  const _SpReusableAddressTab({required this.address, required this.isLoading});

  final String address;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final hasAddress = address.isNotEmpty;
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(24),
          if (isLoading)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: LoadingBoxContent(height: 220),
            )
          else if (hasAddress) ...[
            _AddressDisplay(address: address),
            const Gap(16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.appColors.tertiaryContainer,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.appColors.tertiary),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: 16,
                          color: context.appColors.onTertiary,
                        ),
                        const Gap(6),
                        Text(
                          'Manual scan required',
                          style: context.font.bodyMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: context.appColors.onTertiary,
                          ),
                        ),
                      ],
                    ),
                    const Gap(4),
                    Text(
                      'This address is reusable. Funds arrive after you tap Scan.',
                      style: context.font.bodySmall?.copyWith(
                        color: context.appColors.onTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Reusable address unavailable. Pull to refresh or reopen the wallet.',
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const Gap(40),
        ],
      ),
    );
  }
}

/// The taproot receive address. A standard (non-reusable) address: it is only
/// revealed on an explicit "Generate" tap, and each tap derives a fresh
/// never-before-issued address so the same address is never handed to two
/// payers.
class _SpTaprootReceiveTab extends StatelessWidget {
  const _SpTaprootReceiveTab();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<SpCubit>();
    final state = context.watch<SpCubit>().state;
    final address = state.taprootReceiveAddress;
    final hasAddress = address.isNotEmpty;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Gap(24),
          if (hasAddress) ...[
            _AddressDisplay(address: address),
            const Gap(16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Standard Bitcoin address. Funds appear immediately on-chain. '
                'Generate a new one for each payment to avoid address reuse.',
                style: context.font.bodySmall?.copyWith(
                  color: context.appColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ] else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Tap below to generate a fresh taproot receive address.',
                style: context.font.bodyMedium?.copyWith(
                  color: context.appColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          const Gap(24),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: FilledButton(
              onPressed: state.isGeneratingAddress
                  ? null
                  : cubit.generateTaprootAddress,
              child: state.isGeneratingAddress
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(
                      hasAddress ? 'Generate new address' : 'Generate address',
                    ),
            ),
          ),
          const Gap(40),
        ],
      ),
    );
  }
}

class _AddressDisplay extends StatelessWidget {
  const _AddressDisplay({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 42),
            child: QrDisplayWidget(data: address),
          ),
        ),
        const Gap(16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: CopyInput(
            text: address,
            clipboardText: address,
            overflow: TextOverflow.ellipsis,
            canShowValueModal: true,
            modalTitle: 'Address',
            modalContent: address,
          ),
        ),
      ],
    );
  }
}
