import 'package:bull_sdk/bwk.dart';

/// Result of testing one backend URL: ok, or a human-readable error.
enum SpConnTest { untested, testing, ok, failed }

/// Validates a blindbit / electrum URL by actually connecting (standalone, no
/// live SP session). Returns null on success or an error message. The bwk free
/// functions are injectable so the usecase can be unit-tested.
class TestSpBackendUsecase {
  final Future<int> Function({required String url}) _testBlindbit;
  final Future<void> Function({required String url}) _testElectrum;

  TestSpBackendUsecase({
    Future<int> Function({required String url})? testBlindbit,
    Future<void> Function({required String url})? testElectrum,
  }) : _testBlindbit = testBlindbit ?? testBlindbitUrl,
       _testElectrum = testElectrum ?? testElectrumUrl;

  Future<String?> testBlindbit(String url) async {
    try {
      await _testBlindbit(url: url);
      return null;
    } catch (e) {
      return e.toString();
    }
  }

  Future<String?> testElectrum(String url) async {
    try {
      await _testElectrum(url: url);
      return null;
    } catch (e) {
      return e.toString();
    }
  }
}
