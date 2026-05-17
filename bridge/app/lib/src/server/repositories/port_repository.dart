import "package:meta/meta.dart";

import "../api/loopback_port_api.dart";

const String loopbackPortHost = "127.0.0.1";

class PortRepository {
  const PortRepository({
    required LoopbackPortApi loopbackPortApi,
  }) : _loopbackPortApi = loopbackPortApi;

  final LoopbackPortApi _loopbackPortApi;

  Future<PortAvailabilityFact> getAvailabilityFact({
    required int port,
  }) async {
    final isAvailable = await _loopbackPortApi.isBindable(
      host: loopbackPortHost,
      port: port,
    );

    return PortAvailabilityFact(
      host: loopbackPortHost,
      port: port,
      isAvailable: isAvailable,
    );
  }

  Future<List<PortAvailabilityFact>> getCandidateFacts({
    required Iterable<int> candidatePorts,
  }) async {
    final facts = <PortAvailabilityFact>[];

    for (final port in candidatePorts) {
      facts.add(await getAvailabilityFact(port: port));
    }

    return facts;
  }
}

@immutable
class PortAvailabilityFact {
  const PortAvailabilityFact({
    required this.host,
    required this.port,
    required this.isAvailable,
  });

  final String host;
  final int port;
  final bool isAvailable;

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        other is PortAvailabilityFact &&
            other.host == host &&
            other.port == port &&
            other.isAvailable == isAvailable;
  }

  @override
  int get hashCode => Object.hash(host, port, isAvailable);
}
