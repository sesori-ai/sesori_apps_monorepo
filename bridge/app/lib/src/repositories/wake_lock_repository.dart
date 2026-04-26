import '../api/wake_lock_client.dart';

class WakeLockRepository {
  final WakeLockClient _client;
  bool _isEnabled = false;

  WakeLockRepository({required WakeLockClient client}) : _client = client;

  bool get isEnabled => _isEnabled;

  Future<void> enable() async {
    await _client.enable();
    _isEnabled = true;
  }

  Future<void> disable() async {
    await _client.disable();
    _isEnabled = false;
  }
}
