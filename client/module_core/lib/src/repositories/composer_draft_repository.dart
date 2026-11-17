import "dart:async";

import "package:injectable/injectable.dart";
import "package:sesori_auth/sesori_auth.dart";

import "../api/storage/composer_draft_storage.dart";
import "../foundation/models/composer/composer_attachment.dart";
import "../foundation/models/composer/composer_draft.dart";
import "../foundation/models/composer/restored_composer.dart";

/// What a new-session composer holds besides its text: the images and files it
/// staged, and the name of the command it staged.
typedef KeptNewSessionComposer = ({List<ComposerAttachment> attachments, String? commandName});

@lazySingleton
class ComposerDraftRepository({
  required final ComposerDraftStorage _storage,
  required final AuthSession _authSession,
}) {
  late final StreamSubscription<AuthState> _authStates;

  /// Attachments handed to sessions whose page has not opened yet; see
  /// [handOverForSession]. Their bytes are never persisted.
  final Map<String, List<ComposerAttachment>> _handedOverAttachments = {};

  /// See [keepForNewSession]. Like the attachments above, never persisted.
  KeptNewSessionComposer? _keptForNewSession;

  this {
    // Drafts belong to the account that typed them: signing out drops their
    // text, images and files, so the next account's composer never opens with
    // them.
    _authStates = _authSession.authStateStream.listen((state) {
      if (state is! AuthUnauthenticated) return;
      _storage.clearAll();
      _handedOverAttachments.clear();
      _keptForNewSession = null;
    });
  }

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

  /// Gives [sessionId]'s composer what [restored] holds, before its page
  /// opens: the text becomes its draft, and the attachments wait for
  /// [takeHandedOverAttachments], once.
  void handOverForSession({required String sessionId, required RestoredComposer restored}) {
    saveForSession(sessionId: sessionId, draft: restored.draft);
    if (restored.attachments.isNotEmpty) _handedOverAttachments[sessionId] = restored.attachments;
  }

  /// The attachments handed over to [sessionId], once; empty when none were.
  List<ComposerAttachment> takeHandedOverAttachments({required String sessionId}) =>
      _handedOverAttachments.remove(sessionId) ?? const [];

  void clearForNewSession() => _storage.clear(key: newSessionIdentity);

  /// Keeps what a new-session composer holds besides its text for the next
  /// new-session composer to [takeKeptForNewSession], when that composer goes
  /// away without anyone taking it over. Its text stays as the new-session
  /// draft already.
  void keepForNewSession({required KeptNewSessionComposer kept}) {
    _keptForNewSession = kept.attachments.isEmpty && kept.commandName == null ? null : kept;
  }

  /// What [keepForNewSession] kept, once; nothing when it kept nothing.
  KeptNewSessionComposer takeKeptForNewSession() {
    final kept = _keptForNewSession;
    _keptForNewSession = null;
    return kept ?? (attachments: const [], commandName: null);
  }

  void _save({required String key, required ComposerDraft draft}) {
    if (draft.text.trim().isEmpty) {
      _storage.clear(key: key);
    } else {
      _storage.write(key: key, draft: draft);
    }
  }

  @disposeMethod
  Future<void> dispose() => _authStates.cancel();
}
