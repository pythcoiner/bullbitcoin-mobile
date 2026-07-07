import 'package:bb_mobile/features/sp/domain/domain_errors.dart';

/// Application-layer errors for the Silent Payments feature.
///
/// Use cases catch lower-layer errors (domain rule violations, FFI failures)
/// and map them here so callers never see a foreign layer's error type.
sealed class SpApplicationError implements Exception {
  const SpApplicationError(this.message);
  final String message;

  @override
  String toString() => message;

  /// Map a domain rule error into its application-layer counterpart.
  static SpApplicationError fromDomainError(SpDomainError e) =>
      switch (e) {
        SpRequiresSuperuserError() ||
        SpRequiresDevModeError() => SpNotAvailableError(e.message),
        SpDerivationAlreadyExistsError() => SpAlreadySetUpError(e.message),
        SpDerivationNotFoundError() ||
        SpWalletNotInitializedError() => SpNotSetUpError(e.message),
        SpScanInProgressError() => SpScanBusyError(e.message),
      };

  /// Map an arbitrary FFI/infra failure into an application error, preserving
  /// the recognisable "inputs changed" / "dispose timed out" signals.
  static SpApplicationError fromFfiError(Object e) {
    final s = e.toString();
    if (s.contains('inputs changed')) return SpSimulationDriftedError(s);
    if (s.contains('dispose timed out')) return SpSessionBusyError(s);
    return SpUnknownError(s);
  }
}

class SpNotAvailableError extends SpApplicationError {
  const SpNotAvailableError(super.message);
}

class SpNotSetUpError extends SpApplicationError {
  const SpNotSetUpError(super.message);
}

class SpAlreadySetUpError extends SpApplicationError {
  const SpAlreadySetUpError(super.message);
}

class SpScanBusyError extends SpApplicationError {
  const SpScanBusyError(super.message);
}

class SpSimulationDriftedError extends SpApplicationError {
  const SpSimulationDriftedError(super.message);
}

class SpSessionBusyError extends SpApplicationError {
  const SpSessionBusyError(super.message);
}

class SpSetupCleanupFailedError extends SpApplicationError {
  const SpSetupCleanupFailedError(super.message);
}

class SpSetupRequiresMnemonicError extends SpApplicationError {
  const SpSetupRequiresMnemonicError(super.message);
}

class SpUnknownError extends SpApplicationError {
  const SpUnknownError(super.message);
}
