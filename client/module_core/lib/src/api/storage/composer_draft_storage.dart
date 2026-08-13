import "package:injectable/injectable.dart";

import "../../foundation/models/composer/composer_draft.dart";

/// Process-local storage boundary for unsent composer drafts.
@lazySingleton
class ComposerDraftStorage() {
  final Map<String, ComposerDraft> _drafts = <String, ComposerDraft>{};

  ComposerDraft? read({required String key}) => _drafts[key];

  void write({required String key, required ComposerDraft draft}) {
    _drafts[key] = draft;
  }

  void clear({required String key}) => _drafts.remove(key);
}
