import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bull_sdk/bwk.dart';

class SpBackendDefaults {
  const SpBackendDefaults({
    required this.isOk,
    required this.error,
    required this.blindbitUrl,
    required this.electrumUrl,
  });

  const SpBackendDefaults.ok({
    required String blindbitUrl,
    required String electrumUrl,
  }) : this(
         isOk: true,
         error: '',
         blindbitUrl: blindbitUrl,
         electrumUrl: electrumUrl,
       );

  const SpBackendDefaults.error(String error)
    : this(isOk: false, error: error, blindbitUrl: '', electrumUrl: '');

  final bool isOk;
  final String error;
  final String blindbitUrl;
  final String electrumUrl;
}

SpBackendDefaults readSpRegtestBackendDefaults() {
  final defaults = getRegtestDefaults();
  if (!defaults.isOk) return SpBackendDefaults.error(defaults.error);
  return SpBackendDefaults.ok(
    blindbitUrl: defaults.blindbitUrl,
    electrumUrl: defaults.electrumUrl,
  );
}

SpBackendDefaults spBackendDefaultsForNetwork(
  SpNetwork network, {
  required SpBackendDefaults Function() readRegtestDefaults,
}) {
  if (network == SpNetwork.regtest) return readRegtestDefaults();
  return SpBackendDefaults.ok(
    blindbitUrl: SpConfig.defaultBlindbitUrl[network] ?? '',
    electrumUrl: SpConfig.defaultElectrumUrl[network] ?? '',
  );
}
