/// In-memory store for unsent composer drafts, keyed by a stable key
/// (the session id).
///
/// Lets a half-written prompt survive navigating away from a session and
/// back, or backgrounding the app — cases where the composer's
/// [PromptInput] state is disposed and recreated. Registered as a
/// lazy-singleton so it outlives any single session screen.
///
/// Intentionally lightweight: drafts live only for the current app run and
/// are not persisted across an app kill.
class DraftStore {
  final Map<String, String> _drafts = <String, String>{};

  /// The saved draft for [key], or the empty string if none.
  String read(String key) => _drafts[key] ?? "";

  /// Saves [text] as the draft for [key]. Whitespace-only (or empty) text
  /// clears the entry, so a blank composer never restores a useless draft.
  void write(String key, String text) {
    if (text.trim().isEmpty) {
      _drafts.remove(key);
    } else {
      _drafts[key] = text;
    }
  }

  /// Drops any saved draft for [key] (e.g. after the message is sent).
  void clear(String key) => _drafts.remove(key);
}
