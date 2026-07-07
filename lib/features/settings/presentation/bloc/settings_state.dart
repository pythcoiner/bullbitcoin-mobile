part of 'settings_cubit.dart';

@freezed
sealed class SettingsState with _$SettingsState {
  const factory SettingsState({
    SettingsEntity? storedSettings,
    String? appVersion,
    bool? hasLegacySeeds,
    // Surfaced to the UI when `toggleDevMode(false)` could not fully wipe
    // the SP wallet on disk (e.g. file-locked because the SP notification
    // thread still holds the sqlite handle, or iOS document-protection
    // denial). Dev mode is still flipped off in that case because
    // `RevokeSpWalletUsecase` drops a `.revoked` sentinel BEFORE the
    // recursive delete, so `GetSpWalletUsecase` will refuse to load the
    // partial-state wallet. The user-facing error allows the UI to prompt
    // the user to retry / restart the app.
    String? revokeSpError,
  }) = _SettingsState;
  const SettingsState._();

  Environment? get environment => storedSettings?.environment;
  BitcoinUnit? get bitcoinUnit => storedSettings?.bitcoinUnit;
  Language? get language => storedSettings?.language;
  String? get currencyCode => storedSettings?.currencyCode;
  bool? get hideAmounts => storedSettings?.hideAmounts;
  bool? get isSuperuser => storedSettings?.isSuperuser;
  bool? get isDevModeEnabled => storedSettings?.isDevModeEnabled;
  bool get isErrorReportingEnabled =>
      storedSettings?.isErrorReportingEnabled ?? false;
  String? get exchangeTestnetBasicAuthUsername =>
      storedSettings?.exchangeTestnetBasicAuthUsername;
  String? get exchangeTestnetBasicAuthPassword =>
      storedSettings?.exchangeTestnetBasicAuthPassword;
}
