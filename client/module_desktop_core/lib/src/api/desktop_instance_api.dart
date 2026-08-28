import "dart:async";
import "dart:io";

import "package:injectable/injectable.dart";
import "package:meta/meta.dart";
import "package:path/path.dart" as path;
import "package:sesori_dart_core/sesori_dart_core.dart";

import "../foundation/platform/desktop_application_support_directory.dart";

/// Layer-1 process boundary for the desktop instance lock and activation channel.
@lazySingleton
class DesktopInstanceApi.forTesting({
  required final DesktopApplicationSupportDirectory _applicationSupportDirectory,
  required final int _activationAttempts,
  required final Duration _activationRetryDelay,
  required final Duration _connectTimeout,
  required final Duration _readTimeout,
}) {
  new({required DesktopApplicationSupportDirectory applicationSupportDirectory})
    : this.forTesting(
        applicationSupportDirectory: applicationSupportDirectory,
        activationAttempts: 20,
        activationRetryDelay: const Duration(milliseconds: 50),
        connectTimeout: const Duration(milliseconds: 250),
        readTimeout: const Duration(seconds: 2),
      );

  @visibleForTesting
  this
    : assert(_activationAttempts > 0, "activationAttempts must be positive"),
      assert(!_activationRetryDelay.isNegative, "activationRetryDelay must not be negative"),
      assert(_connectTimeout > Duration.zero, "connectTimeout must be positive"),
      assert(_readTimeout > Duration.zero, "readTimeout must be positive");

  static const String _directoryName = "desktop-instance";
  static const String _lockFileName = "instance.lock";
  static const String _activationPortFileName = "activation-port";
  static const int _activationByte = 0x01;

  final StreamController<void> _activationRequests = StreamController<void>.broadcast(sync: true);
  final Set<Socket> _acceptedSockets = <Socket>{};
  RandomAccessFile? _lockHandle;
  ServerSocket? _activationServer;
  StreamSubscription<Socket>? _serverSubscription;
  File? _activationPortFile;
  bool _disposed = false;

  Stream<void> get activationRequests => _activationRequests.stream;

  Future<bool> tryAcquirePrimary() async {
    _ensureNotDisposed();
    if (_lockHandle != null) {
      return true;
    }

    final Directory directory = await _resolveDirectory();
    await directory.create(recursive: true);
    final RandomAccessFile handle = await File(path.join(directory.path, _lockFileName)).open(mode: FileMode.append);
    try {
      await handle.lock(FileLock.exclusive);
    } on FileSystemException {
      await handle.close();
      return false;
    }

    ServerSocket? server;
    try {
      server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0, shared: false);
      final File portFile = File(path.join(directory.path, _activationPortFileName));
      await portFile.writeAsString(server.port.toString(), flush: true);
      _lockHandle = handle;
      _activationServer = server;
      _activationPortFile = portFile;
      _serverSubscription = server.listen(
        _acceptActivationSocket,
        onError: (Object error, StackTrace stackTrace) {
          logw("Desktop activation server failed", error, stackTrace);
        },
      );
      return true;
    } on Object catch (error, stackTrace) {
      try {
        await server?.close();
      } on Object catch (cleanupError, cleanupStackTrace) {
        logw("Failed to close a partial desktop activation server", cleanupError, cleanupStackTrace);
      }
      try {
        await handle.unlock();
      } on Object catch (cleanupError, cleanupStackTrace) {
        logw("Failed to unlock a partial desktop instance claim", cleanupError, cleanupStackTrace);
      }
      try {
        await handle.close();
      } on Object catch (cleanupError, cleanupStackTrace) {
        logw("Failed to close a partial desktop instance lock", cleanupError, cleanupStackTrace);
      }
      Error.throwWithStackTrace(error, stackTrace);
    }
  }

  Future<bool> signalPrimary() async {
    _ensureNotDisposed();
    for (int attempt = 0; attempt < _activationAttempts; attempt++) {
      final int? port = await _readActivationPort();
      if (port != null && await _sendActivation(port: port)) {
        return true;
      }
      if (attempt + 1 < _activationAttempts) {
        await Future<void>.delayed(_activationRetryDelay);
      }
    }
    return false;
  }

  void _acceptActivationSocket(Socket socket) {
    _acceptedSockets.add(socket);
    unawaited(_readActivation(socket: socket));
  }

  Future<void> _readActivation({required Socket socket}) async {
    try {
      final List<int> bytes = await socket.timeout(_readTimeout).first;
      if (bytes.isNotEmpty && bytes.first == _activationByte && !_activationRequests.isClosed) {
        _activationRequests.add(null);
      }
    } on Object catch (error, stackTrace) {
      logw("Desktop activation request failed", error, stackTrace);
    } finally {
      _acceptedSockets.remove(socket);
      socket.destroy();
    }
  }

  Future<int?> _readActivationPort() async {
    final Directory directory = await _resolveDirectory();
    final File file = File(path.join(directory.path, _activationPortFileName));
    // ignore: avoid_slow_async_io, bounded process-start coordination
    if (!await file.exists()) {
      return null;
    }
    try {
      final int? port = int.tryParse((await file.readAsString()).trim());
      if (port == null || port < 1 || port > 65535) {
        return null;
      }
      return port;
    } on FileSystemException {
      return null;
    }
  }

  Future<bool> _sendActivation({required int port}) async {
    Socket? socket;
    try {
      socket = await Socket.connect(InternetAddress.loopbackIPv4, port, timeout: _connectTimeout);
      socket.add(const <int>[_activationByte]);
      await socket.flush();
      return true;
    } on SocketException {
      return false;
    } finally {
      socket?.destroy();
    }
  }

  Future<Directory> _resolveDirectory() async {
    final Directory root = await _applicationSupportDirectory.resolve();
    return Directory(path.join(root.path, _directoryName));
  }

  @disposeMethod
  Future<void> dispose() async {
    if (_disposed) {
      return;
    }
    _disposed = true;
    await _serverSubscription?.cancel();
    await _activationServer?.close();
    for (final Socket socket in _acceptedSockets) {
      socket.destroy();
    }
    _acceptedSockets.clear();
    final File? portFile = _activationPortFile;
    if (portFile != null) {
      try {
        // ignore: avoid_slow_async_io, one shutdown cleanup check
        if (await portFile.exists()) {
          await portFile.delete();
        }
      } on Object catch (error, stackTrace) {
        logw("Failed to remove the desktop activation metadata", error, stackTrace);
      }
    }
    final RandomAccessFile? handle = _lockHandle;
    if (handle != null) {
      try {
        await handle.unlock();
      } on Object catch (error, stackTrace) {
        logw("Failed to unlock the desktop instance file", error, stackTrace);
      }
      try {
        await handle.close();
      } on Object catch (error, stackTrace) {
        logw("Failed to close the desktop instance file", error, stackTrace);
      }
      _lockHandle = null;
    }
    await _activationRequests.close();
  }

  void _ensureNotDisposed() {
    if (_disposed) {
      throw StateError("DesktopInstanceApi is disposed");
    }
  }
}
