import 'package:bb_mobile/features/sp/application/ports/sp_account_repository.dart';

/// Reveal a fresh taproot receive address to hand out to a payer.
///
/// Each call derives the next never-before-issued address (advancing the
/// receive tip), so the same address is never handed to two payers. Invoke
/// only on an explicit user "generate" action.
class GenerateTaprootAddressUsecase {
  final SpAccountRepository _repository;

  GenerateTaprootAddressUsecase({required this._repository});

  Future<String> execute() => _repository.generateTaprootAddress();
}
