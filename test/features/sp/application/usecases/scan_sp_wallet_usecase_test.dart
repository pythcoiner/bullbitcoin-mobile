import 'package:bb_mobile/features/sp/application/ports/sp_account_repository.dart';
import 'package:bb_mobile/features/sp/application/usecases/scan_sp_wallet_usecase.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockSpAccountRepository extends Mock implements SpAccountRepository {}

void main() {
  late MockSpAccountRepository repository;
  late ScanSpWalletUsecase usecase;

  setUp(() {
    repository = MockSpAccountRepository();
    usecase = ScanSpWalletUsecase(repository: repository);
  });

  group('ScanSpWalletUsecase', () {
    test('A: calls scanOnce exactly once on the repository', () async {
      when(() => repository.scanOnce()).thenAnswer((_) async {});

      await usecase.execute();

      verify(() => repository.scanOnce()).called(1);
    });

    test('B: each execute() delegates to scanOnce (idempotent pass-through)',
        () async {
      when(() => repository.scanOnce()).thenAnswer((_) async {});

      await usecase.execute();
      await usecase.execute();

      // Two calls => two delegations, one-to-one. The use case adds no
      // dedup/throttle of its own; it is a thin pass-through.
      verify(() => repository.scanOnce()).called(2);
    });

    test('C: rethrows the exact error thrown by scanOnce', () async {
      final scanError = StateError('scan backend offline');
      when(() => repository.scanOnce()).thenAnswer((_) async => throw scanError);

      // The same instance must propagate unchanged (no wrapping/swallowing).
      await expectLater(
        usecase.execute(),
        throwsA(same(scanError)),
      );

      verify(() => repository.scanOnce()).called(1);
    });

    test('D: does not touch any repository method other than scanOnce',
        () async {
      when(() => repository.scanOnce()).thenAnswer((_) async {});

      await usecase.execute();

      verify(() => repository.scanOnce()).called(1);
      // The scan entry point must never stop a scan or tear down the session.
      verifyNever(() => repository.stopScan());
      verifyNever(() => repository.dispose());
      verifyNoMoreInteractions(repository);
    });

    test('E: forwards a chosen start height to scanOnce', () async {
      when(
        () => repository.scanOnce(startHeight: any(named: 'startHeight')),
      ).thenAnswer((_) async {});

      await usecase.execute(startHeight: 800000);

      verify(() => repository.scanOnce(startHeight: 800000)).called(1);
    });
  });
}
