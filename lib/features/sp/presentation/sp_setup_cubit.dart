import 'package:bb_mobile/features/sp/application/usecases/create_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_defaults.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_state.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Thin setup cubit: collects network + backend config, then delegates wallet
/// creation to [CreateSpWalletUsecase] (which gates, clears stale revoked
/// state, derives keys, and creates the on-disk account through the port).
class SpSetupCubit extends Cubit<SpSetupState> {
  final CreateSpWalletUsecase _createSpWalletUsecase;
  final TestSpBackendUsecase _testSpBackendUsecase;
  final SpBackendDefaults Function() _regtestDefaults;

  SpSetupCubit(
    this._createSpWalletUsecase,
    this._testSpBackendUsecase, {
    SpBackendDefaults Function()? regtestDefaults,
  }) : _regtestDefaults = regtestDefaults ?? readSpRegtestBackendDefaults,
       super(
         _stateForNetwork(
           SpNetwork.regtest,
           regtestDefaults ?? readSpRegtestBackendDefaults,
         ),
       );

  Future<void> setNetwork(SpNetwork n) async {
    emit(_stateForNetwork(n, _regtestDefaults));
  }

  Future<void> fetchRegtestDefaults() async {
    emit(state.copyWith(isFetchingDefaults: true, error: null));
    try {
      final defaults = _regtestDefaults();
      if (!defaults.isOk) {
        emit(state.copyWith(isFetchingDefaults: false, error: defaults.error));
        return;
      }
      emit(
        state.copyWith(
          isFetchingDefaults: false,
          blindbitUrl: defaults.blindbitUrl,
          electrumUrl: defaults.electrumUrl,
          blindbitTest: SpConnTest.untested,
          electrumTest: SpConnTest.untested,
          blindbitTestError: null,
          electrumTestError: null,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isFetchingDefaults: false, error: e.toString()));
    }
  }

  void setBlindbitUrl(String url) => emit(
    state.copyWith(
      blindbitUrl: url,
      blindbitTest: SpConnTest.untested,
      blindbitTestError: null,
      error: null,
    ),
  );

  void setElectrumUrl(String url) => emit(
    state.copyWith(
      electrumUrl: url,
      electrumTest: SpConnTest.untested,
      electrumTestError: null,
      error: null,
    ),
  );

  Future<void> testBlindbit() async {
    final url = state.blindbitUrl;
    if (url.isEmpty) return;
    emit(state.copyWith(blindbitTest: SpConnTest.testing, blindbitTestError: null));
    final err = await _testSpBackendUsecase.testBlindbit(url);
    if (isClosed || state.blindbitUrl != url) return;
    emit(
      state.copyWith(
        blindbitTest: err == null ? SpConnTest.ok : SpConnTest.failed,
        blindbitTestError: err,
      ),
    );
  }

  Future<void> testElectrum() async {
    final url = state.electrumUrl;
    if (url.isEmpty) return;
    emit(state.copyWith(electrumTest: SpConnTest.testing, electrumTestError: null));
    final err = await _testSpBackendUsecase.testElectrum(url);
    if (isClosed || state.electrumUrl != url) return;
    emit(
      state.copyWith(
        electrumTest: err == null ? SpConnTest.ok : SpConnTest.failed,
        electrumTestError: err,
      ),
    );
  }

  Future<void> create() async {
    if (!state.canCreate) return;
    emit(state.copyWith(isCreating: true, error: null));
    try {
      await _createSpWalletUsecase.execute(
        network: state.network,
        blindbitUrl: state.blindbitUrl,
        electrumUrl: state.electrumUrl,
      );
      // Wallet creation emits SpSetupChanged on the repository update stream;
      // the wallet feature observes it and reloads. SP does not push to the
      // wallet bloc.
      if (isClosed) return;
      emit(state.copyWith(isCreating: false, created: true));
    } catch (e) {
      if (isClosed) return;
      emit(state.copyWith(isCreating: false, error: e.toString()));
    }
  }

  static SpSetupState _stateForNetwork(
    SpNetwork network,
    SpBackendDefaults Function() regtestDefaults,
  ) {
    final defaults = spBackendDefaultsForNetwork(
      network,
      readRegtestDefaults: regtestDefaults,
    );
    if (!defaults.isOk) {
      return SpSetupState(network: network, error: defaults.error);
    }
    return SpSetupState(
      network: network,
      blindbitUrl: defaults.blindbitUrl,
      electrumUrl: defaults.electrumUrl,
    );
  }
}
