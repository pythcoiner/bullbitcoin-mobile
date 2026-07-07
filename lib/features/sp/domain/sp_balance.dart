import 'package:bull_sdk/bwk.dart';

/// Pure domain value object for the unified Silent Payments balance.
class SpBalance {
  final BigInt confirmedSat;
  final BigInt totalUnifiedSat;
  final int? lastScannedHeight;

  const SpBalance({
    required this.confirmedSat,
    required this.totalUnifiedSat,
    this.lastScannedHeight,
  });

  factory SpBalance.fromView(SpBalanceView view) => SpBalance(
    confirmedSat: view.confirmedSat,
    totalUnifiedSat: view.totalUnifiedSat,
    lastScannedHeight: view.lastScannedHeight,
  );

  bool get hasFunds => totalUnifiedSat > BigInt.zero;
  String get formatted => '$totalUnifiedSat sats';
}
