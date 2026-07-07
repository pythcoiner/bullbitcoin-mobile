import 'package:bb_mobile/features/sp/domain/sp_notif_log.dart';
import 'package:bull_sdk/bwk.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('formatSpNotification', () {
    test('scan lifecycle variants', () {
      expect(
        formatSpNotification(const SpNotification.scanStarted(from: 1, to: 9)),
        'ScanStarted 1 -> 9',
      );
      expect(
        formatSpNotification(
          const SpNotification.scanReceiveProgress(current: 5, end: 9),
        ),
        'ScanReceiveProgress 5 / 9',
      );
      expect(
        formatSpNotification(
          const SpNotification.scanSpendProgress(current: 3, end: 9),
        ),
        'ScanSpendProgress 3 / 9',
      );
      expect(
        formatSpNotification(const SpNotification.scanCompleted()),
        'ScanCompleted',
      );
      expect(
        formatSpNotification(const SpNotification.scanStopped()),
        'ScanStopped',
      );
      expect(
        formatSpNotification(const SpNotification.scanFailed(message: 'boom')),
        'ScanFailed: boom',
      );
    });

    test('coin variants', () {
      expect(
        formatSpNotification(
          SpNotification.newOutput(outpoint: 'ab:0', amountSat: BigInt.from(1000)),
        ),
        'NewOutput ab:0 1000sat',
      );
      expect(
        formatSpNotification(const SpNotification.outputSpent(outpoint: 'ab:0')),
        'OutputSpent ab:0',
      );
      expect(
        formatSpNotification(const SpNotification.backendOffline()),
        'BackendOffline',
      );
    });

    test('electrum tx shows kind, txid, amount and height', () {
      expect(
        formatSpNotification(
          SpNotification.electrumTx(
            kind: CoinSource.taproot,
            txid: 'deadbeef',
            amountSat: BigInt.from(2500),
            height: 210,
          ),
        ),
        'ElectrumTx taproot deadbeef 2500sat @210',
      );
      expect(
        formatSpNotification(
          SpNotification.electrumTx(
            kind: CoinSource.segwit,
            txid: 'cafe',
            amountSat: BigInt.from(1),
          ),
        ),
        'ElectrumTx segwit cafe 1sat',
      );
    });
  });
}
