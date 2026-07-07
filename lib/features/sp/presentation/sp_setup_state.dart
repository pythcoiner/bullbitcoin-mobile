import 'package:bb_mobile/features/sp/application/usecases/test_sp_backend_usecase.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'sp_setup_state.freezed.dart';

@freezed
sealed class SpSetupState with _$SpSetupState {
  const factory SpSetupState({
    @Default(SpNetwork.regtest) SpNetwork network,
    @Default('') String blindbitUrl,
    @Default('') String electrumUrl,
    @Default(SpConnTest.untested) SpConnTest blindbitTest,
    @Default(SpConnTest.untested) SpConnTest electrumTest,
    String? blindbitTestError,
    String? electrumTestError,
    @Default(false) bool isFetchingDefaults,
    @Default(false) bool isCreating,
    @Default(false) bool created,
    String? error,
  }) = _SpSetupState;

  const SpSetupState._();

  // A wrong address can't create a wallet: both URLs must pass a connection test.
  bool get canCreate =>
      blindbitUrl.isNotEmpty &&
      electrumUrl.isNotEmpty &&
      blindbitTest == SpConnTest.ok &&
      electrumTest == SpConnTest.ok &&
      !isCreating;
}
