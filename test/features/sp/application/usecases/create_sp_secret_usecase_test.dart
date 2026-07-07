import 'dart:typed_data';

import 'package:bb_mobile/core/bip85/data/bip85_repository.dart';
import 'package:bb_mobile/core/bip85/domain/bip85_derivation_entity.dart';
import 'package:bb_mobile/core/bip85/domain/errors/bip85_failure.dart';
import 'package:bb_mobile/core/seed/domain/entity/seed.dart';
import 'package:bb_mobile/core/settings/data/settings_repository.dart';
import 'package:bb_mobile/core/settings/domain/settings_entity.dart';
import 'package:bb_mobile/core/utils/result.dart';
import 'package:bb_mobile/features/sp/application/usecases/create_sp_secret_usecase.dart';
import 'package:bb_mobile/features/sp/domain/domain_errors.dart';
import 'package:bb_mobile/features/sp/domain/sp_config.dart';
import 'package:bip39_mnemonic/bip39_mnemonic.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockBip85Repository extends Mock implements Bip85Repository {}

class MockSettingsRepository extends Mock implements SettingsRepository {}

SettingsEntity _makeSettings({
  bool? isSuperuser,
  bool? isDevModeEnabled = true,
}) =>
    const SettingsEntity(
      environment: Environment.mainnet,
      bitcoinUnit: BitcoinUnit.sats,
      currencyCode: 'CAD',
      isSuperuser: null,
    ).copyWith(
      isSuperuser: isSuperuser,
      isDevModeEnabled: isDevModeEnabled,
    );

Bip85DerivationEntity _makeDerivation({
  required Bip85Status status,
  int index = SpConfig.bip85Index,
}) =>
    Bip85DerivationEntity(
      path: "m/83696968'/128169'/${SpConfig.bip85Length}'/$index'",
      xprvFingerprint: 'test',
      alias: null,
      status: status,
      application: Bip85Application.hex,
      index: index,
    );

void main() {
  late MockBip85Repository bip85Repo;
  late MockSettingsRepository settingsRepo;
  late CreateSpSecretUsecase usecase;
  late Seed testSeed;

  setUp(() {
    bip85Repo = MockBip85Repository();
    settingsRepo = MockSettingsRepository();
    usecase = CreateSpSecretUsecase(
      bip85Repository: bip85Repo,
      settingsRepository: settingsRepo,
    );

    final mnemonic = Mnemonic.fromWords(
      words: List.generate(11, (_) => 'zoo') + ['wrong'],
    );
    testSeed = Seed.bytes(
      bytes: Uint8List.fromList(mnemonic.seed),
      masterFingerprint: 'test',
    );
  });

  group('CreateSpSecretUsecase', () {
    test('A: throws SpRequiresSuperuserError when isSuperuser is not true',
        () async {
      when(() => settingsRepo.fetch())
          .thenAnswer((_) async => _makeSettings(isSuperuser: false));

      expect(
        () => usecase.execute(defaultSeed: testSeed),
        throwsA(isA<SpRequiresSuperuserError>()),
      );
    });

    test(
        'A2: throws SpRequiresDevModeError when isSuperuser=true but isDevModeEnabled=false',
        () async {
      when(() => settingsRepo.fetch()).thenAnswer(
        (_) async => _makeSettings(isSuperuser: true, isDevModeEnabled: false),
      );

      expect(
        () => usecase.execute(defaultSeed: testSeed),
        throwsA(isA<SpRequiresDevModeError>()),
      );
    });

    test('B: throws SpDerivationAlreadyExistsError when active derivation exists',
        () async {
      when(() => settingsRepo.fetch())
          .thenAnswer((_) async => _makeSettings(isSuperuser: true));
      when(() => bip85Repo.fetchAll()).thenAnswer(
        (_) async => Ok<List<Bip85DerivationEntity>, Bip85Failure>([
          _makeDerivation(status: Bip85Status.active),
        ]),
      );

      expect(
        () => usecase.execute(defaultSeed: testSeed),
        throwsA(isA<SpDerivationAlreadyExistsError>()),
      );
    });

    test('C: reactivates revoked derivation and returns (derivation, hex)',
        () async {
      final revoked = _makeDerivation(status: Bip85Status.revoked);
      when(() => settingsRepo.fetch())
          .thenAnswer((_) async => _makeSettings(isSuperuser: true));
      when(() => bip85Repo.fetchAll()).thenAnswer(
        (_) async => Ok<List<Bip85DerivationEntity>, Bip85Failure>([revoked]),
      );
      when(() => bip85Repo.activate(revoked)).thenAnswer(
        (_) async => const Ok<void, Bip85Failure>(null),
      );

      final result = await usecase.execute(defaultSeed: testSeed);

      verify(() => bip85Repo.activate(revoked)).called(1);
      expect(result.derivation, equals(revoked.path));
      expect(result.hex, isNotEmpty);
      expect(result.hex.length, equals(128)); // 64 bytes = 128 hex chars
    });

    test('D: no existing derivation — calls deriveHex with length 64 and index 352',
        () async {
      const expectedDerivation = "m/test'";
      final expectedHex = 'aabbccdd' * 16;
      when(() => settingsRepo.fetch())
          .thenAnswer((_) async => _makeSettings(isSuperuser: true));
      when(() => bip85Repo.fetchAll()).thenAnswer(
        (_) async => const Ok<List<Bip85DerivationEntity>, Bip85Failure>([]),
      );
      when(
        () => bip85Repo.deriveHex(
          xprvBase58: any(named: 'xprvBase58'),
          length: SpConfig.bip85Length,
          index: SpConfig.bip85Index,
        ),
      ).thenAnswer(
        (_) async => Ok<({String derivation, String hex}), Bip85Failure>(
          (derivation: expectedDerivation, hex: expectedHex),
        ),
      );

      final result = await usecase.execute(defaultSeed: testSeed);

      verify(
        () => bip85Repo.deriveHex(
          xprvBase58: any(named: 'xprvBase58'),
          length: SpConfig.bip85Length,
          index: SpConfig.bip85Index,
        ),
      ).called(1);
      expect(result.derivation, equals(expectedDerivation));
      expect(result.hex, equals(expectedHex));
    });
  });
}
