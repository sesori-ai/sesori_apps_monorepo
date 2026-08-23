import "dart:math";

String generateSessionId({required Random secureRandom}) {
  final buffer = StringBuffer("ses_");
  for (var index = 0; index < 16; index++) {
    buffer.write(secureRandom.nextInt(256).toRadixString(16).padLeft(2, "0"));
  }
  return buffer.toString();
}
