import 'dart:async';

import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/presentation/cubit.dart';
import 'package:bb_mobile/features/sp/presentation/scan_start_ticks.dart';
import 'package:bb_mobile/features/sp/presentation/sp_sync_estimator.dart';
import 'package:bb_mobile/features/sp/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SpScanPage extends StatelessWidget {
  const SpScanPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const BackButton(),
        title: Text('Scan', style: context.font.headlineMedium),
      ),
      body: SafeArea(
        child: BlocBuilder<SpCubit, SpState>(
          builder: (context, state) {
            if (state.isScanning) return const _ScanningView();
            if (state.error != null) return _ErrorView(message: state.error!.message);
            if (!state.hasScannedBefore) return _FirstScanView(state: state);
            if (state.isCaughtUp) {
              return _CaughtUpView(
                tip: state.chainTip!,
                lastDurationSecs: state.scanLastDurationSecs,
              );
            }
            return _ResumeView(state: state);
          },
        ),
      ),
    );
  }
}

class _ScanningView extends StatelessWidget {
  const _ScanningView();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: BlocBuilder<SpCubit, SpState>(
              builder: (context, state) => _ScanProgressCard(state: state),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          child: BBButton.big(
            label: 'Stop',
            onPressed: () => unawaited(context.read<SpCubit>().stopScan()),
            bgColor: context.appColors.error,
            textColor: context.appColors.onError,
          ),
        ),
      ],
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.error, color: context.appColors.error, size: 72),
                const Gap(24),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    message,
                    style: context.font.bodyMedium?.copyWith(
                      color: context.appColors.error,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          child: BBButton.big(
            label: 'Retry',
            onPressed: () => context.read<SpCubit>().scan(),
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
        ),
      ],
    );
  }
}

class _CaughtUpView extends StatelessWidget {
  const _CaughtUpView({required this.tip, this.lastDurationSecs});
  final int tip;
  final int? lastDurationSecs;

