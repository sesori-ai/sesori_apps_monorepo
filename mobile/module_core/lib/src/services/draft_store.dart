import "package:injectable/injectable.dart";

/// In-memory store for unsent composer drafts, keyed by a stable key — the
/// session id for an existing session, or `"new-session:<projectId>"` for the
/// not-yet-created session composer.
///
/// Lets a half-written prompt survive navigating away from a composer and
/// back, or backgrounding the app — cases where the composer widget's state
/// is disposed and recreated. A lazy-singleton so it outlives any single
/// session screen.
///
/// Intentionally lightweight: drafts live only for the current app run and
/// are not persisted across an app kill.
@lazySingleton
class DraftStore {
  final Map<String, String> _drafts = <String, String>{};

  /// The saved draft for [key], or the empty string if none.
  String read(String key) => _drafts[key] ?? "";

  /// Saves [text] as the draft for [key]. Whitespace-only (or empty) text
  /// clears the entry, so a blank composer never restores a useless draft.
  void write(String key, {required String text}) {
    if (text.trim().isEmpty) {
      _drafts.remove(key);
    } else {
      _drafts[key] = text;
    }
  }

  /// Drops any saved draft for [key] (e.g. after the message is sent).
  void clear(String key) => _drafts.remove(key);
}
