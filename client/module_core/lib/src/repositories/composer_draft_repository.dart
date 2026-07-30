import "package:injectable/injectable.dart";

import "../api/storage/composer_draft_storage.dart";
import "../foundation/models/composer/composer_draft.dart";

@lazySingleton
class ComposerDraftRepository {
  final ComposerDraftStorage _storage;

  ComposerDraftRepository({required ComposerDraftStorage storage}) : _storage = storage;

  ComposerDraft readForSession({required String sessionId}) =>
      _storage.read(key: sessionId) ?? ComposerDraft.typed(text: "");

  ComposerDraft readForNewSession({required String projectId}) =>
      _storage.read(key: _newSessionKey(projectId: projectId)) ?? ComposerDraft.typed(text: "");

  void saveForSession({required String sessionId, required ComposerDraft draft}) {
    _save(key: sessionId, draft: draft);
  }

  void saveForNewSession({required String projectId, required ComposerDraft draft}) {
    _save(
      key: _newSessionKey(projectId: projectId),
      draft: draft,
    );
  }

  void clearForSession({required String sessionId}) => _storage.clear(key: sessionId);

  void clearForNewSession({required String projectId}) => _storage.clear(key: _newSessionKey(projectId: projectId));

  void _save({required String key, required ComposerDraft draft}) {
    if (draft.text.trim().isEmpty) {
      _storage.clear(key: key);
    } else {
      _storage.write(key: key, draft: draft);
    }
  }

  String _newSessionKey({required String projectId}) => "new-session:$projectId";
}
