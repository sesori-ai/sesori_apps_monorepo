import "dart:typed_data";

import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/storage/composer_draft_storage.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_attachment.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_draft.dart";
import "package:sesori_dart_core/src/foundation/models/composer/restored_composer.dart";
import "package:sesori_dart_core/src/repositories/composer_draft_repository.dart";
import "package:sesori_dart_core/src/testing/test_helpers.dart";
import "package:test/test.dart";

void main() {
  late FakeAuthSession authSession;
  late ComposerDraftRepository repository;

  setUp(() {
    authSession = FakeAuthSession(initialState: const AuthState.initial());
    repository = ComposerDraftRepository(storage: ComposerDraftStorage(), authSession: authSession);
  });

  tearDown(() => repository.dispose());

  test("restores exact mixed attribution for a session", () {
    final draft = ComposerDraft(
      text: "typed voice",
      voiceSpans: [VoiceOriginSpan(start: 6, end: 11)],
    );

    repository.saveForSession(sessionId: "session", draft: draft);

    expect(repository.readForSession(sessionId: "session"), draft);
  });

  test("isolates existing-session and new-session keys", () {
    repository.saveForSession(
      sessionId: "session",
      draft: ComposerDraft.typed(text: "existing"),
    );
    repository.saveForNewSession(draft: ComposerDraft.typed(text: "new"));

    expect(repository.readForSession(sessionId: "session").text, "existing");
    expect(repository.readForNewSession().text, "new");
  });

  test("whitespace-only save clears the stored draft and attribution", () {
    repository.saveForSession(
      sessionId: "session",
      draft: ComposerDraft(
        text: "voice",
        voiceSpans: [VoiceOriginSpan(start: 0, end: 5)],
      ),
    );

    repository.saveForSession(
      sessionId: "session",
      draft: ComposerDraft.typed(text: "  \n"),
    );

    expect(repository.readForSession(sessionId: "session"), ComposerDraft.typed(text: ""));
  });

  test("a handover saves the text and gives its attachments to the first reader only", () {
    final image = ComposerImageAttachment(mime: "image/png", bytes: Uint8List(3), filename: null);
    repository.handOverForSession(
      sessionId: "fork",
      restored: RestoredComposer(
        draft: ComposerDraft.typed(text: "again"),
        attachments: [image],
        leftOutCount: 0,
      ),
    );

    expect(repository.readForSession(sessionId: "fork").text, "again");
    expect(repository.takeHandedOverAttachments(sessionId: "fork"), [image]);
    expect(repository.takeHandedOverAttachments(sessionId: "fork"), isEmpty);
  });

  test("signing out drops every draft, so the next account's composer opens empty", () async {
    final image = ComposerImageAttachment(mime: "image/png", bytes: Uint8List(3), filename: null);
    repository.saveForSession(
      sessionId: "session",
      draft: ComposerDraft.typed(text: "existing"),
    );
    repository.saveForNewSession(draft: ComposerDraft.typed(text: "new"));
    repository.handOverForSession(
      sessionId: "fork",
      restored: RestoredComposer(
        draft: ComposerDraft.typed(text: "again"),
        attachments: [image],
        leftOutCount: 0,
      ),
    );
    repository.keepForNewSession(kept: (attachments: [image], commandName: "review"));

    authSession.emit(const AuthState.unauthenticated());
    await Future<void>.delayed(Duration.zero);

    expect(repository.readForSession(sessionId: "session").text, isEmpty);
    expect(repository.readForSession(sessionId: "fork").text, isEmpty);
    expect(repository.readForNewSession().text, isEmpty);
    expect(repository.takeHandedOverAttachments(sessionId: "fork"), isEmpty);
    final kept = repository.takeKeptForNewSession();
    expect(kept.attachments, isEmpty);
    expect(kept.commandName, isNull);
  });
}
