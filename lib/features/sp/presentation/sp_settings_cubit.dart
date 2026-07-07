import 'dart:async';

import 'package:bb_mobile/features/sp/application/ports/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/application/usecases/recreate_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/watch_sp_notification_log_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/presentation/sp_backend_defaults.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class SpSettingsState {
  const SpSettingsState({
    this.initialized = false,
    this.network = SpNetwork.regtest,
    this.blindbitUrl = '',
    this.electrumUrl = '',
    this.formRevision = 0,
    this.blindbitTest = SpConnTest.untested,
    this.electrumTest = SpConnTest.untested,
    this.blindbitTestError,
    this.electrumTestError,
    this.isFetchingDefaults = false,
    this.isSaving = false,
    this.saved = false,
    this.error,
    this.console = const [],
  });

  final bool initialized;
  final SpNetwork network;
  final String blindbitUrl;
  final String electrumUrl;
  // Bumped on programmatic URL changes (load/fetch/network) so the text fields
  // (keyed on it) rebuild; NOT bumped on user typing, to preserve the cursor.
  final int formRevision;
  final SpConnTest blindbitTest;
  final SpConnTest electrumTest;
  final String? blindbitTestError;
  final String? electrumTestError;
  final bool isFetchingDefaults;
  final bool isSaving;
  final bool saved;
  final String? error;
  final List<SpNotifLogLine> console;

  // A wrong address can't be saved: both URLs must pass a connection test.
  bool get canSave =>
      blindbitUrl.isNotEmpty &&
      electrumUrl.isNotEmpty &&
      blindbitTest == SpConnTest.ok &&
      electrumTest == SpConnTest.ok &&
      !isSaving;

  SpSettingsState copyWith({
    bool? initialized,
    SpNetwork? network,
    String? blindbitUrl,
    String? electrumUrl,
    int? formRevision,
    SpConnTest? blindbitTest,
    SpConnTest? electrumTest,
    String? blindbitTestError,
    String? electrumTestError,
    bool clearBlindbitTestError = false,
    bool clearElectrumTestError = false,
    bool? isFetchingDefaults,
    bool? isSaving,
    bool? saved,
    String? error,
    bool clearError = false,
    List<SpNotifLogLine>? console,
  }) => SpSettingsState(
    initialized: initialized ?? this.initialized,
    network: network ?? this.network,
    blindbitUrl: blindbitUrl ?? this.blindbitUrl,
    electrumUrl: electrumUrl ?? this.electrumUrl,
    formRevision: formRevision ?? this.formRevision,
    blindbitTest: blindbitTest ?? this.blindbitTest,
    electrumTest: electrumTest ?? this.electrumTest,
    blindbitTestError: clearBlindbitTestError
        ? null
        : blindbitTestError ?? this.blindbitTestError,
    electrumTestError: clearElectrumTestError
        ? null
        : electrumTestError ?? this.electrumTestError,
    isFetchingDefaults: isFetchingDefaults ?? this.isFetchingDefaults,
    isSaving: isSaving ?? this.isSaving,
    saved: saved ?? this.saved,
    error: clearError ? null : error ?? this.error,
    console: console ?? this.console,
  );
}

class SpSettingsCubit extends Cubit<SpSettingsState> {
  final RecreateSpWalletUsecase _recreateSpWalletUsecase;
  final WatchSpNotificationLogUsecase _watchNotificationLogUsecase;
  final TestSpBackendUsecase _testSpBackendUsecase;
  final SpBackendConfigRepository _configRepository;
  final SpBackendDefaults Function() _regtestDefaults;

  static const int _consoleCap = 200;
  final List<SpNotifLogLine> _console = [];
  StreamSubscription<SpNotifLogLine>? _logSub;
  int _formRevision = 0;

  SpSettingsCubit(
    this._recreateSpWalletUsecase,
    this._watchNotificationLogUsecase,
    this._testSpBackendUsecase,
    this._configRepository, {
    SpBackendDefaults Function()? regtestDefaults,
  }) : _regtestDefaults = regtestDefaults ?? readSpRegtestBackendDefaults,
       super(
         _stateForNetwork(
           SpNetwork.regtest,
           initialized: false,
           regtestDefaults: regtestDefaults ?? readSpRegtestBackendDefaults,
         ),
       ) {
    _console.addAll(_watchNotificationLogUsecase.current());
    if (_console.isNotEmpty) {
      emit(state.copyWith(console: List.unmodifiable(_console)));
    }
    _logSub = _watchNotificationLogUsecase.stream().listen((line) {
      _console.add(line);
      if (_console.length > _consoleCap) _console.removeAt(0);
      emit(state.copyWith(console: List.unmodifiable(_console)));
    });
  }

