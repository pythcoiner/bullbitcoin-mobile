import 'package:bb_mobile/core/themes/app_theme.dart';
import 'package:bb_mobile/core/widgets/buttons/button.dart';
import 'package:bb_mobile/core/widgets/loading/fading_linear_progress.dart';
import 'package:bb_mobile/features/send/ui/screens/full_screen_scanner_page.dart';
import 'package:bb_mobile/features/sp/presentation/cubit.dart';
import 'package:bb_mobile/features/sp/presentation/state.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';

class SpSendRecipientPage extends StatefulWidget {
  const SpSendRecipientPage({super.key});

  @override
  State<SpSendRecipientPage> createState() => _SpSendRecipientPageState();
}

class _SpSendRecipientPageState extends State<SpSendRecipientPage> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(() {
      setState(() {});
      context.read<SpCubit>().previewRecipient(_controller.text);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Send', style: context.font.headlineMedium),
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
        backgroundColor: context.appColors.secondaryFixedDim,
        body: Column(
          children: [
            Expanded(
              child: _SpCameraSection(
                onScanned: (address) {
                  _controller.text = address;
                },
              ),
            ),
            Card(
              shape: const RoundedRectangleBorder(
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Gap(32),
                      Text(
                        'Recipient address',
                        style: context.font.bodyMedium,
                      ),
                      const Gap(16),
                      TextFormField(
                        controller: _controller,
                        focusNode: _focusNode,
                        maxLines: 3,
                        minLines: 1,
                        textInputAction: TextInputAction.done,
                        decoration: InputDecoration(
                          fillColor: context.appColors.onPrimary,
                          filled: true,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: context.appColors.secondaryFixedDim,
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: context.appColors.secondaryFixedDim,
                            ),
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          hintText: 'Silent payment address or Bitcoin address',
                          hintStyle: context.font.bodyMedium?.copyWith(
                            color: context.appColors.outline,
                          ),
                          suffixIcon: IconButton(
                            icon: Icon(
                              Icons.paste_outlined,
                              color: context.appColors.secondary,
                            ),
                            onPressed: () {
                              Clipboard.getData(Clipboard.kTextPlain).then(
                                (value) {
                                  if (value != null && mounted) {
                                    _controller.text = value.text ?? '';
                                  }
                                },
                              );
                            },
                          ),
                        ),
                      ),
                      const Gap(8),
                      _AddressTypeBadge(input: _controller.text),
                      const Gap(16),
                      BlocSelector<SpCubit, SpState, String?>(
                        selector: (state) => state.error?.message,
                        builder: (context, errorMsg) {
                          if (errorMsg == null || errorMsg.isEmpty) {
                            return const SizedBox.shrink();
                          }
                          return Center(
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
                      const Gap(16),
                      BBButton.big(
                        label: 'Continue',
                        onPressed: () => context
                            .read<SpCubit>()
                            .previewRecipient(_controller.text),
                        disabled: _controller.text.trim().isEmpty,
                        bgColor: context.appColors.secondary,
                        textColor: context.appColors.onSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SpCameraSection extends StatelessWidget {
  const _SpCameraSection({required this.onScanned});
  final void Function(String address) onScanned;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.appColors.secondaryFixedDim,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.qr_code_scanner, size: 80, color: context.appColors.secondary),
            const Gap(16),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).push(
                PageRouteBuilder(
                  pageBuilder: (context, animation, secondaryAnimation) => FullScreenScannerPage(
                    onScannedPaymentRequest: (paymentRequest) {
                      onScanned(paymentRequest.$1);
                    },
                  ),
                  transitionsBuilder:
                      (context, animation, secondaryAnimation, child) => child,
                ),
              ),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Scan QR code'),
            ),
          ],
        ),
      ),
    );
  }
}

class _AddressTypeBadge extends StatelessWidget {
  const _AddressTypeBadge({required this.input});
  final String input;

  @override
  Widget build(BuildContext context) {
    if (input.trim().isEmpty) return const SizedBox.shrink();
    final lower = input.trim().toLowerCase();
    final String label;
    final Color color;
    if (lower.startsWith('sp1') || lower.startsWith('tsp1')) {
      label = 'Silent Payment';
      color = context.appColors.success;
    } else if (lower.startsWith('bc1') ||
        lower.startsWith('tb1') ||
        lower.startsWith('1') ||
        lower.startsWith('m') ||
        lower.startsWith('n')) {
      label = 'Bitcoin Address';
      color = context.appColors.primary;
    } else {
      label = 'Unrecognized';
      color = context.appColors.error;
    }
    return Chip(
      label: Text(label, style: context.font.bodySmall),
      backgroundColor: color.withValues(alpha: 0.15),
      side: BorderSide(color: color),
    );
  }
}
