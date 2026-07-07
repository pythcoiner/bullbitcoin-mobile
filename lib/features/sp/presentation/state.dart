import 'package:bb_mobile/features/sp/domain/sp_balance.dart';
import 'package:bb_mobile/features/sp/presentation/presentation_errors.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'state.freezed.dart';

/// The two phases of an SP scan, reported separately by bwk: the receive
/// (output) scan, then the spend (input) sweep.
enum SpScanPhase { receive, spend }

@freezed
sealed class SpState with _$SpState {
  const factory SpState({
    SpPresentationError? error,
    @Default(false) bool isLoading,
    // Re-entrancy guard for the sign+broadcast path. Dedicated flag (not
    // isLoading) so a stale isLoading from initial load() can never block a
    // legitimate send, and a prepare()-in-flight isLoading does not prevent
    // the user from confirming a separate, completed prepare cycle. The
    // sign/broadcast sequence is irreversible: a second concurrent invocation
    // would produce a second signed tx spending the same coins.
    @Default(false) bool isBroadcasting,

    // Wallet data (populated in load()) — domain types only.
    SpBalance? balance,
    @Default('') String spAddress,
    // Last taproot address revealed via an explicit "generate" action.
    // Empty until the user taps generate; each tap reveals a fresh address
    // (never re-displays a prior one — no address reuse).
    @Default('') String taprootReceiveAddress,
    @Default(false) bool isGeneratingAddress,
    @Default([]) List<SpPaymentView> history,
    @Default([]) List<UnifiedCoinView> coins,
    SpNetwork? network,
    @Default(false) bool backendOnline,

    // Scan progress
    @Default(false) bool isScanning,
    // Which phase the current scan is in (receive then spend); null when idle.
    SpScanPhase? scanPhase,
    // Start of the current scan (for the live elapsed timer); null when idle.
    DateTime? scanStartTime,
    // Estimated seconds remaining (null until the estimator warms up).
    int? scanEtaSecs,
    // Total duration of the just-finished scan; shown on the post-scan view.
    int? scanLastDurationSecs,
    int? lastScannedHeight,
    int? scanFrom,
    int? scanTo,
    int? scanCurrent,
    // Chain tip + earliest scannable height; bound the start-height chooser.
    int? chainTip,
    int? minBirthdayHeight,

    // Receive tab (persists across navigation)
    @Default(0) int receiveTabIndex,

    // Send flow
    RecipientView? recipient,
    BigInt? amountSat,
    @Default(false) bool isMax,
    @Default(1) int feerate,
    TxSimulation? txSimulation,
    @Default([]) List<int> signedTx,
    @Default('') String txid,
  }) = _SpState;
  const SpState._();

  BigInt get totalBalance => balance?.totalUnifiedSat ?? BigInt.zero;

  double get scanProgress {
    final from = scanFrom;
    final current = scanCurrent;
    final to = scanTo;
    if (from == null || to == null || to <= from) return 0.0;
    // Clamp: a phase's current can briefly sit outside [from, to] at a
    // transition, which must never render a negative or >100% bar.
    return (((current ?? from) - from) / (to - from)).clamp(0.0, 1.0);
  }

  /// Human label for the current scan phase, for the two-step progress UI.
  String? get scanPhaseLabel => switch (scanPhase) {
    SpScanPhase.receive => 'Receiving',
    SpScanPhase.spend => 'Checking spends',
    null => null,
  };

  bool get hasSendRecipient => recipient != null;
  bool get hasTxSimulation => txSimulation != null;
  bool get sendSuccess => txid.isNotEmpty;

  /// True once a scan has recorded progress; the chooser is only offered before
  /// the first scan.
  bool get hasScannedBefore => lastScannedHeight != null;

  /// Height the next resume scan would begin at (last scanned + 1).
  int? get nextScanStart {
    final last = lastScannedHeight;
    return last == null ? null : last + 1;
  }

  /// True when the next scan would start past the tip (nothing left to scan).
  bool get isCaughtUp {
    final next = nextScanStart;
    final tip = chainTip;
    return next != null && tip != null && next > tip;
  }
}
