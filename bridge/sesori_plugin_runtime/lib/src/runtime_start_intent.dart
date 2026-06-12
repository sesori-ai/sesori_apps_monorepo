import "dart:convert";

import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

/// A record that a managed-runtime spawn is *about to happen*, persisted to a
/// bridge-private side file before the child is launched and removed once the
/// real ownership record exists.
///
/// This closes the gap between "child spawned" and "ownership record written":
/// a bridge that crashes inside that window leaves no entry in the frozen
/// ownership file, but the intent side file still names the bridge run and the
/// port the spawn targeted. It deliberately carries **no child pid** — it is
/// written before the pid exists — and it is **never** merged into the frozen
/// `opencode-processes.json` (whose schema requires a non-null runtime pid and
/// is read verbatim by older bridge versions). Its shape is bridge-private and
/// may evolve freely.
class RuntimeStartIntent {
  const RuntimeStartIntent({
    required this.ownerSessionId,
    required this.port,
    required this.bridgePid,
    required this.bridgeStartMarker,
    required this.recordedAt,
  });

  /// Stable identifier of the bridge run that is about to spawn the runtime.
  final String ownerSessionId;

  /// The port the spawn is targeting.
  final int port;

  /// Pid of the hosting bridge process.
  final int bridgePid;

  /// Start marker of the hosting bridge process (absent on Windows).
  final String? bridgeStartMarker;

  /// When the intent was recorded (host clock).
  final DateTime recordedAt;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      "ownerSessionId": ownerSessionId,
      "port": port,
      "bridgePid": bridgePid,
      "bridgeStartMarker": bridgeStartMarker,
      "recordedAt": recordedAt.toUtc().toIso8601String(),
    };
  }

  static RuntimeStartIntent fromJson(Map<String, dynamic> json) {
    return RuntimeStartIntent(
      ownerSessionId: json["ownerSessionId"] as String,
      port: json["port"] as int,
      bridgePid: json["bridgePid"] as int,
      bridgeStartMarker: json["bridgeStartMarker"] as String?,
      recordedAt: DateTime.parse(json["recordedAt"] as String),
    );
  }

  @override
  String toString() {
    return "RuntimeStartIntent(ownerSessionId: $ownerSessionId, port: $port, bridgePid: $bridgePid)";
  }
}

/// Reads and writes the single in-flight [RuntimeStartIntent] to a bridge-private
/// side file (typically `<runtimeId>-start-intent.json`) inside the runtime's
/// state directory.
///
/// The file is a sibling of the frozen ownership file but is **never** read by
/// older bridge versions: writing or removing it leaves the ownership file
/// byte-for-byte untouched. Writes and removals use the plain [HostJsonStore]
/// operations (atomic write / no-op delete) rather than the locked `update()` —
/// the intent targets its own file, so there is nothing to serialize against,
/// and nesting an `update()` inside the ownership store's locked critical
/// section would deadlock.
class RuntimeStartIntentStore {
  RuntimeStartIntentStore({required HostJsonStore store, required String fileName})
    : _store = store,
      _fileName = fileName;

  final HostJsonStore _store;
  final String _fileName;

  /// Atomically writes [intent], replacing any previous in-flight intent.
  Future<void> write(RuntimeStartIntent intent) async {
    await _store.write(name: _fileName, contents: jsonEncode(intent.toJson()));
  }

  /// Reads the current intent, or `null` when none is recorded or the file is
  /// unreadable/corrupt (a leftover intent must never block a fresh start).
  Future<RuntimeStartIntent?> read() async {
    final String? contents;
    try {
      contents = await _store.read(name: _fileName);
    } on Object catch (error) {
      Log.w("Failed to read runtime start-intent side file at $_fileName; ignoring. Error: $error");
      return null;
    }
    if (contents == null || contents.trim().isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(contents);
      if (decoded is! Map) {
        return null;
      }
      return RuntimeStartIntent.fromJson(Map<String, dynamic>.from(decoded));
    } on Object catch (error) {
      Log.w("Failed to parse runtime start-intent side file at $_fileName; ignoring. Error: $error");
      return null;
    }
  }

  /// Removes the intent side file. A no-op when no intent is recorded, so it is
  /// safe to call on every start outcome (success, failure, abort).
  Future<void> clear() async {
    await _store.delete(name: _fileName);
  }
}
