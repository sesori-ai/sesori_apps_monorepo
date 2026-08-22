import "dart:async";
import "dart:io";

import "package:rxdart/rxdart.dart";
import "package:sesori_bridge/src/auth/access_token_provider.dart";
import "package:sesori_bridge/src/auth/bridge_id_provider.dart";
import "package:sesori_bridge/src/foundation/relay_client.dart";

final class BenchmarkRelayFixture._({
  required final RelayClient client,
  required final RelayConnection connection,
  required final HttpServer _server,
  required final _BenchmarkAccessTokenProvider _accessTokenProvider,
}) {
  static Future<BenchmarkRelayFixture> start() async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      if (!WebSocketTransformer.isUpgradeRequest(request)) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      final socket = await WebSocketTransformer.upgrade(request);
      socket.listen((_) {});
    });
    final accessTokenProvider = _BenchmarkAccessTokenProvider();
    final client = RelayClient(
      relayURL: "ws://127.0.0.1:${server.port}",
      accessTokenProvider: accessTokenProvider,
      bridgeIdProvider: const _BenchmarkBridgeIdProvider(),
    );
    try {
      final connection = await client.connect();
      return BenchmarkRelayFixture._(
        client: client,
        connection: connection,
        server: server,
        accessTokenProvider: accessTokenProvider,
      );
    } on Object {
      await accessTokenProvider.dispose();
      await server.close(force: true);
      rethrow;
    }
  }

  Future<void> dispose() async {
    await client.closeIfCurrent(connection: connection);
    await _accessTokenProvider.dispose();
    await _server.close(force: true);
  }
}

final class _BenchmarkAccessTokenProvider() implements AccessTokenProvider {
  final BehaviorSubject<String> _tokens = BehaviorSubject.seeded("");

  @override
  String get accessToken => "";

  @override
  ValueStream<String> get tokenStream => _tokens;

  Future<void> dispose() => _tokens.close();
}

final class const _BenchmarkBridgeIdProvider() implements BridgeIdProvider {
  @override
  String? get bridgeId => null;
}
