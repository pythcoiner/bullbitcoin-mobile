import 'package:bull_sdk/bwk.dart';

/// Short marker labels for coin sources shown on badges: SP, SW (segwit),
/// TR (taproot).
extension CoinSourceLabel on CoinSource {
  String get shortLabel => switch (this) {
    CoinSource.sp => 'SP',
    CoinSource.segwit => 'SW',
    CoinSource.taproot => 'TR',
    CoinSource.other => 'OTHER',
  };
}
