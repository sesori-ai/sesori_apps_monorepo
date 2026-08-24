import "dart:math";

Iterable<int> dynamicPortCandidates({
  required int minPort,
  required int maxPort,
  required int maxDraws,
  required int reservedPort,
  required Iterable<int>? candidates,
  required Random? random,
}) sync* {
  bool isCandidate(int port) => port != reservedPort && port >= minPort && port <= maxPort;

  final supplied = candidates;
  if (supplied != null) {
    for (final port in supplied.take(maxDraws)) {
      if (isCandidate(port)) yield port;
    }
    return;
  }

  final rng = random ?? Random.secure();
  final seen = <int>{};
  for (var examined = 0; examined < maxDraws; examined++) {
    final port = minPort + rng.nextInt(maxPort - minPort + 1);
    if (isCandidate(port) && seen.add(port)) yield port;
  }
}