  /// Load the SAVED backend config (custom URLs) when present, falling back to
  /// the network defaults. Then auto-test both so the current connection state
  /// shows without the user tapping.
  Future<void> initFromNetwork(SpNetwork? network) async {
    if (state.initialized) return;
    final stored = await _configRepository.fetch();
    if (stored != null) {
      emit(
        SpSettingsState(
          initialized: true,
          network: stored.network,
          blindbitUrl: stored.blindbitUrl,
          electrumUrl: stored.electrumUrl,
          formRevision: ++_formRevision,
          console: List.unmodifiable(_console),
        ),
      );
    } else if (network != null) {
      emit(
        _stateForNetwork(
          network,
          initialized: true,
          regtestDefaults: _regtestDefaults,
        ).copyWith(
          formRevision: ++_formRevision,
          console: List.unmodifiable(_console),
        ),
      );
    } else {
      return;
    }
    unawaited(testBlindbit());
    unawaited(testElectrum());
  }

  void setNetwork(SpNetwork network) {
    emit(
      _stateForNetwork(
        network,
        initialized: true,
        regtestDefaults: _regtestDefaults,
      ).copyWith(
        formRevision: ++_formRevision,
        console: List.unmodifiable(_console),
      ),
    );
  }

  Future<void> fetchRegtestDefaults() async {
    emit(
      state.copyWith(
        initialized: true,
        isFetchingDefaults: true,
        saved: false,
        clearError: true,
      ),
    );
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
          formRevision: ++_formRevision,
          blindbitTest: SpConnTest.untested,
          electrumTest: SpConnTest.untested,
          clearBlindbitTestError: true,
          clearElectrumTestError: true,
        ),
      );
    } catch (e) {
      emit(state.copyWith(isFetchingDefaults: false, error: e.toString()));
    }
  }

  void setBlindbitUrl(String url) => emit(
    state.copyWith(
      initialized: true,
      blindbitUrl: url,
      blindbitTest: SpConnTest.untested,
      clearBlindbitTestError: true,
      saved: false,
      clearError: true,
    ),
  );

  void setElectrumUrl(String url) => emit(
    state.copyWith(
      initialized: true,
      electrumUrl: url,
      electrumTest: SpConnTest.untested,
      clearElectrumTestError: true,
      saved: false,
      clearError: true,
    ),
  );

  Future<void> testBlindbit() async {
    final url = state.blindbitUrl;
    if (url.isEmpty) return;
    emit(state.copyWith(blindbitTest: SpConnTest.testing, clearBlindbitTestError: true));
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
    emit(state.copyWith(electrumTest: SpConnTest.testing, clearElectrumTestError: true));
    final err = await _testSpBackendUsecase.testElectrum(url);
    if (isClosed || state.electrumUrl != url) return;
    emit(
      state.copyWith(
        electrumTest: err == null ? SpConnTest.ok : SpConnTest.failed,
        electrumTestError: err,
      ),
    );
  }

  void clearConsole() {
    _console.clear();
    emit(state.copyWith(console: const []));
  }

  Future<void> saveBackendConfig() async {
    if (!state.canSave) return;
    emit(state.copyWith(isSaving: true, saved: false, clearError: true));
    try {
      await _recreateSpWalletUsecase.execute(
        network: state.network,
        blindbitUrl: state.blindbitUrl,
        electrumUrl: state.electrumUrl,
      );
      emit(state.copyWith(isSaving: false, saved: true));
    } catch (e) {
      emit(state.copyWith(isSaving: false, error: e.toString()));
    }
  }

  @override
  Future<void> close() async {
    await _logSub?.cancel();
    return super.close();
  }

  static SpSettingsState _stateForNetwork(
    SpNetwork network, {
    required bool initialized,
    required SpBackendDefaults Function() regtestDefaults,
  }) {
    final defaults = spBackendDefaultsForNetwork(
      network,
      readRegtestDefaults: regtestDefaults,
    );
    if (!defaults.isOk) {
      return SpSettingsState(
        initialized: initialized,
        network: network,
        error: defaults.error,
      );
    }
    return SpSettingsState(
      initialized: initialized,
      network: network,
      blindbitUrl: defaults.blindbitUrl,
      electrumUrl: defaults.electrumUrl,
    );
  }
}
