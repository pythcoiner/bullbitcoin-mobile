import 'package:bull_sdk/bwk.dart';

/// Static configuration for the Silent Payments feature.
///
/// Pure constants only. No business logic, no external dependencies beyond
/// the generated network enum.
abstract class SpConfig {
  static const int bip85Index = 352;
  static const int bip85Length = 64;
  static const String accountName = 'sp';

  /// Rough blocks-per-day used to map a "months/weeks ago" scan start to a
  /// block height. Mainnet pace; test networks mine on demand, so on those the
  /// time-to-height mapping is only indicative.
  static const int blocksPerDay = 144;

  /// Sentinel file placed inside `{appDocs}/{accountName}` BEFORE the account
  /// dir is recursively deleted on revoke. If the delete subsequently fails
  /// (e.g. transient file-locked on Android/iOS because the SP notification
  /// thread still holds the sqlite handle, or iOS document-protection
  /// denial), the repository refuses to load any wallet from a dir containing
  /// this file. This prevents a stale on-disk wallet from being resurrected
  /// after a failed revoke.
  static const String revokedSentinelFile = '.revoked';

  /// bwk's per-directory advisory-lock sentinel, `{accountName}/.lock`. bwk
  /// holds an OS flock on it to refuse a second CROSS-process opener; on mobile
  /// there is only one process, so a lock present at open time is always a
  /// disposed session whose Rust handle Dart has not GC'd yet. The repository
  /// clears it before reopening (sqlite WAL keeps the brief in-process overlap
  /// safe). Must match bwk persist's lock filename.
  static const String lockFile = '.lock';

  // TODO: confirm production URLs for each network
  static const Map<SpNetwork, String> defaultBlindbitUrl = {
    SpNetwork.bitcoin: 'https://blindbit.bullbitcoin.com',
    SpNetwork.signet: 'https://blindbit-signet.bullbitcoin.com',
    SpNetwork.testnet: 'https://blindbit-testnet.bullbitcoin.com',
  };

  static const Map<SpNetwork, String> defaultElectrumUrl = {
    SpNetwork.bitcoin: 'ssl://electrum.bullbitcoin.com:50002',
    SpNetwork.signet: 'ssl://electrum-signet.bullbitcoin.com:50002',
    SpNetwork.testnet: 'ssl://electrum-testnet.bullbitcoin.com:50002',
  };

  // Regtest URLs come from getRegtestDefaults() at runtime, not hardcoded here.
}
