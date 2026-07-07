import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/core/widgets/scrollable_column.dart';
import 'package:bb_mobile/features/sp/domain/sp_balance.dart';
import 'package:bb_mobile/features/sp/presentation/cubit.dart';
import 'package:bb_mobile/features/sp/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SpSendAmountPage extends StatefulWidget {
  const SpSendAmountPage({super.key});

  @override
  State<SpSendAmountPage> createState() => _SpSendAmountPageState();
}

class _SpSendAmountPageState extends State<SpSendAmountPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  late int _feerate;
  bool _isMax = false;

  @override
  void initState() {
    super.initState();
    _feerate = context.read<SpCubit>().state.feerate;
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _setMax(bool isMax) {
    setState(() => _isMax = isMax);
    context.read<SpCubit>().setMax(isMax);
    if (isMax) {
      _controller.clear();
      FocusScope.of(context).unfocus();
    }
  }

  void _submit() {
    final cubit = context.read<SpCubit>();
    if (_isMax) {
      // bwk drains all coins and computes the amount; no manual validation.
      FocusScope.of(context).unfocus();
      cubit.prepare();
      return;
    }
    final sats = BigInt.tryParse(_controller.text);
    if (sats == null) return;
    FocusScope.of(context).unfocus();
    // Validates against the available balance and surfaces an inline error;
    // only advance to prepare() when the amount is acceptable.
    if (cubit.setValidatedAmount(sats)) {
      cubit.prepare();
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Amount', style: context.font.headlineMedium),
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(3),
            child: BlocSelector<SpCubit, SpState, bool>(
              selector: (state) => state.isLoading,
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
          child: Form(
            child: ScrollableColumn(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const Gap(16),
                    Text('Amount (sats)', style: context.font.bodyMedium),
                    const Gap(8),
                    TextFormField(
                      controller: _controller,
                      focusNode: _focusNode,
                      enabled: !_isMax,
                      keyboardType: TextInputType.number,
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        hintText: _isMax ? 'MAX (all funds)' : '0',
                        suffixText: 'sats',
                        filled: true,
                        fillColor: context.appColors.surface,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: context.appColors.border),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: context.appColors.border),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(
                            color: context.appColors.primary,
                            width: 2,
                          ),
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                      ),
                      onFieldSubmitted: (_) => _submit(),
                    ),
                    const Gap(8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: BlocSelector<SpCubit, SpState, SpBalance?>(
                            selector: (s) => s.balance,
                            builder: (context, balance) => Text(
                              'Available: ${balance?.totalUnifiedSat ?? BigInt.zero} sats',
                              style: context.font.bodySmall?.copyWith(
                                color: context.appColors.outline,
                              ),
                            ),
                          ),
                        ),
                        ChoiceChip(
                          label: const Text('MAX'),
                          selected: _isMax,
                          onSelected: _setMax,
                          selectedColor: context.appColors.secondary,
                          labelStyle: _isMax
                              ? context.font.bodySmall?.copyWith(
                                  color: context.appColors.onSecondary,
                                )
                              : context.font.bodySmall,
                        ),
                      ],
                    ),
                    const Gap(24),
                    Text('Fee rate', style: context.font.bodyMedium),
                    const Gap(8),
                    _FeerateSelector(
                      feerate: _feerate,
                      onChanged: (v) {
                        setState(() => _feerate = v);
                        context.read<SpCubit>().setFeerate(v);
                      },
                    ),
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
                        label: 'Continue',
                        onPressed: _submit,
                        disabled: (!_isMax && _controller.text.isEmpty) || isLoading,
                        bgColor: context.appColors.secondary,
                        textColor: context.appColors.onSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _FeerateSelector extends StatefulWidget {
  const _FeerateSelector({required this.feerate, required this.onChanged});
  final int feerate;
  final ValueChanged<int> onChanged;

  static const presets = [
    (label: 'Slow', value: 1),
    (label: 'Normal', value: 3),
    (label: 'Fast', value: 10),
  ];

  @override
  State<_FeerateSelector> createState() => _FeerateSelectorState();
}

class _FeerateSelectorState extends State<_FeerateSelector> {
  final _customController = TextEditingController();

  bool get _isPreset =>
      _FeerateSelector.presets.any((p) => p.value == widget.feerate);

  @override
  void initState() {
    super.initState();
    // Pre-fill the custom field when the initial feerate isn't a preset.
    if (!_isPreset) _customController.text = widget.feerate.toString();
  }

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  void _onCustomChanged(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed > 0) widget.onChanged(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: _FeerateSelector.presets
              .map(
                (preset) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 4),
                    child: ChoiceChip(
                      label: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(preset.label, style: context.font.bodySmall),
                          Text(
                            '${preset.value} sat/vB',
                            style: context.font.bodySmall?.copyWith(
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      selected: widget.feerate == preset.value,
                      onSelected: (_) {
                        _customController.clear();
                        widget.onChanged(preset.value);
                      },
                      selectedColor: context.appColors.secondary,
                      labelStyle: widget.feerate == preset.value
                          ? context.font.bodySmall?.copyWith(
                              color: context.appColors.onSecondary,
                            )
                          : null,
                    ),
                  ),
                ),
              )
              .toList(),
        ),
        const Gap(8),
        TextFormField(
          controller: _customController,
          keyboardType: TextInputType.number,
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: _onCustomChanged,
          decoration: InputDecoration(
            isDense: true,
            hintText: 'Custom',
            suffixText: 'sat/vB',
            filled: true,
            fillColor: context.appColors.surface,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: context.appColors.border),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
          ),
        ),
      ],
    );
  }
}
