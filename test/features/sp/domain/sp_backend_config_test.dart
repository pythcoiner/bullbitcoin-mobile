import 'package:bb_mobile/features/sp/domain/sp_backend_config.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SpBackendConfig', () {
    test('toJson emits the network name and the urls', () {
      const config = SpBackendConfig(
        network: SpNetwork.regtest,
        blindbitUrl: 'http://blindbit.example',
        electrumUrl: 'tcp://electrum.example:50001',
      );

      expect(config.toJson(), {
        'network': 'regtest',
        'blindbitUrl': 'http://blindbit.example',
        'electrumUrl': 'tcp://electrum.example:50001',
      });
    });

    test('fromJson(toJson) round-trips every network', () {
      for (final network in SpNetwork.values) {
        final original = SpBackendConfig(
          network: network,
          blindbitUrl: 'http://blindbit.example',
          electrumUrl: 'tcp://electrum.example:50001',
        );

        final restored = SpBackendConfig.fromJson(original.toJson());

        expect(restored.network, network);
        expect(restored.blindbitUrl, 'http://blindbit.example');
        expect(restored.electrumUrl, 'tcp://electrum.example:50001');
      }
    });
  });
}
