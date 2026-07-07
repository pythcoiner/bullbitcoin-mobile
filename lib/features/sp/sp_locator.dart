import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/storage/data/datasources/key_value_storage/key_value_storage_datasource.dart';
import 'package:bb_mobile/core/utils/constants.dart';
import 'package:bb_mobile/features/sp/adapters/bwk_sp_account_repository.dart';
import 'package:bb_mobile/features/sp/adapters/key_value_sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_backend_config_repository.dart';
import 'package:bb_mobile/features/sp/application/usecases/check_sp_wallet_setup_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/create_sp_secret_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/create_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/ensure_sp_session_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/fetch_sp_secret_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/generate_taproot_address_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/get_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/prepare_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/refresh_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/recreate_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/resync_sp_listener_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/scan_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/send_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/test_sp_backend_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/stop_sp_scan_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/watch_sp_notification_log_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/watch_sp_notifications_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/watch_sp_updates_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_settings_cubit.dart';
import 'package:bb_mobile/features/sp/presentation/sp_setup_cubit.dart';
import 'package:bb_mobile/features/sp/public/sp_facade.dart';
import 'package:get_it/get_it.dart';

/// DI wiring for the Silent Payments feature:
/// adapter (single live session) -> use cases -> facade -> presentation.
///
/// Must be registered BEFORE the wallet/settings locators, whose own use
/// cases resolve `locator<SpFacade>()`.
class SpLocator {
  static void setup(GetIt locator) {
    _registerAdapters(locator);
    _registerUseCases(locator);
    _registerFacade(locator);
    _registerPresentation(locator);
  }

  static void _registerAdapters(GetIt locator) {
    // lazySingleton: exactly one owner of the live SpAccount session.
    locator.registerLazySingleton<SpAccountRepository>(
      BwkSpAccountRepository.new,
    );
    locator.registerLazySingleton<SpBackendConfigRepository>(
      () => KeyValueSpBackendConfigRepository(
        storage: locator<KeyValueStorageDatasource<String>>(
          instanceName: LocatorInstanceNameConstants.secureStorageDatasource,
        ),
      ),
    );
  }

