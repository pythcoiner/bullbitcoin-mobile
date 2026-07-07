import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/utils/bip32_derivation.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/core/wallet/domain/entities/wallet.dart';
import 'package:bb_mobile/features/sp/domain/domain_errors.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bip85_entropy/bip85_entropy.dart' as bip85;

class CreateSpSecretUsecase {
  final Bip85Repository _bip85Repository;
  final SettingsRepository _settingsRepository;

  CreateSpSecretUsecase({
    required this._bip85Repository,
    required this._settingsRepository,
  });

  Future<({String derivation, String hex})> execute({
    required Seed defaultSeed,
  }) async {
    final settings = await _settingsRepository.fetch();
    if (settings.isSuperuser != true) {
      throw const SpRequiresSuperuserError();
    }
    if (settings.isDevModeEnabled != true) {
      throw const SpRequiresDevModeError();
    }

    final derivations = switch (await _bip85Repository.fetchAll()) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
    Bip85DerivationEntity? existing;
    for (final d in derivations) {
      if (d.application == Bip85Application.hex &&
          d.index == SpConfig.bip85Index) {
        existing = d;
        break;
      }
    }

    if (existing != null) {
      if (existing.status == Bip85Status.revoked) {
        switch (await _bip85Repository.activate(existing)) {
          case Ok():
            break;
          case Err(:final failure):
            throw failure;
        }
        final xprv = Bip32Derivation.getXprvFromSeed(
          defaultSeed.bytes,
          Network.bitcoinMainnet,
        );
        final hexStr = bip85.Bip85Entropy.deriveHex(
          xprvBase58: xprv,
          numBytes: SpConfig.bip85Length,
          index: SpConfig.bip85Index,
        );
        return (derivation: existing.path, hex: hexStr);
      } else {
        throw const SpDerivationAlreadyExistsError();
      }
    }

    final xprv = Bip32Derivation.getXprvFromSeed(
      defaultSeed.bytes,
      Network.bitcoinMainnet,
    );
    return switch (await _bip85Repository.deriveHex(
      xprvBase58: xprv,
      length: SpConfig.bip85Length,
      index: SpConfig.bip85Index,
    )) {
      Ok(:final value) => value,
      Err(:final failure) => throw failure,
    };
  }
}
