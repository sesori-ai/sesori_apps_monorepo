import "dart:async";

import "protocol.dart";

sealed class DeviceCanvasConnectionSnapshot() {
  bool get isConnected;
}

final class DeviceCanvasDisconnectedSnapshot() extends DeviceCanvasConnectionSnapshot {
  @override
  bool get isConnected => false;
}

final class DeviceCanvasConnectedSnapshot({required final String canvasInstanceId, required final int protocolVersion})
    extends DeviceCanvasConnectionSnapshot {
  @override
  bool get isConnected => true;
}

class DeviceCanvasPresenceSnapshot({required final Map<String, DeviceCanvasDescriptor> devicesByKey});

class DeviceCanvasIntegrationState() {
  final StreamController<DeviceCanvasConnectionSnapshot> _connectionChanges =
      StreamController<DeviceCanvasConnectionSnapshot>.broadcast(sync: true);
  final StreamController<DeviceCanvasPresenceSnapshot> _presenceChanges =
      StreamController<DeviceCanvasPresenceSnapshot>.broadcast(sync: true);

  DeviceCanvasConnectionSnapshot _connection = DeviceCanvasDisconnectedSnapshot();
  Map<String, DeviceCanvasDescriptor> _devicesByKey = const <String, DeviceCanvasDescriptor>{};
  bool _disposed = false;

  Stream<DeviceCanvasConnectionSnapshot> get connectionChanges => _connectionChanges.stream;
  Stream<DeviceCanvasPresenceSnapshot> get presenceChanges => _presenceChanges.stream;
  DeviceCanvasConnectionSnapshot get connectionSnapshot => _connection;
  DeviceCanvasPresenceSnapshot get presenceSnapshot =>
      DeviceCanvasPresenceSnapshot(devicesByKey: Map<String, DeviceCanvasDescriptor>.unmodifiable(_devicesByKey));

  bool get isConnected => _connection.isConnected;
  bool isDeviceAvailable(String deviceKey) => _devicesByKey.containsKey(deviceKey);

  void connect({required String canvasInstanceId, required int protocolVersion}) {
    _connection = DeviceCanvasConnectedSnapshot(canvasInstanceId: canvasInstanceId, protocolVersion: protocolVersion);
    _emitConnection();
  }

  void replaceInventory(List<DeviceCanvasDescriptor> devices) {
    _devicesByKey = Map<String, DeviceCanvasDescriptor>.unmodifiable({
      for (final device in devices) device.deviceKey: device,
    });
    _emitPresence();
  }

  void disconnect() {
    final hadState = _connection.isConnected || _devicesByKey.isNotEmpty;
    _connection = DeviceCanvasDisconnectedSnapshot();
    _devicesByKey = const <String, DeviceCanvasDescriptor>{};
    if (hadState) {
      _emitConnection();
      _emitPresence();
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await _connectionChanges.close();
    await _presenceChanges.close();
  }

  void _emitConnection() {
    if (!_connectionChanges.isClosed) _connectionChanges.add(_connection);
  }

  void _emitPresence() {
    if (!_presenceChanges.isClosed) _presenceChanges.add(presenceSnapshot);
  }
}
