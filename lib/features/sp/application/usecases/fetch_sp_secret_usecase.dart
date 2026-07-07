import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;
import 'package:convert/convert.dart';

class FetchSpSecretUsecase {
  final Bip85Repository _bip85Repository;
  final GetDefaultSeedUsecase _getDefaultSeedUsecase;

  FetchSpSecretUsecase({
    required this._bip85Repository,
    required this._getDefaultSeedUsecase,
  });

  Future<List<int>?> execute() async {
    final derivations = switch (await _bip85Repository.fetchAll()) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    Bip85DerivationEntity? spDerivation;
    for (final d in derivations) {
      if (d.application == Bip85Application.hex &&
          d.index == SpConfig.bip85Index &&
          d.status == Bip85Status.active) {
        spDerivation = d;
      }
    }
    if (spDerivation == null) return null;

    final seed = await _getDefaultSeedUsecase.execute();
    final xprv = Bip32Derivation.getXprvFromSeed(
      seed.bytes,
      Network.bitcoinMainnet,
    );
    final secretHex = bip85.Bip85Entropy.deriveHex(
      xprvBase58: xprv,
      numBytes: SpConfig.bip85Length,
      index: SpConfig.bip85Index,
    );
    return hex.decode(secretHex); // 64 bytes: [0..32) scan_sk, [32..64) spend_sk
  }
}
