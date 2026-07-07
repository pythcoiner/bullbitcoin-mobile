import 'package:bb_mobile/features/sp/application/ports/sp_account_repository.dart';
import 'package:bull_sdk/bwk.dart';

/// Exposes the SP notification stream (scan progress, electrum pushes, etc.)
/// to the presentation layer through the application boundary, rather than
/// letting the cubit reach into the repository's stream directly.
class WatchSpNotificationsUsecase {
  final SpAccountRepository _repository;

  WatchSpNotificationsUsecase({required this._repository});

  Stream<SpNotification> execute() => _repository.notifications;
}
