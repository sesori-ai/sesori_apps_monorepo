import "package:collection/collection.dart";
import "package:injectable/injectable.dart";
import "package:meta/meta.dart";

import "../foundation/models/product_analytics/product_analytics_event.dart";

@immutable
final class ComposerDraft {
  final String text;
  final List<bool> voiceOriginByCodeUnit;

  ComposerDraft({required this.text, required List<bool> voiceOriginByCodeUnit})
    : voiceOriginByCodeUnit = List.unmodifiable(voiceOriginByCodeUnit) {
    if (voiceOriginByCodeUnit.length != text.length) {
      throw ArgumentError.value(
        voiceOriginByCodeUnit,
        "voiceOriginByCodeUnit",
        "must contain one origin value per UTF-16 code unit",
      );
    }
  }

  AnalyticsInputMode get inputMode =>
      voiceOriginByCodeUnit.any((isVoice) => isVoice) ? AnalyticsInputMode.voiceAssisted : AnalyticsInputMode.typed;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ComposerDraft &&
          text == other.text &&
          const ListEquality<bool>().equals(voiceOriginByCodeUnit, other.voiceOriginByCodeUnit);

  @override
  int get hashCode => Object.hash(text, const ListEquality<bool>().hash(voiceOriginByCodeUnit));
}

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
  final Map<String, ComposerDraft> _drafts = <String, ComposerDraft>{};

  /// The saved draft for [key], or null when none exists.
  ComposerDraft? read({required String key}) => _drafts[key];

  /// Saves [draft] for [key]. Whitespace-only (or empty) text
  /// clears the entry, so a blank composer never restores a useless draft.
  void write({required String key, required ComposerDraft draft}) {
    if (draft.text.trim().isEmpty) {
      _drafts.remove(key);
    } else {
      _drafts[key] = draft;
    }
  }

  /// Drops any saved draft for [key] (e.g. after the message is sent).
  void clear({required String key}) => _drafts.remove(key);
}
