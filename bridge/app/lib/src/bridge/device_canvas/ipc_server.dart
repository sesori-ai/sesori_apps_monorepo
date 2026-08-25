import "dart:async";
import "dart:convert";
import "dart:io";
import "dart:math";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;

import "../../repositories/device_canvas_claim_repository.dart";
import "../../services/device_canvas_claim_service.dart";
import "integration_state.dart";
import "protocol.dart";
import "protocol_codec.dart";
import "rendezvous_repository.dart";

class DeviceCanvasIpcServer({
  required DeviceCanvasRendezvousRepository rendezvousRepository,
  required String bridgeId,
  required String processGeneration,
  required DeviceCanvasClaimService claimService,
  required DeviceCanvasIntegrationState integrationState,
  Duration heartbeatTimeout = const Duration(seconds: 15),
}) {
  final DeviceCanvasRendezvousRepository _rendezvousRepository = rendezvousRepository;
  final String _bridgeId = bridgeId;
  final String _processGeneration = processGeneration;
  final DeviceCanvasClaimService _claimService = claimService;
  final DeviceCanvasIntegrationState _integrationState = integrationState;
  final Duration _heartbeatTimeout = heartbeatTimeout;
  final DeviceCanvasProtocolCodec _codec = const DeviceCanvasProtocolCodec();
  final String _secret = _generateSecret();

  HttpServer? _server;
  StreamSubscription<HttpRequest>? _serverSubscription;
  StreamSubscription<DeviceCanvasClaimChange>? _claimSubscription;
  _DeviceCanvasPeer? _peer;
  int _peerRequestSequence = 0;
  int _latestInstalledPeerSequence = 0;
  bool _started = false;
  bool _disposed = false;

  String get rendezvousFilePath => _rendezvousRepository.filePath;
  int? get port => _server?.port;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    try {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      _server = server;
      _serverSubscription = server.listen(
        (request) => unawaited(_handleRequestLogged(request)),
        onError: (Object error, StackTrace stackTrace) =>
            Log.w("Device Canvas IPC HTTP server stream failed", error, stackTrace),
        cancelOnError: false,
      );
      _claimSubscription = _claimService.changes.listen(
        _publishClaimChange,
        onError: (Object error, StackTrace stackTrace) => Log.w("Device Canvas claim stream failed", error, stackTrace),
      );
      await _rendezvousRepository.write(
        _rendezvousRepository.create(
          port: server.port,
          bearerSecret: _secret,
          bridgeId: _bridgeId,
          processGeneration: _processGeneration,
        ),
      );
    } on Object {
      await _cleanupFailedStart();
      rethrow;
    }
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    Object? firstError;
    StackTrace? firstStackTrace;

    Future<void> step(Future<void>? Function() dispose) async {
      try {
        await dispose();
      } on Object catch (error, stackTrace) {
        firstError ??= error;
        firstStackTrace ??= stackTrace;
      }
    }

    await step(() => _claimSubscription?.cancel());
    _claimSubscription = null;
    await step(() => _serverSubscription?.cancel());
    _serverSubscription = null;
    final peer = _peer;
    _peer = null;
    _integrationState.disconnect();
    await step(() => peer?.dispose(closeCode: WebSocketStatus.goingAway, reason: "bridge shutting down"));
    final server = _server;
    _server = null;
    await step(() => server?.close(force: true));
    await step(_rendezvousRepository.delete);

    if (firstError != null) {
      Error.throwWithStackTrace(firstError!, firstStackTrace!);
    }
  }

  Future<void> _cleanupFailedStart() async {
    _started = false;
    _integrationState.disconnect();
    final peer = _peer;
    _peer = null;
    await _runCleanupStep(
      () => peer?.dispose(closeCode: WebSocketStatus.goingAway, reason: "Device Canvas IPC startup failed"),
    );
    await _runCleanupStep(() => _claimSubscription?.cancel());
    _claimSubscription = null;
    await _runCleanupStep(() => _serverSubscription?.cancel());
    _serverSubscription = null;
    final server = _server;
    _server = null;
    await _runCleanupStep(() => server?.close(force: true));
    await _runCleanupStep(_rendezvousRepository.delete);
  }

  Future<void> _runCleanupStep(Future<void>? Function() step) async {
    try {
      await step();
    } on Object catch (error, stackTrace) {
      Log.w("Device Canvas IPC startup cleanup step failed", error, stackTrace);
    }
  }

  Future<void> _handleRequestLogged(HttpRequest request) async {
    try {
      await _handleRequest(request);
    } on Object catch (error, stackTrace) {
      Log.w("Device Canvas IPC request handling failed", error, stackTrace);
      try {
        await request.response.close();
      } on Object catch (closeError, closeStackTrace) {
        Log.w("Device Canvas IPC request close after failure failed", closeError, closeStackTrace);
      }
    }
  }

  Future<void> _handleRequest(HttpRequest request) async {
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    if (request.headers.value(HttpHeaders.authorizationHeader) != "Bearer $_secret") {
      Log.w("Rejected unauthorized Device Canvas IPC loopback WebSocket upgrade request");
      request.response.statusCode = HttpStatus.unauthorized;
      await request.response.close();
      return;
    }

    final requestSequence = ++_peerRequestSequence;
    final socket = await WebSocketTransformer.upgrade(request);
    if (requestSequence < _latestInstalledPeerSequence) {
      await socket.close(WebSocketStatus.goingAway, "replaced by a newer Device Canvas peer");
      return;
    }
    final oldPeer = _peer;
    final peer = _DeviceCanvasPeer(
      socket: socket,
      heartbeatTimeout: _heartbeatTimeout,
      onTimeout: (timedOutPeer) => _startPeerOperation(
        peer: timedOutPeer,
        context: "handling Device Canvas heartbeat timeout",
        operation: () => _handlePeerTimeout(timedOutPeer),
      ),
    );
    _latestInstalledPeerSequence = requestSequence;
    _peer = peer;
    _integrationState.disconnect();
    peer.subscription = socket.listen(
      (data) => _handleFrame(peer: peer, data: data),
      onError: (Object error, StackTrace stackTrace) {
        Log.w("Device Canvas IPC socket failed", error, stackTrace);
        _clearPeer(peer);
      },
      onDone: () => _clearPeer(peer),
      cancelOnError: false,
    );
    await oldPeer?.dispose(closeCode: WebSocketStatus.goingAway, reason: "replaced by a newer Device Canvas peer");
  }

  void _handleFrame({required _DeviceCanvasPeer peer, required dynamic data}) {
    if (!identical(peer, _peer)) return;
    if (data is! String) {
      _startPeerOperation(
        peer: peer,
        context: "rejecting non-text Device Canvas IPC frame",
        operation: () => _closeFailedPeer(peer: peer, reason: "non-text Device Canvas IPC frame"),
      );
      return;
    }

    final DeviceCanvasInboundMessage message;
    try {
      message = _codec.decodeInbound(data);
    } on Object {
      _startPeerOperation(
        peer: peer,
        context: "rejecting malformed Device Canvas IPC frame",
        operation: () => _closeFailedPeer(peer: peer, reason: "malformed Device Canvas IPC frame"),
      );
      return;
    }

    switch (message) {
      case DeviceCanvasHello():
        final hello = message;
        _startPeerOperation(
          peer: peer,
          context: "handling Device Canvas hello",
          operation: () => _handleHello(peer: peer, message: hello),
        );
      case DeviceCanvasInventorySnapshot(:final devices):
        if (!peer.helloAccepted) {
          _startPeerOperation(
            peer: peer,
            context: "rejecting Device Canvas inventory before hello",
            operation: () => _closeFailedPeer(peer: peer, reason: "inventory before hello"),
          );
          return;
        }
        _integrationState.replaceInventory(devices);
      case DeviceCanvasHeartbeat(:final canvasInstanceId):
        if (!peer.helloAccepted || peer.canvasInstanceId != canvasInstanceId) {
          _startPeerOperation(
            peer: peer,
            context: "rejecting Device Canvas heartbeat identity mismatch",
            operation: () => _closeFailedPeer(peer: peer, reason: "heartbeat identity mismatch"),
          );
          return;
        }
        peer.armHeartbeat();
    }
  }

  void _startPeerOperation({
    required _DeviceCanvasPeer peer,
    required String context,
    required Future<void> Function() operation,
  }) {
    unawaited(_runPeerOperation(peer: peer, context: context, operation: operation));
  }

  Future<void> _runPeerOperation({
    required _DeviceCanvasPeer peer,
    required String context,
    required Future<void> Function() operation,
  }) async {
    try {
      await operation();
    } on Object catch (error, stackTrace) {
      Log.w("Device Canvas IPC peer operation failed while $context", error, stackTrace);
      if (identical(peer, _peer)) {
        _peer = null;
        _integrationState.disconnect();
      }
      try {
        await peer.dispose(
          closeCode: WebSocketStatus.internalServerError,
          reason: "Device Canvas IPC peer operation failed",
        );
      } on Object catch (closeError, closeStackTrace) {
        Log.w("Device Canvas IPC peer close after operation failure failed", closeError, closeStackTrace);
      }
    }
  }

  Future<void> _handleHello({required _DeviceCanvasPeer peer, required DeviceCanvasHello message}) async {
    if (!identical(peer, _peer)) return;
    if (peer.helloAccepted) {
      await _closeFailedPeer(peer: peer, reason: "duplicate hello");
      return;
    }
    if (message.protocolVersion != deviceCanvasIpcProtocolVersion) {
      Log.w(
        "Rejected Device Canvas IPC hello with unsupported protocol version "
        "${message.protocolVersion}; supported version is $deviceCanvasIpcProtocolVersion",
      );
      if (!_send(
        peer,
        const DeviceCanvasOutboundMessage.compatibilityStatus(
          supported: false,
          protocolVersion: deviceCanvasIpcProtocolVersion,
          reason: "unsupportedProtocolVersion",
        ),
      )) {
        return;
      }
      await _closeFailedPeer(peer: peer, reason: "unsupported Device Canvas IPC protocol version");
      return;
    }

    _integrationState.connect(canvasInstanceId: message.canvasInstanceId, protocolVersion: message.protocolVersion);
    peer.acceptHello(canvasInstanceId: message.canvasInstanceId);
    peer.armHeartbeat();
    if (!_send(
      peer,
      DeviceCanvasOutboundMessage.helloAccepted(protocolVersion: deviceCanvasIpcProtocolVersion, bridgeId: _bridgeId),
    )) {
      return;
    }
    final claims = await _claimService.snapshot(bridgeId: _bridgeId);
    if (!identical(peer, _peer)) return;
    if (!_send(
      peer,
      DeviceCanvasOutboundMessage.claimsSnapshot(
        claims: [
          for (final claim in claims) _claimProjectionToDto(claim),
        ],
      ),
    )) {
      return;
    }
    peer.claimSnapshotSent = true;
    _flushPendingClaimChanges(peer);
  }

  void _publishClaimChange(DeviceCanvasClaimChange change) {
    final peer = _peer;
    if (peer == null || !peer.helloAccepted) return;
    if (!_isChangeForBridge(change)) return;
    if (!peer.claimSnapshotSent) {
      final deviceKey = switch (change) {
        DeviceCanvasClaimUpdated(:final projection) => projection.deviceKey,
        DeviceCanvasClaimRemoved(:final deviceKey) => deviceKey,
      };
      if (!peer.pendingClaimChanges.containsKey(deviceKey) &&
          peer.pendingClaimChanges.length >= DeviceCanvasClaimRepository.maxProjectedClaims) {
        _startPeerOperation(
          peer: peer,
          context: "closing an overflowing Device Canvas claim buffer",
          operation: () => _closeFailedPeer(peer: peer, reason: "claim snapshot delta buffer exceeded"),
        );
        return;
      }
      peer.pendingClaimChanges[deviceKey] = change;
      return;
    }
    _sendClaimChange(peer: peer, change: change);
  }

  void _flushPendingClaimChanges(_DeviceCanvasPeer peer) {
    for (final change in peer.pendingClaimChanges.values) {
      _sendClaimChange(peer: peer, change: change);
    }
    peer.pendingClaimChanges.clear();
  }

  bool _isChangeForBridge(DeviceCanvasClaimChange change) {
    return switch (change) {
      DeviceCanvasClaimUpdated(:final projection) => projection.bridgeId == _bridgeId,
      DeviceCanvasClaimRemoved(:final bridgeId) => bridgeId == _bridgeId,
    };
  }

  void _sendClaimChange({required _DeviceCanvasPeer peer, required DeviceCanvasClaimChange change}) {
    switch (change) {
      case DeviceCanvasClaimUpdated(:final projection):
        _send(peer, DeviceCanvasOutboundMessage.claimUpdated(claim: _claimProjectionToDto(projection)));
      case DeviceCanvasClaimRemoved(:final bridgeId, :final deviceKey, :final claimRevision):
        _send(
          peer,
          DeviceCanvasOutboundMessage.claimRemoved(bridgeId: bridgeId, deviceKey: deviceKey, revision: claimRevision),
        );
    }
  }

  Future<void> _handlePeerTimeout(_DeviceCanvasPeer peer) async {
    if (!identical(peer, _peer)) return;
    _peer = null;
    _integrationState.disconnect();
    await peer.dispose(closeCode: WebSocketStatus.goingAway, reason: "Device Canvas heartbeat timed out");
  }

  void _clearPeer(_DeviceCanvasPeer peer) {
    if (!identical(peer, _peer)) return;
    _peer = null;
    _integrationState.disconnect();
    peer.cancelHeartbeat();
  }

  Future<void> _closeFailedPeer({required _DeviceCanvasPeer peer, required String reason}) async {
    if (identical(peer, _peer)) {
      _peer = null;
      _integrationState.disconnect();
    }
    await peer.dispose(closeCode: WebSocketStatus.unsupportedData, reason: reason);
  }

  bool _send(_DeviceCanvasPeer peer, DeviceCanvasOutboundMessage message) {
    if (peer.socket.readyState != WebSocket.open) return false;
    try {
      peer.socket.add(_codec.encodeOutbound(message));
      return true;
    } on Object catch (error, stackTrace) {
      _startPeerOperation(
        peer: peer,
        context: "sending Device Canvas IPC frame",
        operation: () async => Error.throwWithStackTrace(error, stackTrace),
      );
      return false;
    }
  }

  static DeviceCanvasClaimProjectionDto _claimProjectionToDto(DeviceCanvasClaimProjection claim) {
    return DeviceCanvasClaimProjectionDto(
      bridgeId: claim.bridgeId,
      sessionId: claim.sessionId,
      deviceKey: claim.deviceKey,
      revision: claim.claimRevision,
      displayTitle: switch (claim.displayTitle) {
        final title? when title.runes.length > maxDeviceCanvasIpcDisplayLength => String.fromCharCodes(
          title.runes.take(maxDeviceCanvasIpcDisplayLength),
        ),
        final title => title,
      },
    );
  }

  static String _generateSecret() {
    final random = Random.secure();
    return base64Url.encode(List<int>.generate(32, (_) => random.nextInt(256)));
  }
}

class _DeviceCanvasPeer({
  required final WebSocket socket,
  required final Duration heartbeatTimeout,
  required final void Function(_DeviceCanvasPeer peer) onTimeout,
}) {
  StreamSubscription<dynamic>? subscription;
  Timer? heartbeatTimer;
  bool helloAccepted = false;
  bool claimSnapshotSent = false;
  String? canvasInstanceId;
  final Map<String, DeviceCanvasClaimChange> pendingClaimChanges = <String, DeviceCanvasClaimChange>{};

  void acceptHello({required String canvasInstanceId}) {
    this.canvasInstanceId = canvasInstanceId;
    helloAccepted = true;
  }

  void armHeartbeat() {
    heartbeatTimer?.cancel();
    heartbeatTimer = Timer(heartbeatTimeout, () => onTimeout(this));
  }

  void cancelHeartbeat() {
    heartbeatTimer?.cancel();
    heartbeatTimer = null;
  }

  Future<void> dispose({required int closeCode, required String reason}) async {
    cancelHeartbeat();
    await subscription?.cancel();
    subscription = null;
    await socket.close(closeCode, reason);
  }
}
