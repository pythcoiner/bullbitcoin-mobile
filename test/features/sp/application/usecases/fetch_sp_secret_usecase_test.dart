import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/seed/domain/usecases/get_default_seed_usecase.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/application/usecases/fetch_sp_secret_usecase.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBip85Repository extends Mock implements Bip85Repository {}

class MockGetDefaultSeedUsecase extends Mock implements GetDefaultSeedUsecase {}

Bip85DerivationEntity _makeDerivation({
  required Bip85Status status,
  int index = SpConfig.bip85Index,
  Bip85Application application = Bip85Application.hex,
}) =>
    Bip85DerivationEntity(
      path: "m/83696968'/128169'/${SpConfig.bip85Length}'/$index'",
      xprvFingerprint: 'test',
      alias: null,
      status: status,
      application: application,
      index: index,
    );

void main() {
  late MockBip85Repository bip85Repo;
  late MockGetDefaultSeedUsecase getDefaultSeedUsecase;
  late FetchSpSecretUsecase usecase;

  setUp(() {
    bip85Repo = MockBip85Repository();
    getDefaultSeedUsecase = MockGetDefaultSeedUsecase();
    usecase = FetchSpSecretUsecase(
      bip85Repository: bip85Repo,
      getDefaultSeedUsecase: getDefaultSeedUsecase,
    );
  });

  group('FetchSpSecretUsecase', () {
    test('A: returns null when no active hex derivation at index 352', () async {
      when(() => bip85Repo.fetchAll()).thenAnswer(
        (_) async => const Ok<List<Bip85DerivationEntity>, Bip85Failure>([]),
      );

      final result = await usecase.execute();

      expect(result, isNull);
    });

    test('A: returns null when derivation exists but is inactive', () async {
      when(() => bip85Repo.fetchAll()).thenAnswer(
        (_) async => Ok<List<Bip85DerivationEntity>, Bip85Failure>([
          _makeDerivation(status: Bip85Status.inactive),
        ]),
      );

      final result = await usecase.execute();

      expect(result, isNull);
    });

    test('B: returns List<int> of length 64 when active derivation exists',
        () async {
      final mnemonic = Mnemonic.fromWords(
        words: List.generate(11, (_) => 'zoo') + ['wrong'],
      );
      final seed = Seed.bytes(
        bytes: Uint8List.fromList(mnemonic.seed),
        masterFingerprint: 'test',
      );

      when(() => bip85Repo.fetchAll()).thenAnswer(
        (_) async => Ok<List<Bip85DerivationEntity>, Bip85Failure>([
          _makeDerivation(status: Bip85Status.active),
        ]),
      );
      when(() => getDefaultSeedUsecase.execute()).thenAnswer((_) async => seed);

      final result = await usecase.execute();

      expect(result, isNotNull);
      expect(result!.length, equals(64));
    });
  });
}
