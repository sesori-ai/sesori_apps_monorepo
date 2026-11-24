import "dart:io";

/// The IANA name of this computer's time zone, or null when it cannot be
/// told: `TZ` when it names a zone, otherwise the zoneinfo file that `TZ` or
/// `/etc/localtime` links to, as macOS and most Linux systems keep it.
/// Windows names its zones differently, so it gets null.
String? readLocalTimeZone({required Map<String, String> environment}) {
  // POSIX lets TZ start with a colon.
  final configured = environment["TZ"]?.replaceFirst(RegExp("^:"), "").trim();
  if (configured != null && configured.isNotEmpty && !configured.startsWith("/")) return configured;
  if (Platform.isWindows) return null;
  try {
    final target = File(configured == null || configured.isEmpty ? "/etc/localtime" : configured)
        .resolveSymbolicLinksSync();
    const marker = "/zoneinfo/";
    final index = target.indexOf(marker);
    return index < 0 ? null : target.substring(index + marker.length);
  } on FileSystemException {
    return null;
  }
}
