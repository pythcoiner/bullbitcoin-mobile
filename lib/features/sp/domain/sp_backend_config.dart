import 'package:bull_sdk/bwk.dart';

/// The SP backend config (network + node URLs) bb-mobile persists itself.
///
/// The FFI create path does not write a reloadable config file, so the session
/// is reconstructed via `createFromKeys` from this stored config plus the
/// re-derived secret (matching how the silent wallet rebuilds its account).
class SpBackendConfig {
  const SpBackendConfig({
    required this.network,
    required this.blindbitUrl,
    required this.electrumUrl,
  });

  final SpNetwork network;
  final String blindbitUrl;
  final String electrumUrl;

  Map<String, dynamic> toJson() => {
    'network': network.name,
    'blindbitUrl': blindbitUrl,
    'electrumUrl': electrumUrl,
  };

  factory SpBackendConfig.fromJson(Map<String, dynamic> json) =>
      SpBackendConfig(
        network: SpNetwork.values.byName(json['network'] as String),
        blindbitUrl: json['blindbitUrl'] as String,
        electrumUrl: json['electrumUrl'] as String,
      );
}
