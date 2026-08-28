import "dart:math";

String generateRandomHexId({
  required Random secureRandom,
  required String prefix,
  required int byteLength,
}) {
  final buffer = StringBuffer(prefix);
  for (var index = 0; index < byteLength; index++) {
    buffer.write(secureRandom.nextInt(256).toRadixString(16).padLeft(2, "0"));
  }
  return buffer.toString();
}
