import "package:sesori_dart_core/src/api/storage/composer_draft_storage.dart";
import "package:sesori_dart_core/src/foundation/models/composer/composer_draft.dart";
import "package:sesori_dart_core/src/repositories/composer_draft_repository.dart";
import "package:test/test.dart";

void main() {
  late ComposerDraftRepository repository;

  setUp(() {
    repository = ComposerDraftRepository(storage: ComposerDraftStorage());
  });

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
}
