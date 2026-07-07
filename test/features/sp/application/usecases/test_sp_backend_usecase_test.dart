import 'package:bb_mobile/features/sp/application/usecases/test_sp_backend_usecase.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TestSpBackendUsecase', () {
    test('testBlindbit returns null on success', () async {
      final usecase = TestSpBackendUsecase(
        testBlindbit: ({required String url}) async => 42,
        testElectrum: ({required String url}) async {},
      );
      expect(await usecase.testBlindbit('http://ok'), isNull);
    });

    test('testBlindbit returns the error message on failure', () async {
      final usecase = TestSpBackendUsecase(
        testBlindbit: ({required String url}) async => throw Exception('boom'),
        testElectrum: ({required String url}) async {},
      );
      final err = await usecase.testBlindbit('http://bad');
      expect(err, contains('boom'));
    });

    test('testElectrum returns null on success', () async {
      final usecase = TestSpBackendUsecase(
        testBlindbit: ({required String url}) async => 0,
        testElectrum: ({required String url}) async {},
      );
      expect(await usecase.testElectrum('tcp://ok:1'), isNull);
    });

    test('testElectrum returns the error message on failure', () async {
      final usecase = TestSpBackendUsecase(
        testBlindbit: ({required String url}) async => 0,
        testElectrum: ({required String url}) async => throw Exception('no route'),
      );
      final err = await usecase.testElectrum('tcp://bad:1');
      expect(err, contains('no route'));
    });
  });
}
