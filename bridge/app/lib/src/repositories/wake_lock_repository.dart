import '../api/wake_lock_client.dart';

class WakeLockRepository({required final WakeLockClient _client}) {
  /// Whether the operating system currently grants the wake lock.
  bool get isHeld => _client.isHeld;

  bool get preventsLidCloseSleep => _client.preventsLidCloseSleep;

  Future<void> enable() => _client.enable();

  Future<void> disable() => _client.disable();
}
