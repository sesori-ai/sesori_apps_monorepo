/// Controls device wake lock state.
abstract class WakeLockClient {
  Future<void> enable();

  Future<void> disable();
}
