import 'package:bb_mobile/features/sp/domain/sp_balance.dart';
import 'package:bb_mobile/features/sp/domain/sp_notif_log.dart';
import 'package:bb_mobile/features/sp/domain/sp_update.dart';
import 'package:bb_mobile/features/sp/domain/sp_wallet.dart';
import 'package:bull_sdk/bwk.dart';

/// Outbound port over the Silent Payments Rust FFI (`SpAccount`).
///
/// The application layer depends on this interface; the concrete
/// `BwkSpAccountRepository` adapter owns the single live FFI session
/// (notification stream + dispose lifecycle + sqlite handle) per data dir.
/// Nothing above the application layer touches `SpAccount` directly.
///
/// FRB view types (`SpPaymentView`, `UnifiedCoinView`, `TxSimulation`,
/// `RecipientView`, `SpNotification`, `SpNetwork`) are passed through
/// deliberately (no over-mapping): `TxSimulation` MUST round-trip unchanged
/// into finalize (the pin invariant), and the View structs are read-only with
/// no business rules to enforce. Domain types are produced only where a rule
/// lives (`SpWallet`, `SpBalance`).
abstract class SpAccountRepository {
  // --- session lifecycle (owns the single live SpAccount) ---

  /// Create an account from derived keys, reusing any existing on-disk sqlite
  /// stores. Establishes the live session. Used both for first-time setup and
  /// to reconstruct the session on load (see `EnsureSpSessionUsecase`).
  Future<void> createFromMnemonic({
    required SpNetwork network,
    required String mnemonic,
    required String blindbitUrl,
    required String electrumUrl,
  });

  /// Tear down the live session: cancel the notification stream, join the
  /// Rust thread, drop the sqlite handle. Idempotent; rethrows a timeout
  /// error if the inner lock is still held so callers can decline to reopen.
  Future<void> dispose();

  bool get hasSession;

  // --- snapshot reads (sync FFI) ---

  /// Current snapshot (SP address + balance + scan state). Throws if no
  /// session is established.
  SpWallet snapshot();
  SpBalance balance();
  bool get isScanning;
  int? get lastScannedHeight;

  /// Whether a scan is running, tracked in Dart from notifications (no FFI), so
  /// callers can skip blocking reads while the scan holds the inner lock.
  bool get isScanningCached;

  // --- receive address (USER-TRIGGERED reveal) ---

  /// Reveal a fresh taproot receive address to hand out. Each call derives the
  /// next never-before-issued address (advances + persists the receive tip);
  /// it must NEVER re-hand a previously revealed address. Call only on an
  /// explicit user "generate" action — not on every screen load.
  Future<String> generateTaprootAddress();

  // --- async reads ---

  Future<List<SpPaymentView>> history();
  Future<List<UnifiedCoinView>> coins();

  // --- scan (USER-TRIGGERED ONLY) ---

  /// The single Dart entry point to the Rust scan. Reached only via
  /// `ScanSpWalletUsecase`. `startHeight` overrides where the scan begins
  /// (null resumes from the last scanned position).
  Future<void> scanOnce({int? startHeight});
  Future<void> stopScan();

  /// Restart the taproot electrum listener in place (reconnect + re-subscribe +
  /// re-sync). Used on app foreground to recover after Android killed the
  /// backgrounded socket. No-op when there is no live session.
  Future<void> restartElectrum();

  /// Earliest height a scan may start from (taproot activation on mainnet, a
  /// low value on test networks). The scan start chooser uses it as its floor.
  int minBirthdayHeight();

  // --- send orchestration ---

  Future<TxSimulation> preparePsbt({
    required List<RecipientView> recipients,
    required BigInt feerateSatVb,
  });

  /// finalize → sign → broadcast as one irreversible, simulation-pinned step.
  /// Returns the broadcast txid.
  Future<String> finalizeSignBroadcast({required TxSimulation simulation});

  // --- info (tolerant: null/false on FRB Err) ---

  SpNetwork? network();
  bool backendOnline();

  /// Current chain tip height, or null on FRB Err / no session.
  int? chainTip();

  // --- notifications (broadcast view of the single-take receiver) ---

  Stream<SpNotification> get notifications;

  // --- notification debug log (for the SP settings console) ---

  /// Buffered notifications (oldest first), capped; survives session recycles.
  List<SpNotifLogLine> get notificationLog;

  /// Live stream of new notification log lines.
  Stream<SpNotifLogLine> get notificationLogStream;

  // --- cross-feature update signals (pure domain events) ---

  /// Materially-changed events (balance changes, setup created/revoked) that
  /// other features observe without depending on SP internals. Always-on
  /// (independent of whether a session is established).
  Stream<SpUpdate> get updates;

  /// Emit a [SpSetupChanged] on [updates]. Called by the revoke use case after
  /// it tears the wallet down, so observers (the wallet home) re-evaluate setup
  /// state. `createFromKeys` emits the same event internally on setup.
  void notifySetupChanged();
}
