import 'dart:io';

import 'package:sesori_bridge/src/server/api/loopback_port_api.dart';
import 'package:sesori_bridge/src/server/host/bridge_host_port_service.dart';
import 'package:test/test.dart';

void main() {
  group('BridgeHostPortService', () {
    test('delegates host and port to the loopback probe', () async {
      final loopbackPortApi = _FakeLoopbackPortApi(availabilityByPort: {50123: true, 50124: false});
      final service = BridgeHostPortService(loopbackPortApi: loopbackPortApi);

      expect(await service.isBindable(host: '127.0.0.1', port: 50123), isTrue);
      expect(await service.isBindable(host: '::1', port: 50124), isFalse);
      expect(
        loopbackPortApi.invocations,
        equals(<String>['127.0.0.1:50123', '::1:50124']),
      );
    });

    test('reports a held loopback port as not bindable', () async {
      final occupiedSocket = await ServerSocket.bind('127.0.0.1', 0);
      addTearDown(occupiedSocket.close);
      const service = BridgeHostPortService(loopbackPortApi: LoopbackPortApi());

      expect(await service.isBindable(host: '127.0.0.1', port: occupiedSocket.port), isFalse);
    });
  });
}

class _FakeLoopbackPortApi implements LoopbackPortApi {
  _FakeLoopbackPortApi({required Map<int, bool> availabilityByPort}) : _availabilityByPort = availabilityByPort;

  final Map<int, bool> _availabilityByPort;
  final List<String> invocations = <String>[];

  @override
  Future<bool> isBindable({required String host, required int port}) async {
    invocations.add('$host:$port');
    final available = _availabilityByPort[port];
    if (available == null) {
      throw StateError('Unexpected port probe: $port');
    }
    return available;
  }
}