  @override
  Widget build(BuildContext context) {
    final duration = lastDurationSecs;
    return Column(
      children: [
        Expanded(
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
                Text(
                  'Caught up at block $tip',
                  style: context.font.titleMedium?.copyWith(
                    color: context.appColors.success,
                  ),
                ),
                if (duration != null) ...[
                  const Gap(8),
                  Text(
                    'Scanned in ${formatDuration(duration)}',
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          child: BBButton.big(
            label: 'Start scan',
            onPressed: () => context.read<SpCubit>().scan(),
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
        ),
      ],
    );
  }
}

class _ResumeView extends StatelessWidget {
  const _ResumeView({required this.state});
  final SpState state;

  @override
  Widget build(BuildContext context) {
    final last = state.lastScannedHeight;
    final tip = state.chainTip;
    final gap = (last != null && tip != null) ? tip - last : null;
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.search, color: context.appColors.primary, size: 72),
                const Gap(24),
                if (gap != null) ...[
                  Text(
                    '$gap blocks behind',
                    style: context.font.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                  const Gap(4),
                  Text(
                    '~${blocksToApproxDuration(gap, blocksPerDay: SpConfig.blocksPerDay)}',
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ] else
                  Text(
                    'Resume scan',
                    style: context.font.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                if (state.scanLastDurationSecs != null) ...[
                  const Gap(8),
                  Text(
                    'Scanned in ${formatDuration(state.scanLastDurationSecs!)}',
                    style: context.font.bodySmall?.copyWith(
                      color: context.appColors.textMuted,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          child: BBButton.big(
            label: 'Start scan',
            onPressed: () => context.read<SpCubit>().scan(),
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
        ),
      ],
    );
  }
}

/// First-ever scan. When the chain bounds are known, offer the start-height
/// chooser; otherwise fall back to a plain start from the birthday height.
class _FirstScanView extends StatelessWidget {
  const _FirstScanView({required this.state});
  final SpState state;

  @override
  Widget build(BuildContext context) {
    final min = state.minBirthdayHeight;
    final tip = state.chainTip;
    if (min != null && tip != null && tip > min) {
      return _ScanStartChooser(
        minBirthday: min,
        tip: tip,
        onStart: (h) => context.read<SpCubit>().scan(startHeight: h),
      );
    }
    return Column(
      children: [
        Expanded(
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'Ready to scan for incoming silent payments.',
                style: context.font.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          child: BBButton.big(
            label: 'Start scan',
            onPressed: () => context.read<SpCubit>().scan(),
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
        ),
      ],
    );
  }
}

/// Pick the block height the first scan begins at, via a slider, labelled
/// ruler stops, or a numeric field, kept in sync and clamped to
/// `[minBirthday, tip]`.
class _ScanStartChooser extends StatefulWidget {
  const _ScanStartChooser({
    required this.minBirthday,
    required this.tip,
    required this.onStart,
  });

  final int minBirthday;
  final int tip;
  final void Function(int height) onStart;

  @override
  State<_ScanStartChooser> createState() => _ScanStartChooserState();
}

class _ScanStartChooserState extends State<_ScanStartChooser> {
  late int _height = widget.minBirthday;
  late final TextEditingController _controller = TextEditingController(
    text: '$_height',
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  int _clamp(int h) => h.clamp(widget.minBirthday, widget.tip);

  void _setHeight(int h, {bool syncField = true}) {
    final clamped = _clamp(h);
    setState(() => _height = clamped);
    if (syncField) _controller.text = '$clamped';
  }

  @override
  Widget build(BuildContext context) {
    final ticks = scanStartTicks(
      tip: widget.tip,
      minBirthday: widget.minBirthday,
      blocksPerDay: SpConfig.blocksPerDay,
    );
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Choose where to start scanning. Earlier means a longer scan; '
                  'pick after the wallet first received funds.',
                  style: context.font.bodyMedium,
                ),
                const Gap(24),
                Slider(
                  value: _height.toDouble().clamp(
                    widget.minBirthday.toDouble(),
                    widget.tip.toDouble(),
                  ),
                  min: widget.minBirthday.toDouble(),
                  max: widget.tip.toDouble(),
                  activeColor: context.appColors.secondary,
                  inactiveColor: context.appColors.surfaceContainer,
                  onChanged: (v) => _setHeight(v.round()),
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    for (final t in ticks)
                      OutlinedButton(
                        onPressed: () => _setHeight(t.height),
                        child: Text(t.label),
                      ),
                  ],
                ),
                const Gap(24),
                Text('Block height', style: context.font.bodyMedium),
                const Gap(8),
                TextFormField(
                  controller: _controller,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: context.appColors.surface,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide(color: context.appColors.border),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (v) {
                    final parsed = int.tryParse(v);
                    if (parsed != null) _setHeight(parsed, syncField: false);
                  },
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
          child: BBButton.big(
            label: 'Start scan from $_height',
            onPressed: () => widget.onStart(_height),
            bgColor: context.appColors.secondary,
            textColor: context.appColors.onSecondary,
          ),
        ),
      ],
    );
  }
}

class _ScanProgressCard extends StatelessWidget {
  const _ScanProgressCard({required this.state});
  final SpState state;

  @override
  Widget build(BuildContext context) {
    final progress = state.scanProgress;
    final current = state.scanCurrent ?? state.scanFrom;
    final target = state.scanTo;
    final phaseLabel = state.scanPhaseLabel;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (phaseLabel != null) ...[
          Text(
            state.scanPhase == SpScanPhase.spend
                ? 'Step 2 of 2: $phaseLabel'
                : 'Step 1 of 2: $phaseLabel',
            style: context.font.titleMedium,
            textAlign: TextAlign.center,
          ),
          const Gap(12),
        ],
        SizedBox(
          width: 132,
          height: 132,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  // Indeterminate until the first progress tick, then fill.
                  value: progress > 0 ? progress : null,
                  strokeWidth: 6,
                  backgroundColor: context.appColors.surface,
                  color: context.appColors.primary,
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: context.font.titleMedium,
              ),
            ],
          ),
        ),
        const Gap(16),
        Text(
          current != null && target != null
              ? '$current / $target'
              : 'Scanning',
          style: context.font.titleMedium,
          textAlign: TextAlign.center,
        ),
        const Gap(4),
        Text(
          'blocks',
          style: context.font.bodySmall?.copyWith(
            color: context.appColors.textMuted,
          ),
        ),
        const Gap(8),
        _ScanTimings(
          startTime: state.scanStartTime,
          etaSecs: state.scanEtaSecs,
        ),
      ],
    );
  }
}

/// Live elapsed timer (ticks every second) plus the ETA, shown under the scan
/// progress. A local timer keeps the elapsed value moving without churning the
/// cubit; it stops when the scan ends and this widget is disposed.
class _ScanTimings extends StatefulWidget {
  const _ScanTimings({required this.startTime, required this.etaSecs});
  final DateTime? startTime;
  final int? etaSecs;

  @override
  State<_ScanTimings> createState() => _ScanTimingsState();
}

class _ScanTimingsState extends State<_ScanTimings> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final start = widget.startTime;
    final eta = widget.etaSecs;
    final muted = context.font.bodySmall?.copyWith(
      color: context.appColors.textMuted,
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (start != null)
          Text(
            'Elapsed ${formatDuration(DateTime.now().difference(start).inSeconds)}',
            style: muted,
          ),
        if (eta != null)
          Text('~${formatDuration(eta)} remaining', style: muted),
      ],
    );
  }
}
