import "package:injectable/injectable.dart";

import "../foundation/models/page_draft.dart";

/// Unsent question-page drafts on this surface, keyed by request id. They live
/// in memory only, so closing and reopening a page keeps the user's picks
/// until the page settles or the app quits.
@lazySingleton
class PageDraftRepository() {
  final Map<String, PageDraft> _drafts = {};

  PageDraft? get({required String requestId}) => _drafts[requestId];

  void save({required String requestId, required PageDraft draft}) => _drafts[requestId] = draft;

  void remove({required String requestId}) => _drafts.remove(requestId);
}
