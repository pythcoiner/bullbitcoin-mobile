import 'package:bb_mobile/features/sp/application/ports/sp_account_repository.dart';

/// USER-TRIGGERED ONLY. This is the single Dart entry point to the Rust scan.
/// Only `SpCubit.scan()` (the Scan button handler) may invoke this use case.
/// Do NOT call from lifecycle hooks, timers, route observers, or background
/// services — the no-auto-scan invariant depends on it.
class ScanSpWalletUsecase {
  final SpAccountRepository _repository;

  ScanSpWalletUsecase({required this._repository});

  /// `startHeight` overrides where the scan begins (null resumes from the last
  /// scanned position); used by the first-scan start chooser.
  Future<void> execute({int? startHeight}) =>
      _repository.scanOnce(startHeight: startHeight);
}
