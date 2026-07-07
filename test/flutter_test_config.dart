import 'dart:async';
import 'dart:io';

/// Auto-loaded by `flutter test`. Runs once per test binary process,
/// before any test in `test/` executes.
///
/// SP cubit tests intentionally exercise error paths (e.g.
/// `SpCubit.prepare: insufficient funds`, `SpCubit.load: wallet error`)
/// which the global logger appends to `bull_logs.tsv`. The file is
/// gitignored so it never enters commits, but without truncation it
/// keeps growing locally across test runs. Truncating once per run
/// keeps the dev tree predictable.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final logFile = File('bull_logs.tsv');
  try {
    if (logFile.existsSync()) {
      logFile.writeAsStringSync('');
    }
  } catch (_) {
    // Ignore truncate failures — the test run shouldn't be blocked by a
    // log-file housekeeping problem.
  }
  await testMain();
}
