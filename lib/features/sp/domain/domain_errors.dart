/// Domain-layer errors for the Silent Payments feature.
///
/// These represent SP business-rule violations (gating, lifecycle state).
/// The application layer maps these to its own error types at the boundary;
/// see `application/application_errors.dart`.
sealed class SpDomainError implements Exception {
  const SpDomainError(this.message);
  final String message;

  @override
  String toString() => message;
}

class SpDerivationAlreadyExistsError extends SpDomainError {
  const SpDerivationAlreadyExistsError()
    : super('SP bip85 derivation already exists');
}

class SpDerivationNotFoundError extends SpDomainError {
  const SpDerivationNotFoundError() : super('SP bip85 derivation not found');
}

class SpWalletNotInitializedError extends SpDomainError {
  const SpWalletNotInitializedError() : super('SP wallet is not initialized');
}

class SpRequiresSuperuserError extends SpDomainError {
  const SpRequiresSuperuserError()
    : super('SP requires superuser to be enabled');
}

class SpRequiresDevModeError extends SpDomainError {
  const SpRequiresDevModeError() : super('SP requires dev mode to be enabled');
}

class SpScanInProgressError extends SpDomainError {
  const SpScanInProgressError() : super('SP scan is already in progress');
}
