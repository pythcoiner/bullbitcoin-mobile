import 'package:bb_mobile/features/sp/application/ports/sp_account_repository.dart';
import 'package:bull_sdk/bwk.dart';

/// Finalizes, signs and broadcasts the confirmed simulation as one
/// irreversible, simulation-pinned step. Returns the broadcast txid.
///
/// The pin (the Rust side rejects a tx whose inputs drifted from the
/// confirmed simulation) lives in the adapter/FFI; this use case just routes
/// the confirmed `TxSimulation` through unchanged.
class SendSpPaymentUsecase {
  final SpAccountRepository _repository;

  SendSpPaymentUsecase({required this._repository});

  Future<String> execute({required TxSimulation simulation}) =>
      _repository.finalizeSignBroadcast(simulation: simulation);
}
