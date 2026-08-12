import "dart:math";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../../logging/logging.dart";

@lazySingleton
class NotificationPreferencesDeviceIdStorage({required SecureStorage storage}) {
  static const _storageKey = "notification_preferences_device_id_v1";
  static final _uuidV4Pattern = RegExp(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",
  );

  final SecureStorage _storage;
  final Random _random = Random.secure();

  String? _deviceId;
  Future<String>? _pendingDeviceId;

  this : _storage = storage;

  Future<String> getOrCreate() {
    final deviceId = _deviceId;
    if (deviceId != null) return Future.value(deviceId);

    final pendingDeviceId = _pendingDeviceId;
    if (pendingDeviceId != null) return pendingDeviceId;

    late final Future<String> operation;
    operation = _loadOrCreate()
        .then((value) {
          _deviceId = value;
          return value;
        })
        .whenComplete(() {
          if (identical(_pendingDeviceId, operation)) {
            _pendingDeviceId = null;
          }
        });
    _pendingDeviceId = operation;
    return operation;
  }

  Future<String> _loadOrCreate() async {
    final stored = await _storage.read(key: _storageKey);
    if (stored != null && _uuidV4Pattern.hasMatch(stored)) return stored;
    if (stored != null) {
      logw("Stored notification preferences device ID was invalid; replacing it");
    }

    final generated = _generateUuidV4();
    await _storage.write(key: _storageKey, value: generated);
    return generated;
  }

  String _generateUuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final value = StringBuffer();
    for (var index = 0; index < bytes.length; index++) {
      if (index == 4 || index == 6 || index == 8 || index == 10) {
        value.write("-");
      }
      value.write(bytes[index].toRadixString(16).padLeft(2, "0"));
    }
    return value.toString();
  }
}
