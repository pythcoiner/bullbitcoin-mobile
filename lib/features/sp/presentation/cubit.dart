import 'dart:async';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/sp/application/usecases/generate_taproot_address_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/load_sp_wallet_data_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/prepare_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/revoke_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/scan_sp_wallet_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/send_sp_payment_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/stop_sp_scan_usecase.dart';
import 'package:bb_mobile/features/sp/application/usecases/watch_sp_notifications_usecase.dart';
import 'package:bb_mobile/features/sp/presentation/presentation_errors.dart';
import 'package:bb_mobile/features/sp/presentation/sp_sync_estimator.dart';
import 'package:bb_mobile/features/sp/presentation/state.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

/// Thin presentation cubit: transforms between UI state and SP use cases.
/// No FFI access, no orchestration — all of that lives in the application
/// layer behind the `SpAccountRepository` port.
class SpCubit extends Cubit<SpState> {
  final LoadSpWalletDataUsecase loadSpWalletDataUsecase;
  final WatchSpNotificationsUsecase watchSpNotificationsUsecase;
  final ScanSpWalletUsecase scanSpWalletUsecase;
  final StopSpScanUsecase stopSpScanUsecase;
  final PrepareSpPaymentUsecase prepareSpPaymentUsecase;
  final SendSpPaymentUsecase sendSpPaymentUsecase;
  final RevokeSpWalletUsecase revokeSpWalletUsecase;
  final GenerateTaprootAddressUsecase generateTaprootAddressUsecase;

  StreamSubscription<SpNotification>? _notificationSub;
  final SpSyncEstimator _etaEstimator = SpSyncEstimator();

  SpCubit({
    required this.loadSpWalletDataUsecase,
    required this.watchSpNotificationsUsecase,
    required this.scanSpWalletUsecase,
    required this.stopSpScanUsecase,
    required this.prepareSpPaymentUsecase,
    required this.sendSpPaymentUsecase,
    required this.revokeSpWalletUsecase,
    required this.generateTaprootAddressUsecase,
  }) : super(const SpState());

  Future<void> load() async {
    try {
      if (isClosed) return;
      emit(state.copyWith(isLoading: true, error: null));
      final data = await loadSpWalletDataUsecase.execute();
      if (isClosed) return;
      emit(
        state.copyWith(
          balance: data.wallet.balance,
          spAddress: data.wallet.spAddress,
          history: data.history,
          coins: data.coins,
          lastScannedHeight: data.wallet.lastScannedHeight,
          isScanning: data.wallet.isScanning,
          network: data.network,
          backendOnline: data.backendOnline,
          chainTip: data.chainTip,
          minBirthdayHeight: data.minBirthdayHeight,
        ),
      );
      _subscribeToNotifications();
    } catch (e) {
      log.warning('SpCubit.load: $e');
      if (isClosed) return;
      emit(state.copyWith(error: SpPresentationError.from(e)));
    } finally {
      if (!isClosed) emit(state.copyWith(isLoading: false));
    }
  }

  /// Reveal a fresh taproot receive address (explicit user action). Each call
  /// hands out a new never-before-issued address — never re-displays a prior
  /// one, so an address is never given to two payers.
  Future<void> generateTaprootAddress() async {
    try {
      if (isClosed) return;
      emit(state.copyWith(isGeneratingAddress: true, error: null));
      final address = await generateTaprootAddressUsecase.execute();
      if (isClosed) return;
      emit(state.copyWith(taprootReceiveAddress: address));
    } catch (e) {
      log.warning('SpCubit.generateTaprootAddress: $e');
      if (isClosed) return;
      emit(state.copyWith(error: SpPresentationError.from(e)));
    } finally {
      if (!isClosed) emit(state.copyWith(isGeneratingAddress: false));
    }
  }

  void _subscribeToNotifications() {
    try {
      unawaited(_notificationSub?.cancel());
      _notificationSub = watchSpNotificationsUsecase.execute().listen(
        _onNotification,
        // The singleton session can be recycled out from under us (a wallet-
        // side full refresh after a network change disposes it). When that
        // closes the notification stream, re-establish + re-subscribe via
        // load() instead of leaving a dead screen. A genuinely revoked wallet
        // makes load() emit an error and not re-subscribe, so this can't loop.
        onDone: _reestablishSession,
        onError: (Object e) {
          log.warning('SpCubit: notification stream error: $e');
          _reestablishSession();
        },
      );
    } catch (e) {
      log.warning('SpCubit: notification subscribe failed: $e');
    }
  }

