import "dart:math";

final class RelayRequestIdGenerator() {
  final Random _random = Random();
  int _counter = 0;

  String call() {
    _counter = (_counter + 1) & 0xFFFF;
    final timestamp = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final counter = _counter.toRadixString(16).padLeft(4, "0");
    final random = _random.nextInt(0x10000).toRadixString(16).padLeft(4, "0");
    return "$timestamp-$counter$random";
  }
}
