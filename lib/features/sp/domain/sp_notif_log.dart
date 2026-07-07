import 'package:bull_sdk/bwk.dart';

/// One timestamped line in the SP notifications debug console.
class SpNotifLogLine {
  const SpNotifLogLine({required this.time, required this.text});

  final DateTime time;
  final String text;
}

/// One-line, human-readable rendering of a Rust-side [SpNotification] for the
/// debug console. ElectrumTx shows the sub-account kind, txid, amount and
/// height so a missing taproot electrum push is visible.
String formatSpNotification(SpNotification n) {
  switch (n) {
    case SpNotification_ScanStarted(:final from, :final to):
      return 'ScanStarted $from -> $to';
    case SpNotification_ScanReceiveProgress(:final current, :final end):
      return 'ScanReceiveProgress $current / $end';
    case SpNotification_ScanSpendProgress(:final current, :final end):
      return 'ScanSpendProgress $current / $end';
    case SpNotification_ScanCompleted():
      return 'ScanCompleted';
    case SpNotification_ScanStopped():
      return 'ScanStopped';
    case SpNotification_ScanFailed(:final message):
      return 'ScanFailed: $message';
    case SpNotification_NewOutput(:final outpoint, :final amountSat):
      return 'NewOutput $outpoint ${amountSat}sat';
    case SpNotification_OutputSpent(:final outpoint):
      return 'OutputSpent $outpoint';
    case SpNotification_ElectrumTx(
      :final kind,
      :final txid,
      :final amountSat,
      :final height,
    ):
      final at = height == null ? '' : ' @$height';
      return 'ElectrumTx ${kind.name} $txid ${amountSat}sat$at';
    case SpNotification_BackendOffline():
      return 'BackendOffline';
  }
}
