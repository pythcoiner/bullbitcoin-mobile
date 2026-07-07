import 'dart:async';
import 'dart:io';

import 'package:bb_mobile/core/utils/logger.dart';
import 'package:bb_mobile/features/sp/application/ports/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/domain/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bb_mobile/features/sp/domain/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/domain/sp_update.dart';
import 'package:bb_mobile/features/sp/domain/sp_wallet.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:path_provider/path_provider.dart';

/// Secondary (driven) adapter that owns the single live `SpAccount` FFI
/// session and implements [SpAccountRepository].
///
/// Registered as a `lazySingleton`, so there is exactly one owner of the live
/// session per app lifetime / data dir. This absorbs what used to be split
/// across `SpWalletEntity` (notification stream + dispose retry/memo),
/// `GetSpWalletUsecase` (sentinel/db checks + `SpAccount.load`), the setup
/// cubit (`SpAccount.createFromKeys`), and the SP cubit (send-flow FFI calls).
class BwkSpAccountRepository implements SpAccountRepository {
  SpAccount? _account;

  // Notification stream plumbing (single-take Rust receiver -> broadcast).
  Stream<SpNotification>? _notifications;
  StreamSubscription<SpNotification>? _sourceSub;
  StreamController<SpNotification>? _broadcastController;
  bool _notifTornDown = false;
  Future<void>? _pendingDispose;

  // Always-on stream of pure cross-feature update signals (balance changes,
  // setup created/revoked). Independent of the session lifecycle; never
  // closed (this adapter is a lazySingleton living for the app's lifetime).
  final StreamController<SpUpdate> _updates =
      StreamController<SpUpdate>.broadcast();

  void _emit(SpUpdate update) {
    if (!_updates.isClosed) _updates.add(update);
  }

  // Scanning flag tracked from notifications (no FFI), so reads/dispose can be
  // skipped while a scan holds the inner lock and would block the UI isolate.
  bool _scanning = false;

  // Debug console: bounded notification log + a live broadcast of new lines.
  // Never cleared on session recycle; the controller lives for the app.
  static const int _notifLogCap = 200;
  final List<SpNotifLogLine> _notifLog = [];
  final StreamController<SpNotifLogLine> _notifLogController =
      StreamController<SpNotifLogLine>.broadcast();

  Future<String> get _dataDir async {
    final appDocsDir = await getApplicationDocumentsDirectory();
    return appDocsDir.path;
  }

  SpAccount get _live {
    final account = _account;
    if (account == null) {
      throw StateError('SpAccountRepository: no live SP session');
    }
    return account;
  }

  @override
  bool get hasSession => _account != null;

  @override
  Future<void> createFromMnemonic({
    required SpNetwork network,
    required String mnemonic,
    required String blindbitUrl,
    required String electrumUrl,
  }) async {
    final dataDir = await _dataDir;
    _resetNotificationState();
    _scanning = false;
    // Clear any lingering advisory lock. On mobile (single process) a present
    // lock is a disposed session whose Rust handle is not GC'd yet, so it can
    // never be a real second owner; the in-app single-establishment guard
    // (EnsureSpSessionUsecase) keeps two live sessions from ever racing.
    final lock = File('$dataDir/${SpConfig.accountName}/${SpConfig.lockFile}');
    if (lock.existsSync()) {
      try {
        lock.deleteSync();
      } catch (e) {
        log.warning('SpAccountRepository: stale lock delete failed: $e');
      }
    }
    final account = SpAccount.createFromMnemonic(
      name: SpConfig.accountName,
      network: network,
      mnemonic: mnemonic,
      blindbitUrl: blindbitUrl,
      electrumUrl: electrumUrl,
      dataDir: dataDir,
    );
    _account = account;
    // Start the always-on taproot sub-account electrum listener so incoming txs
    // are pushed without a manual scan. createFromMnemonic does not propagate the
    // electrum URL into the sub-account, so set it first (mirrors the silent
    // wallet). Failures here must not abort session setup.
    if (electrumUrl.isNotEmpty) {
      try {
        account.setElectrumUrl(url: electrumUrl);
        // Fire-and-forget: starting the listener must never block (or hang)
        // session establishment. Errors are logged, not fatal.
        unawaited(
          account.startElectrum().catchError((Object e) {
            log.warning('SpAccountRepository: start electrum failed: $e');
          }),
        );
      } catch (e) {
        log.warning('SpAccountRepository: set electrum url failed: $e');
      }
    }
    // Prime the notification listener now (single init() per session) so every
    // Rust notification is recorded as soon as the session exists, regardless
    // of whether the UI has subscribed yet.
    _ensureNotifications();
    // Setup just completed — observers (the wallet) must re-evaluate and load.
    _emit(const SpSetupChanged());
  }

