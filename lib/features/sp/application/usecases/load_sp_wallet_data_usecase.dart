import 'package:bb_mobile/features/sp/application/application_errors.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/application/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_wallet.dart';
import 'package:bull_sdk/bwk.dart';

/// Reads the current wallet snapshot + payment history + backend info in one
/// call (used by the cubit on load and after coin-change notifications).
class SpWalletData {
  final SpWallet wallet;
  final List<SpPaymentView> history;
  final List<UnifiedCoinView> coins;
  final SpNetwork? network;
  final bool backendOnline;
  final int? chainTip;
  final int minBirthdayHeight;

  const SpWalletData({
    required this.wallet,
    required this.history,
    required this.coins,
    required this.network,
    required this.backendOnline,
    this.chainTip,
    this.minBirthdayHeight = 0,
  });
}

class LoadSpWalletDataUsecase {
  final SpAccountRepository _repository;
  final EnsureSpSessionUsecase _ensureSpSessionUsecase;

  LoadSpWalletDataUsecase({
    required this._repository,
    required this._ensureSpSessionUsecase,
  });

  Future<SpWalletData> execute() async {
    // Establish (or reuse) the live session, reconstructing it from the
    // persisted config if it was recycled out from under us. A null result
    // means the wallet is gone (revoked / not set up).
    final wallet = await _ensureSpSessionUsecase.execute();
    if (wallet == null) {
      throw const SpNotSetUpError('SP session unavailable');
    }
    final history = await _repository.history();
    final coins = await _repository.coins();
    return SpWalletData(
      wallet: wallet,
      history: history,
      coins: coins,
      network: _repository.network(),
      backendOnline: _repository.backendOnline(),
      chainTip: _repository.chainTip(),
      minBirthdayHeight: _repository.minBirthdayHeight(),
    );
  }
}
