import 'package:bb_mobile/features/sp/application/application_errors.dart';
import 'package:bb_mobile/features/sp/domain/domain_errors.dart';

/// Presentation-layer error for the Silent Payments feature.
///
/// The cubit maps lower-layer errors (and raw exceptions surfaced from the
/// FFI through use cases) into this user-facing type so the UI never depends
/// on application/domain/FFI error types. Exposes `message` + `toString` so
/// existing UI selectors (`state.error?.message`) keep working.
class SpPresentationError implements Exception {
  const SpPresentationError(this.message);
  final String message;

  @override
  String toString() => message;

  /// Map any lower-layer error or raw exception to a user-facing message.
  factory SpPresentationError.from(Object e) {
    if (e is SpPresentationError) return e;
    if (e is SpApplicationError) return SpPresentationError(e.message);
    if (e is SpDomainError) return SpPresentationError(e.message);
    return SpPresentationError(e.toString());
  }
}
