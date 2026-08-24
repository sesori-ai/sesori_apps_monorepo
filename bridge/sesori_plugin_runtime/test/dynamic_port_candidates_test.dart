import "dart:math";

import "package:sesori_plugin_runtime/sesori_plugin_runtime.dart";
import "package:test/test.dart";

void main() {
  test("filters and bounds supplied candidates while preserving order and duplicates", () {
    final ports = dynamicPortCandidates(
      minPort: 49152,
      maxPort: 65535,
      maxDraws: 5,
      reservedPort: 49153,
      candidates: <int>[80, 49152, 49152, 49153, 49154, 49155],
      random: null,
    ).toList();

    expect(ports, equals(<int>[49152, 49152, 49154]));
  });

  test("bounds an infinite invalid supplied source", () {
    Iterable<int> invalid() sync* {
      while (true) {
        yield 80;
      }
    }

    expect(
      dynamicPortCandidates(
        minPort: 49152,
        maxPort: 65535,
        maxDraws: 5,
        reservedPort: 0,
        candidates: invalid(),
        random: null,
      ),
      isEmpty,
    );
  });

  test("bounds random draws and skips duplicates", () {
    final random = _FixedRandom(0);
    final ports = dynamicPortCandidates(
      minPort: 49152,
      maxPort: 65535,
      maxDraws: 5,
      reservedPort: 0,
      candidates: null,
      random: random,
    ).toList();

    expect(ports, equals(<int>[49152]));
    expect(random.draws, equals(5));
  });
}

final class _FixedRandom(final int value) implements Random {
  int draws = 0;

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();

  @override
  int nextInt(int max) {
    draws++;
    return value;
  }
}
