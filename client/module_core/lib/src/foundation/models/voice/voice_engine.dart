/// Which engine transcribes a dictation, as picked in Settings. Temporary, for
/// comparing the two until one is decided.
enum VoiceEngine({
  /// The persisted spelling. Pinned here rather than derived from the enum name so
  /// renaming a case cannot orphan a stored preference.
  required final String storageValue,
}) {
  /// The operating system's own engine.
  device(storageValue: "device"),

  /// The server.
  remote(storageValue: "remote");

  /// The engine persisted as [value], or `null` when it matches no known case.
  static VoiceEngine? tryParse({required String value}) {
    for (final engine in VoiceEngine.values) {
      if (engine.storageValue == value) return engine;
    }
    return null;
  }
}
