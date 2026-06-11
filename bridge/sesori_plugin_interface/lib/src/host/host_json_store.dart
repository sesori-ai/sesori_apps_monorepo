import "dart:async";

/// Atomic JSON-file persistence inside the plugin's state directory.
///
/// All operations address files by bare [String] name. Names must be plain
/// file names: implementations reject path separators and the reserved
/// `bridge-startup.*` prefix (those files belong to the bridge's own startup
/// mutex). Writes are atomic (write-to-temp + rename), so readers never see
/// a partially written file.
///
/// Contents are raw strings, not decoded JSON, on purpose: stores with a
/// frozen on-disk contract (byte-stable files read by older bridge versions)
/// need full control over the serialized bytes.
abstract class HostJsonStore {
  /// Reads the contents of [name], or `null` when the file does not exist.
  Future<String?> read({required String name});

  /// Atomically writes [contents] to [name], replacing any existing file.
  Future<void> write({required String name, required String contents});

  /// Deletes [name]. A no-op when the file does not exist.
  Future<void> delete({required String name});

  /// Moves a corrupt [name] aside to [quarantinedName] (same directory) so a
  /// fresh file can be started without destroying the evidence. A no-op when
  /// [name] does not exist.
  Future<void> quarantine({required String name, required String quarantinedName});

  /// Reads [name], applies [transform], and atomically writes the result —
  /// all while holding an OS-level advisory lock on the file, so concurrent
  /// mutators (a restart racing a stale-cleanup pass) cannot drop each
  /// other's records.
  ///
  /// [transform] receives the current contents (`null` when the file does
  /// not exist) and returns the new contents; returning `null` deletes the
  /// file. Returns what was written (or `null` when deleted).
  ///
  /// [transform] must not call [update] for the same [name], directly or
  /// transitively: implementations queue same-name calls within the process
  /// (the OS advisory lock alone cannot exclude them there), so a reentrant
  /// call deadlocks behind its caller.
  Future<String?> update({
    required String name,
    required FutureOr<String?> Function(String? current) transform,
  });
}
