import 'package:sesori_bridge/src/api/wake_lock_client.dart';
import 'package:sesori_bridge/src/repositories/wake_lock_repository.dart';
import 'package:test/test.dart';

class _FakeWakeLockClient implements WakeLockClient {
  int enableCalls = 0;
  int disableCalls = 0;

  @override
  Future<void> enable() async {
    enableCalls += 1;
  }

  @override
  Future<void> disable() async {
    disableCalls += 1;
  }

  @override
  bool get preventsLidCloseSleep => true;
}

void main() {
  group('WakeLockRepository', () {
    test('tracks enabled state while delegating to the client', () async {
      final client = _FakeWakeLockClient();
      final repository = WakeLockRepository(client: client);

      expect(repository.isEnabled, isFalse);

      await repository.enable();
      expect(client.enableCalls, equals(1));
      expect(repository.isEnabled, isTrue);

      await repository.disable();
      expect(client.disableCalls, equals(1));
      expect(repository.isEnabled, isFalse);
    });

    test('exposes preventsLidCloseSleep from the client', () {
      final client = _FakeWakeLockClient();
      final repository = WakeLockRepository(client: client);

      expect(repository.preventsLidCloseSleep, isTrue);
    });
  });
}
