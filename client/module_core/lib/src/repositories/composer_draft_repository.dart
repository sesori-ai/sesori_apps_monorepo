import "package:injectable/injectable.dart";

import "../api/storage/composer_draft_storage.dart";
import "../foundation/models/composer/composer_draft.dart";

@lazySingleton
class ComposerDraftRepository({required final ComposerDraftStorage _storage}) {
  /// The new-session composer's draft: one for every project, since the
  /// composer keeps what it holds when its project changes.
  static const String newSessionIdentity = "new-session";

  ComposerDraft readForSession({required String sessionId}) =>
      _storage.read(key: sessionId) ?? ComposerDraft.typed(text: "");

  ComposerDraft readForNewSession() => _storage.read(key: newSessionIdentity) ?? ComposerDraft.typed(text: "");

  void saveForSession({required String sessionId, required ComposerDraft draft}) {
    _save(key: sessionId, draft: draft);
  }

  void saveForNewSession({required ComposerDraft draft}) {
    _save(key: newSessionIdentity, draft: draft);
  }

  void clearForSession({required String sessionId}) => _storage.clear(key: sessionId);

  void clearForNewSession() => _storage.clear(key: newSessionIdentity);

  void _save({required String key, required ComposerDraft draft}) {
    if (draft.text.trim().isEmpty) {
      _storage.clear(key: key);
    } else {
      _storage.write(key: key, draft: draft);
    }
  }
}