  void _reestablishSession() {
    if (isClosed) return;
    unawaited(load());
  }

  void _onNotification(SpNotification n) {
    if (isClosed) return;
    switch (n) {
      case SpNotification_ScanStarted(:final from, :final to):
        _etaEstimator.reset();
        emit(
          state.copyWith(
            isScanning: true,
            scanPhase: SpScanPhase.receive,
            scanStartTime: DateTime.now(),
            scanEtaSecs: null,
            scanLastDurationSecs: null,
            scanFrom: from,
            scanTo: to,
            scanCurrent: from,
          ),
        );
      case SpNotification_ScanReceiveProgress(:final current, :final end):
        _etaEstimator.update(current, end, DateTime.now());
        emit(
          state.copyWith(
            scanPhase: SpScanPhase.receive,
            scanCurrent: current,
            scanTo: end,
            scanEtaSecs: _etaEstimator.estimateSecs(),
          ),
        );
      case SpNotification_ScanSpendProgress(:final current, :final end):
        // First spend update: switch to step 2 and rebase the bar to the spend
        // range (its `current` is the spend start) so it runs 0 -> 100% again.
        final entering = state.scanPhase != SpScanPhase.spend;
        _etaEstimator.update(current, end, DateTime.now());
        emit(
          state.copyWith(
            scanPhase: SpScanPhase.spend,
            scanFrom: entering ? current : state.scanFrom,
            scanCurrent: current,
            scanTo: end,
            scanEtaSecs: _etaEstimator.estimateSecs(),
          ),
        );
      case SpNotification_ScanCompleted():
        // The one-shot scan runs on a background thread, so ScanCompleted is the
        // real done signal (scanOnce returned long before). Refresh here; the
        // lock is free between the scanner's per-block work, so the read does
        // not block.
        final start = state.scanStartTime;
        emit(
          state.copyWith(
            isScanning: false,
            scanLastDurationSecs: start == null
                ? null
                : DateTime.now().difference(start).inSeconds,
          ),
        );
        unawaited(_refreshWalletData());
      case SpNotification_ScanStopped():
        // Reload so lastScannedHeight reflects where the scan stopped; the next
        // scan resumes from there instead of restarting at the birthday.
        emit(state.copyWith(isScanning: false));
        unawaited(_refreshWalletData());
      case SpNotification_ScanFailed(:final message):
        emit(
          state.copyWith(
            isScanning: false,
            error: SpPresentationError(message),
          ),
        );
      case SpNotification_NewOutput():
      case SpNotification_OutputSpent():
      case SpNotification_ElectrumTx():
        // Defer per-coin refreshes during a scan to avoid churn; the
        // ScanCompleted case refreshes once when the scan ends.
        if (!state.isScanning) unawaited(_refreshWalletData());
      case SpNotification_BackendOffline():
        break;
    }
  }

  Future<void> _refreshWalletData() async {
    try {
      final data = await loadSpWalletDataUsecase.execute();
      if (isClosed) return;
      emit(
        state.copyWith(
          balance: data.wallet.balance,
          history: data.history,
          coins: data.coins,
          lastScannedHeight: data.wallet.lastScannedHeight,
          chainTip: data.chainTip,
        ),
      );
      // The wallet feature learns about this balance change independently, by
      // watching the SP repository's update stream (SpBalanceChanged) — SP
      // does not push to the wallet bloc.
    } catch (e) {
      log.warning('SpCubit._refreshWalletData: $e');
    }
  }

  Future<void> scan({int? startHeight}) async {
    try {
      if (isClosed) return;
      emit(state.copyWith(error: null));
      // scanOnce returns immediately (the one-shot scan runs on a background
      // thread); progress + the post-scan refresh are driven by notifications.
      await scanSpWalletUsecase.execute(startHeight: startHeight);
    } catch (e) {
      log.warning('SpCubit.scan: $e');
      if (isClosed) return;
      emit(
        state.copyWith(isScanning: false, error: SpPresentationError.from(e)),
      );
    }
  }

