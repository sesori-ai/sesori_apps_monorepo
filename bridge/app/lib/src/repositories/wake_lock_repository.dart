import '../api/wake_lock_client.dart';

class WakeLockRepository({required WakeLockClient client}) {
  final WakeLockClient _client;
  bool _isEnabled = false;

  this : _client = client;

  bool get isEnabled => _isEnabled;

  bool get preventsLidCloseSleep => _client.preventsLidCloseSleep;

  Future<void> enable() async {
    await _client.enable();
    _isEnabled = true;
  }

  Future<void> disable() async {
    await _client.disable();
    _isEnabled = false;
  }
}
