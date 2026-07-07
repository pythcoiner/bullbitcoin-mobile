import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/features/sp/application/application_errors.dart';
import 'package:bb_mobile/features/sp/application/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_wallet.dart';

/// Loads the SP wallet snapshot, enforcing the superuser + dev-mode gate.
///
/// The gate lives here (not in the adapter) so the secondary adapter stays
/// free of use-case/settings concerns. `EnsureSpSessionUsecase` establishes
/// the live session (reconstructing it from the persisted config) and returns
/// null when the wallet is not set up (revoked / no config / no secret).
class GetSpWalletUsecase {
  final EnsureSpSessionUsecase _ensureSpSessionUsecase;
  final SettingsRepository _settingsRepository;

  GetSpWalletUsecase({
    required this._ensureSpSessionUsecase,
    required this._settingsRepository,
  });

  Future<SpWallet?> execute() async {
    try {
      final settings = await _settingsRepository.fetch();
      if (settings.isSuperuser != true) return null;
      if (settings.isDevModeEnabled != true) return null;

      return await _ensureSpSessionUsecase.execute();
    } catch (e) {
      throw SpApplicationError.fromFfiError(e);
    }
  }
}
