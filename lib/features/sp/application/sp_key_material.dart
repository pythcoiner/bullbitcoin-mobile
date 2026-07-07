import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/features/sp/application/application_errors.dart';

/// The BIP39 mnemonic the SP wallet is built from. bwk derives the SP scan/spend
/// keys the standard BIP352 way from this mnemonic, so the same mnemonic yields
/// the same SP wallet as other BIP352 software. Throws when the seed is not
/// mnemonic-backed, the gate the setup/recreate flows enforce.
String spMnemonicFromSeed(Seed seed) {
  if (seed is! MnemonicSeed) {
    throw SpSetupRequiresMnemonicError(
      'SP setup requires a mnemonic-backed seed; got ${seed.runtimeType}',
    );
  }
  return seed.mnemonicWords.join(' ');
}
