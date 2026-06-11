/// Loopback-port probing offered by the bridge to plugins.
abstract class HostPortService {
  /// Whether [port] on [host] can currently be bound (i.e. is free).
  ///
  /// A `true` result is a point-in-time fact, not a reservation — another
  /// process can take the port between the probe and the plugin's own bind.
  Future<bool> isBindable({required String host, required int port});
}