  Future<void> stopScan() async {
    // Returns after flipping the cancel flag; the scan tears down
    // asynchronously and emits ScanStopped/ScanCompleted, at which point
    // `_onNotification` clears `state.isScanning`.
    try {
      await stopSpScanUsecase.execute();
    } catch (e) {
      log.warning('SpCubit.stopScan: $e');
    }
  }

  void setReceiveTab(int index) {
    emit(state.copyWith(receiveTabIndex: index));
  }

  // Detects whether `input` is a silent payment address (sp1.../tsp1...) or
  // standard. Sets state.recipient; full checksum/format validation is deferred
  // to the Rust side in prepare(). We do one early UX check here: a silent
  // payment address whose network prefix doesn't match the wallet's network is
  // rejected up front (so the user isn't sent to the amount page only to fail
  // at prepare).
  void previewRecipient(String input) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) {
      emit(state.copyWith(recipient: null, error: null));
      return;
    }
    final lower = trimmed.toLowerCase();
    final isMainnetSp = lower.startsWith('sp1');
    final isTestSp = lower.startsWith('tsp1');
    final isSp = isMainnetSp || isTestSp;

    if (isSp) {
      final network = state.network;
      if (network != null) {
        final wantsMainnet = network == SpNetwork.bitcoin;
        if (wantsMainnet != isMainnetSp) {
          emit(
            state.copyWith(
              recipient: null,
              error: SpPresentationError(
                'This is a ${isMainnetSp ? 'mainnet' : 'test'} silent payment '
                'address, but your wallet is on '
                '${wantsMainnet ? 'mainnet' : 'a test network'}.',
              ),
            ),
          );
          return;
        }
      }
    }

    final recipient = isSp
        ? RecipientView.sp(
            address: trimmed,
            amountSat: state.amountSat ?? BigInt.zero,
            isMax: state.isMax,
          )
        : RecipientView.standard(
            address: trimmed,
            amountSat: state.amountSat ?? BigInt.zero,
            isMax: state.isMax,
          );
    emit(state.copyWith(recipient: recipient, error: null));
  }

  void setAmount(BigInt sats) {
    emit(state.copyWith(amountSat: sats));
  }

  /// Validates [sats] against the available balance and stores it. Emits an
  /// inline error and returns false when the amount is non-positive or exceeds
  /// the available balance, so the UI can block advancing. Rust `prepare()`
  /// remains the authority on fee-inclusive feasibility and coin selection.
  bool setValidatedAmount(BigInt sats) {
    if (sats <= BigInt.zero) {
      emit(
        state.copyWith(
          error: const SpPresentationError('Enter an amount greater than zero.'),
        ),
      );
      return false;
    }
    final available = state.balance?.totalUnifiedSat;
    if (available != null && sats > available) {
      emit(
        state.copyWith(
          error: const SpPresentationError(
            'Amount exceeds your available balance.',
          ),
        ),
      );
      return false;
    }
    emit(state.copyWith(amountSat: sats, error: null));
    return true;
  }

  void setFeerate(int feerate) {
    emit(state.copyWith(feerate: feerate));
  }

  /// Toggle send-max. When on, bwk drains all spendable coins on prepare and
  /// computes the amount (no manual amount needed).
  void setMax(bool isMax) {
    emit(state.copyWith(isMax: isMax, error: null));
  }

  Future<void> prepare() async {
    if (state.isLoading) return;
    final recipient = state.recipient;
    final amount = state.amountSat;
    // In max mode bwk computes the amount, so a manual amount is not required.
    if (recipient == null || (amount == null && !state.isMax)) {
      emit(
        state.copyWith(
          error: const SpPresentationError('Recipient and amount required'),
        ),
      );
      return;
    }
    try {
      emit(state.copyWith(isLoading: true, txSimulation: null, error: null));
      final recipientPrepared = _withAmount(
        recipient,
        amount ?? BigInt.zero,
        state.isMax,
      );
      final simulation = await prepareSpPaymentUsecase.execute(
        recipients: [recipientPrepared],
        feerateSatVb: BigInt.from(state.feerate),
      );
      if (isClosed) return;
      // Reflect the simulated output amount (the computed value when max).
      final outputAmount = simulation.outputs.isNotEmpty
          ? _amountOf(simulation.outputs.first)
          : amount;
      emit(
        state.copyWith(
          txSimulation: simulation,
          recipient: recipientPrepared,
          amountSat: outputAmount,
        ),
      );
    } catch (e) {
      log.warning('SpCubit.prepare: $e');
      if (isClosed) return;
      emit(state.copyWith(error: SpPresentationError.from(e)));
    } finally {
      if (!isClosed) emit(state.copyWith(isLoading: false));
    }
  }

  Future<void> signAndBroadcast() async {
    // Re-entrancy guard: the finalize -> sign -> broadcast sequence is
    // irreversible; a second concurrent invocation would produce a second
    // signed tx spending the same coins. Dedicated flag, not isLoading.
    if (state.isBroadcasting) return;
    final recipient = state.recipient;
    final amount = state.amountSat;
    final simulation = state.txSimulation;
    if (recipient == null || amount == null) {
      emit(
        state.copyWith(
          error: const SpPresentationError('Recipient and amount required'),
        ),
      );
      return;
    }
    // Confirm is only reachable after prepare() succeeded. A missing
    // simulation means the flow was driven outside the documented path —
    // refuse rather than rebuilding a tx the user never saw.
    if (simulation == null) {
      emit(
        state.copyWith(
          error: const SpPresentationError('Internal: missing simulation'),
        ),
      );
      return;
    }
    try {
      emit(
        state.copyWith(
          isBroadcasting: true,
          isLoading: true,
          txid: '',
          error: null,
        ),
      );
      // Pinned to the confirmed simulation; the use case (via the FFI) fails
      // loudly if the coin store drifted, so we never broadcast a tx whose
      // inputs differ from what was shown on the Confirm page. The txid is
      // logged inside the repository before returning so it survives even an
      // emit-after-close race.
      final txid = await sendSpPaymentUsecase.execute(simulation: simulation);
      if (isClosed) return;
      // Clear the send-flow inputs on success so a back-nav to the confirm
      // page can't re-enter signAndBroadcast against a stale simulation.
      emit(
        state.copyWith(
          txid: txid,
          recipient: null,
          amountSat: null,
          txSimulation: null,
          signedTx: [],
        ),
      );
      unawaited(_refreshWalletData());
    } catch (e) {
      log.warning('SpCubit.signAndBroadcast: $e');
      if (isClosed) return;
      emit(state.copyWith(error: SpPresentationError.from(e)));
    } finally {
      if (!isClosed) {
        emit(state.copyWith(isBroadcasting: false, isLoading: false));
      }
    }
  }

  RecipientView _withAmount(RecipientView recipient, BigInt amount, bool isMax) =>
      switch (recipient) {
        RecipientView_Sp(:final address, :final label) => RecipientView.sp(
          address: address,
          amountSat: amount,
          label: label,
          isMax: isMax,
        ),
        RecipientView_Standard(:final address) => RecipientView.standard(
          address: address,
          amountSat: amount,
          isMax: isMax,
        ),
      };

  BigInt _amountOf(RecipientView recipient) => switch (recipient) {
    RecipientView_Sp(:final amountSat) => amountSat,
    RecipientView_Standard(:final amountSat) => amountSat,
  };

  void resetSendFlow() {
    emit(
      state.copyWith(
        recipient: null,
        amountSat: null,
        isMax: false,
        txSimulation: null,
        signedTx: [],
        txid: '',
        error: null,
      ),
    );
  }

  Future<void> revokeWallet() async {
    // The usecase writes the `.revoked` sentinel and notifies observers even on
    // its dir-delete failure path, so the wallet is already unloadable. Swallow
    // any error here so the UI always navigates away instead of getting stuck.
    try {
      await revokeSpWalletUsecase.execute();
    } catch (e) {
      log.warning('SpCubit.revokeWallet: $e');
    }
  }

  void clearError() => emit(state.copyWith(error: null));

  @override
  Future<void> close() async {
    await _notificationSub?.cancel();
    return super.close();
  }
}
