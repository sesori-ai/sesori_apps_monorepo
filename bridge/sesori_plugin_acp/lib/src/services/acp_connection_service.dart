import "dart:async";

import "../acp_protocol.dart";
import "../acp_stdio_client.dart";
import "../repositories/acp_session_repository.dart";

class AcpConnectionConfiguration {
  const AcpConnectionConfiguration({
    required this.initializeRequest,
    required this.authMethodId,
  });

  final AcpInitializeRequest initializeRequest;
  final String? authMethodId;
}

class AcpConnection {
  const AcpConnection({
    required this.client,
    required this.repository,
    required this.initializeResult,
  });

  final AcpStdioClient client;
  final AcpSessionRepository repository;
  final AcpInitializeResult initializeResult;
}

class AcpConnectionService {
  AcpConnectionService({
    required AcpStdioClient client,
    required AcpSessionRepository repository,
    required AcpConnectionConfiguration configuration,
  }) : _client = client,
       _repository = repository,
       _configuration = configuration;

  final AcpStdioClient _client;
  final AcpSessionRepository _repository;
  final AcpConnectionConfiguration _configuration;

  final StreamController<void> _connections = StreamController<void>.broadcast(
    sync: true,
  );
  Future<AcpConnection>? _connectFuture;
  AcpConnection? _current;

  Stream<void> get connections => _connections.stream;
  AcpConnection? get current => _current;

  Future<AcpConnection> ensureConnected() {
    final existing = _connectFuture;
    if (existing != null) return existing;
    final future = _connect();
    _connectFuture = future;
    return future;
  }

  Future<AcpConnection> _connect() async {
    try {
      await _client.connect();
      final initializeResult = await initializeRepository(_repository);
      final connection = AcpConnection(
        client: _client,
        repository: _repository,
        initializeResult: initializeResult,
      );
      _current = connection;
      if (!_connections.isClosed) _connections.add(null);
      return connection;
    } on Object {
      _connectFuture = null;
      _current = null;
      await _client.reset(gracefulTimeout: Duration.zero);
      rethrow;
    }
  }

  Future<AcpInitializeResult> initializeRepository(
    AcpSessionRepository repository, {
    Duration timeout = const Duration(seconds: 60),
  }) async {
    final result = await repository.initialize(
      request: _configuration.initializeRequest,
      timeout: timeout,
    );
    if (result.protocolVersion != acpProtocolVersion) {
      throw StateError(
        "ACP agent negotiated protocol version ${result.protocolVersion}, "
        "but this client only speaks v$acpProtocolVersion",
      );
    }
    if (result.requiresAuth) {
      final methodId =
          _configuration.authMethodId ?? (result.authMethods.isNotEmpty ? result.authMethods.first.id : null);
      if (methodId != null) {
        await repository.authenticate(methodId: methodId, timeout: timeout);
      }
    }
    return result;
  }

  Future<void> reset() async {
    _connectFuture = null;
    _current = null;
    await _client.reset(gracefulTimeout: Duration.zero);
  }

  Future<void> dispose() async {
    _connectFuture = null;
    _current = null;
    await _client.dispose();
    await _connections.close();
  }
}