  // --- snapshot reads ---

  @override
  SpWallet snapshot() {
    final account = _live;
    return SpWallet(
      spAddress: account.spAddress(),
      balance: SpBalance.fromView(account.unifiedBalance()),
      isScanning: account.isScanning(),
      lastScannedHeight: account.lastScannedHeight(),
    );
  }

  @override
  Future<String> generateTaprootAddress() => _live.newTaprootAddress();

  @override
  SpBalance balance() => SpBalance.fromView(_live.unifiedBalance());

  @override
  bool get isScanning => _live.isScanning();

  @override
  int? get lastScannedHeight => _live.lastScannedHeight();

  @override
  bool get isScanningCached => _scanning;

  @override
  Future<List<SpPaymentView>> history() => _live.unifiedHistory();

  @override
  Future<List<UnifiedCoinView>> coins() => _live.unifiedCoins();

  // --- scan (USER-TRIGGERED ONLY) ---
  // This is the single Dart call site of `scanOnce`; it is reached only via
  // `ScanSpWalletUsecase`. Do not add other callers — the no-auto-scan
  // invariant depends on it.

  @override
  Future<void> scanOnce({int? startHeight}) {
    // Set scanning synchronously, before the FFI call returns, so the
    // WalletBloc's isSpScanning gate has no blind window between scan_once
    // returning (it spawns a background thread) and the first ScanStarted
    // notification. Cleared on the terminal notification in _recordNotification.
    _scanning = true;
    try {
      return _live.scanOnce(startHeight: startHeight);
    } catch (_) {
      _scanning = false;
      rethrow;
    }
  }

  @override
  Future<void> stopScan() => _live.stopScan();

  @override
  Future<void> restartElectrum() async {
    final account = _account;
    if (account == null) return;
    await account.restartElectrum();
  }

  @override
  int minBirthdayHeight() => _live.minBirthdayHeight();

  // --- send orchestration ---

  @override
  Future<TxSimulation> preparePsbt({
    required List<RecipientView> recipients,
    required BigInt feerateSatVb,
  }) => _live.preparePsbt(recipients: recipients, feerateSatVb: feerateSatVb);

  @override
  Future<String> finalizeSignBroadcast({
    required TxSimulation simulation,
  }) async {
    final account = _live;
    // The Rust side pins inputs+outputs to the confirmed simulation and fails
    // loudly if the coin store drifted, so we never broadcast a tx whose
    // inputs differ from what was shown on the Confirm page.
    final psbtBytes = await account.finalizePsbt(simulation: simulation);
    final signedBytes = await account.signPsbt(psbt: psbtBytes);
    final txHex = signedBytes
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    // changeSat lets bwk net the SP change into the unconfirmed send amount so
    // history shows sent + fee before the change is scanned back in.
    final txid = await account.broadcast(
      txHex: txHex,
      changeSat: simulation.changeSat,
    );
    // The tx is now irreversible. Log the txid before returning so it always
    // survives in the device log even if the caller was torn down mid-await.
    log.info('SpAccountRepository: broadcast succeeded txid=$txid');
    return txid;
  }

  // --- info (tolerant) ---

  @override
  SpNetwork? network() {
    try {
      return _live.network();
    } catch (e) {
      log.warning('SpAccountRepository.network: $e');
      return null;
    }
  }

  @override
  bool backendOnline() {
    try {
      return _live.backendOnline();
    } catch (e) {
      log.warning('SpAccountRepository.backendOnline: $e');
      return false;
    }
  }

  @override
  int? chainTip() {
    try {
      return _live.blockHeight();
    } catch (e) {
      log.warning('SpAccountRepository.chainTip: $e');
      return null;
    }
  }

  // --- notifications ---

  @override
  Stream<SpNotification> get notifications => _ensureNotifications();

  // Set up the Rust notification forwarding (init) + source listener exactly
  // once per session. Called from createFromKeys so recording (and electrum
  // pushes) flow as soon as a session exists, independent of any UI subscriber;
  // `init()` is taken-once per account, so doing it here avoids the double-init
  // ("receiver already taken") that broke recording.
  Stream<SpNotification> _ensureNotifications() {
    final existing = _notifications;
    if (existing != null) return existing;

    final source = _live.init();
    final controller = StreamController<SpNotification>.broadcast();
    _broadcastController = controller;
    _notifTornDown = false;
    _sourceSub = source.listen(
      (n) {
        _recordNotification(n);
        controller.add(n);
        _maybeEmitBalanceChange(n);
      },
      onError: controller.addError,
      onDone: () {
        if (!controller.isClosed) unawaited(controller.close());
      },
    );
    _notifications = controller.stream;
    return _notifications!;
  }

