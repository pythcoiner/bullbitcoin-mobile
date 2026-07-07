import 'package:bb_mobile/features/sp/application/ports/sp_account_repository.dart';
import 'package:bull_sdk/bwk.dart';

/// Builds a transaction simulation (coin selection + fee preview) for the
/// confirm screen. Does not sign or broadcast.
class PrepareSpPaymentUsecase {
  final SpAccountRepository _repository;

  PrepareSpPaymentUsecase({required this._repository});

  Future<TxSimulation> execute({
    required List<RecipientView> recipients,
    required BigInt feerateSatVb,
  }) => _repository.preparePsbt(
    recipients: recipients,
    feerateSatVb: feerateSatVb,
  );
}
