import "package:meta/meta.dart";
import "package:sesori_bridge/src/server/api/loopback_port_api.dart";
import "package:sesori_bridge/src/server/repositories/port_repository.dart";
import "package:test/test.dart";

void main() {
  test("port repository reports loopback availability", () async {
    final loopbackPortApi = _FakeLoopbackPortApi(
      availabilityByPort: <int, bool>{4100: true},
    );
    final repository = PortRepository(loopbackPortApi: loopbackPortApi);

    final fact = await repository.getAvailabilityFact(port: 4100);

    expect(
      fact,
      equals(
        const PortAvailabilityFact(
          host: loopbackPortHost,
          port: 4100,
          isAvailable: true,
        ),
      ),
    );
    expect(loopbackPortApi.invocations, equals(<_ProbeInvocation>[
      const _ProbeInvocation(host: loopbackPortHost, port: 4100),
    ]));
  });

  test("port repository reports occupied port without kill", () async {
    final loopbackPortApi = _FakeLoopbackPortApi(
      availabilityByPort: <int, bool>{4096: false},
    );
    final repository = PortRepository(loopbackPortApi: loopbackPortApi);

    final fact = await repository.getAvailabilityFact(port: 4096);

    expect(fact.isAvailable, isFalse);
    expect(fact.host, equals(loopbackPortHost));
    expect(loopbackPortApi.unexpectedKillCallCount, equals(0));
    expect(loopbackPortApi.invocations, hasLength(1));
  });

  test("port repository preserves injected candidate order", () async {
    final loopbackPortApi = _FakeLoopbackPortApi(
      availabilityByPort: <int, bool>{5003: false, 5001: true, 5002: false},
    );
    final repository = PortRepository(loopbackPortApi: loopbackPortApi);

    final facts = await repository.getCandidateFacts(
      candidatePorts: <int>[5003, 5001, 5002],
    );

    expect(
      facts,
      equals(<PortAvailabilityFact>[
        const PortAvailabilityFact(
          host: loopbackPortHost,
          port: 5003,
          isAvailable: false,
        ),
        const PortAvailabilityFact(
          host: loopbackPortHost,
          port: 5001,
          isAvailable: true,
        ),
        const PortAvailabilityFact(
          host: loopbackPortHost,
          port: 5002,
          isAvailable: false,
        ),
      ]),
    );
    expect(loopbackPortApi.invocations.map((invocation) => invocation.port), <int>[5003, 5001, 5002]);
  });
}

class _FakeLoopbackPortApi implements LoopbackPortApi {
  _FakeLoopbackPortApi({
    required Map<int, bool> availabilityByPort,
  }) : _availabilityByPort = availabilityByPort;

  final Map<int, bool> _availabilityByPort;
  final List<_ProbeInvocation> invocations = <_ProbeInvocation>[];
  int unexpectedKillCallCount = 0;

  @override
  Future<bool> isBindable({
    required String host,
    required int port,
  }) async {
    invocations.add(_ProbeInvocation(host: host, port: port));
    final isAvailable = _availabilityByPort[port];
    if (isAvailable == null) {
      throw StateError("No availability configured for port $port");
    }
    return isAvailable;
  }

  void kill() {
    unexpectedKillCallCount++;
  }
}

@immutable
class _ProbeInvocation {
  const _ProbeInvocation({
    required this.host,
    required this.port,
  });

  final String host;
  final int port;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is _ProbeInvocation && other.host == host && other.port == port;
  }

  @override
  int get hashCode => Object.hash(host, port);
}