  // Forward coin-affecting notifications to the cross-feature update stream as
  // a lightweight balance signal (no session reload). Scan progress/start are
  // ignored — only events that change the coin set move the balance.
  void _maybeEmitBalanceChange(SpNotification n) {
    final affectsBalance =
        n is SpNotification_NewOutput ||
        n is SpNotification_OutputSpent ||
        n is SpNotification_ElectrumTx ||
        n is SpNotification_ScanCompleted;
    if (!affectsBalance) return;
    // Skip the per-event balance read during a scan to avoid churn; the
    // ScanCompleted event reconciles the balance once the scan ends.
    if (_scanning) return;
    try {
      _emit(SpBalanceChanged(balance().confirmedSat));
    } on StateError catch (_) {
      // No live session — expected during teardown; not an error worth a
      // warning (a real FFI failure is a different type, handled below).
      log.fine('SpAccountRepository: balance read skipped (no session)');
    } catch (e) {
      log.warning('SpAccountRepository: balance read on notification failed: $e');
    }
  }

  // Track scanning (no FFI) and append to the debug console log. Runs for every
  // notification the single source emits, before fan-out. The one-shot scan
  // runs on a background thread (returns immediately), so the scanning window is
  // ScanStarted..ScanCompleted, which gates WalletBloc from disposing mid-scan.
  void _recordNotification(SpNotification n) {
    if (n is SpNotification_ScanStarted) {
      _scanning = true;
    } else if (n is SpNotification_ScanCompleted ||
        n is SpNotification_ScanStopped ||
        n is SpNotification_ScanFailed) {
      _scanning = false;
    }
    final line = SpNotifLogLine(
      time: DateTime.now(),
      text: formatSpNotification(n),
    );
    _notifLog.add(line);
    if (_notifLog.length > _notifLogCap) _notifLog.removeAt(0);
    if (!_notifLogController.isClosed) _notifLogController.add(line);
  }

  @override
  List<SpNotifLogLine> get notificationLog => List.unmodifiable(_notifLog);

  @override
  Stream<SpNotifLogLine> get notificationLogStream =>
      _notifLogController.stream;

  @override
  Stream<SpUpdate> get updates => _updates.stream;

  @override
  void notifySetupChanged() => _emit(const SpSetupChanged());

  // --- dispose ---

  @override
  Future<void> dispose() async {
    if (_account == null) return;
    final pending = _pendingDispose;
    if (pending != null) return pending;
    final future = _runDispose();
    _pendingDispose = future;
    try {
      await future;
    } finally {
      _pendingDispose = null;
    }
  }

  Future<void> _runDispose() async {
    final account = _account;
    try {
      // Tear down the Rust session FIRST. This flips the notif-thread shutdown
      // flag, stops the electrum listener, and releases the sqlite handle/.lock.
      // It MUST happen before cancelling the Dart notification subscription:
      // cancelling an FRB stream subscription while the Rust notif thread is
      // still actively producing (electrum flood) deadlocks, which previously
      // wedged the whole revoke/delete flow. Rethrows "dispose timed out" if the
      // inner lock is still held; only drop the reference after a clean dispose.
      if (account != null) {
        await account.dispose();
        _account = null;
        _notifications = null;
      }
    } finally {
      // Best-effort Dart-stream cleanup. NOT awaited: the session is already
      // torn down (its source is done), and cancel/close must never be allowed
      // to block dispose() and stall revoke.
      if (!_notifTornDown) {
        _notifTornDown = true;
        final sub = _sourceSub;
        _sourceSub = null;
        if (sub != null) {
          unawaited(
            sub.cancel().catchError((Object e) {
              log.warning('SpAccountRepository.dispose: source cancel failed: $e');
            }),
          );
        }
        final controller = _broadcastController;
        _broadcastController = null;
        if (controller != null && !controller.isClosed) {
          unawaited(
            controller.close().catchError((Object e) {
              log.warning('SpAccountRepository.dispose: controller close failed: $e');
            }),
          );
        }
      }
    }
  }

  void _resetNotificationState() {
    _notifications = null;
    _sourceSub = null;
    _broadcastController = null;
    _notifTornDown = false;
  }
}