  static void _registerUseCases(GetIt locator) {
    locator.registerFactory<CreateSpSecretUsecase>(
      () => CreateSpSecretUsecase(
        bip85Repository: locator<Bip85Repository>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<FetchSpSecretUsecase>(
      () => FetchSpSecretUsecase(
        bip85Repository: locator<Bip85Repository>(),
        getDefaultSeedUsecase: locator<GetDefaultSeedUsecase>(),
      ),
    );
    // Singleton: its in-flight guard serializes session establishment so
    // concurrent callers never race two live SpAccount instances.
    locator.registerLazySingleton<EnsureSpSessionUsecase>(
      () => EnsureSpSessionUsecase(
        repository: locator<SpAccountRepository>(),
        configRepository: locator<SpBackendConfigRepository>(),
        fetchSpSecretUsecase: locator<FetchSpSecretUsecase>(),
        getDefaultSeedUsecase: locator<GetDefaultSeedUsecase>(),
      ),
    );
    locator.registerFactory<GetSpWalletUsecase>(
      () => GetSpWalletUsecase(
        ensureSpSessionUsecase: locator<EnsureSpSessionUsecase>(),
        settingsRepository: locator<SettingsRepository>(),
      ),
    );
    locator.registerFactory<CheckSpWalletSetupUsecase>(
      () => CheckSpWalletSetupUsecase(
        fetchSpSecretUsecase: locator<FetchSpSecretUsecase>(),
        settingsRepository: locator<SettingsRepository>(),
        configRepository: locator<SpBackendConfigRepository>(),
      ),
    );
    locator.registerFactory<RevokeSpWalletUsecase>(
      () => RevokeSpWalletUsecase(
        bip85Repository: locator<Bip85Repository>(),
        repository: locator<SpAccountRepository>(),
        configRepository: locator<SpBackendConfigRepository>(),
      ),
    );
    locator.registerFactory<ScanSpWalletUsecase>(
      () => ScanSpWalletUsecase(repository: locator<SpAccountRepository>()),
    );
    locator.registerFactory<StopSpScanUsecase>(
      () => StopSpScanUsecase(repository: locator<SpAccountRepository>()),
    );
    locator.registerFactory<GenerateTaprootAddressUsecase>(
      () => GenerateTaprootAddressUsecase(
        repository: locator<SpAccountRepository>(),
      ),
    );
    locator.registerFactory<PrepareSpPaymentUsecase>(
      () => PrepareSpPaymentUsecase(repository: locator<SpAccountRepository>()),
    );
    locator.registerFactory<SendSpPaymentUsecase>(
      () => SendSpPaymentUsecase(repository: locator<SpAccountRepository>()),
    );
    locator.registerFactory<LoadSpWalletDataUsecase>(
      () => LoadSpWalletDataUsecase(
        repository: locator<SpAccountRepository>(),
        ensureSpSessionUsecase: locator<EnsureSpSessionUsecase>(),
      ),
    );
    locator.registerFactory<WatchSpNotificationsUsecase>(
      () => WatchSpNotificationsUsecase(
        repository: locator<SpAccountRepository>(),
      ),
    );
    locator.registerFactory<RefreshSpWalletUsecase>(
      () => RefreshSpWalletUsecase(
        repository: locator<SpAccountRepository>(),
        getSpWalletUsecase: locator<GetSpWalletUsecase>(),
      ),
    );
    locator.registerFactory<CreateSpWalletUsecase>(
      () => CreateSpWalletUsecase(
        getDefaultSeedUsecase: locator<GetDefaultSeedUsecase>(),
        createSpSecretUsecase: locator<CreateSpSecretUsecase>(),
        repository: locator<SpAccountRepository>(),
        configRepository: locator<SpBackendConfigRepository>(),
      ),
    );
    locator.registerFactory<RecreateSpWalletUsecase>(
      () => RecreateSpWalletUsecase(
        locator<GetDefaultSeedUsecase>(),
        locator<FetchSpSecretUsecase>(),
        locator<SpAccountRepository>(),
        locator<SpBackendConfigRepository>(),
        locator<EnsureSpSessionUsecase>(),
      ),
    );
    locator.registerFactory<WatchSpUpdatesUsecase>(
      () => WatchSpUpdatesUsecase(repository: locator<SpAccountRepository>()),
    );
    locator.registerFactory<WatchSpNotificationLogUsecase>(
      () => WatchSpNotificationLogUsecase(
        repository: locator<SpAccountRepository>(),
      ),
    );
    locator.registerFactory<ResyncSpListenerUsecase>(
      () => ResyncSpListenerUsecase(repository: locator<SpAccountRepository>()),
    );
    locator.registerFactory<TestSpBackendUsecase>(() => TestSpBackendUsecase());
  }

  static void _registerFacade(GetIt locator) {
    locator.registerLazySingleton<SpFacade>(
      () => SpFacade(
        refreshSpWalletUsecase: locator<RefreshSpWalletUsecase>(),
        getSpWalletUsecase: locator<GetSpWalletUsecase>(),
        checkSpWalletSetupUsecase: locator<CheckSpWalletSetupUsecase>(),
        revokeSpWalletUsecase: locator<RevokeSpWalletUsecase>(),
        watchSpUpdatesUsecase: locator<WatchSpUpdatesUsecase>(),
        resyncSpListenerUsecase: locator<ResyncSpListenerUsecase>(),
      ),
    );
  }

  static void _registerPresentation(GetIt locator) {
    locator.registerFactory<SpCubit>(
      () => SpCubit(
        loadSpWalletDataUsecase: locator<LoadSpWalletDataUsecase>(),
        watchSpNotificationsUsecase: locator<WatchSpNotificationsUsecase>(),
        scanSpWalletUsecase: locator<ScanSpWalletUsecase>(),
        stopSpScanUsecase: locator<StopSpScanUsecase>(),
        prepareSpPaymentUsecase: locator<PrepareSpPaymentUsecase>(),
        sendSpPaymentUsecase: locator<SendSpPaymentUsecase>(),
        revokeSpWalletUsecase: locator<RevokeSpWalletUsecase>(),
        generateTaprootAddressUsecase: locator<GenerateTaprootAddressUsecase>(),
      ),
    );
    locator.registerFactory<SpSetupCubit>(
      () => SpSetupCubit(
        locator<CreateSpWalletUsecase>(),
        locator<TestSpBackendUsecase>(),
      ),
    );
    locator.registerFactory<SpSettingsCubit>(
      () => SpSettingsCubit(
        locator<RecreateSpWalletUsecase>(),
        locator<WatchSpNotificationLogUsecase>(),
        locator<TestSpBackendUsecase>(),
        locator<SpBackendConfigRepository>(),
      ),
    );
  }
}
