import "dart:async";

import "package:fake_async/fake_async.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

class _MockSessionRepository() extends Mock implements SessionRepository;

TranscriptPromptEntry _loaded({required String id, required String text}) => TranscriptPromptOpener(
  messageId: id,
  text: text,
  source: TranscriptPromptLoaded(fullText: text),
  createdAt: null,
  dayKey: null,
  number: null,
);

TranscriptPromptEntry _unloaded({required String id, required int seq}) => TranscriptPromptOpener(
  messageId: id,
  text: null,
  source: TranscriptPromptUnloaded(seq: seq, preview: null),
  createdAt: null,
  dayKey: null,
  number: null,
);

/// An old prompt only the bridge can match, then a loaded one that matches.
TranscriptPromptList _prompts({required bool isIndexed}) => TranscriptPromptList(
  entries: [
    _unloaded(id: "old", seq: 1),
    _loaded(id: "new", text: "Deploy it"),
  ],
  isIndexed: isIndexed,
);

const _oldMatch = SessionPromptSearchMatch(
  messageId: "old",
  excerpt: SessionPromptExcerpt(before: "", match: "deploy", after: " again"),
);

({String ids, EarlierPromptSearch earlier})? _shown(PromptSearchState state) => switch (state) {
  PromptSearchIdle() => null,
  PromptSearchActive(:final matches, :final earlier) => (ids: matches.keys.join(","), earlier: earlier),
};

void main() {
  late _MockSessionRepository repository;

  setUp(() => repository = _MockSessionRepository());

  PromptSearchCubit cubitFor({required bool isIndexed}) => PromptSearchCubit(
    sessionRepository: repository,
    sessionId: "s1",
    prompts: _prompts(isIndexed: isIndexed),
  );

  void answer({required String query, required FutureOr<SessionPromptSearchResult> Function() result}) =>
      when(() => repository.searchPrompts(sessionId: "s1", query: query)).thenAnswer((_) => Future.value(result()));

  test("matches the listed prompts alone when the list is not the whole history", () {
    fakeAsync((async) {
      final cubit = cubitFor(isIndexed: false)..search(query: "deploy");
      async.elapse(const Duration(seconds: 1));

      expect(_shown(cubit.state), (ids: "new", earlier: EarlierPromptSearch.listedOnly));
      verifyZeroInteractions(repository);
    });
  });

  test("asks the bridge once typing pauses, says it searches only once it is slow, and joins its matches", () {
    fakeAsync((async) {
      final bridge = Completer<SessionPromptSearchResult>();
      answer(query: "deploy", result: () => bridge.future);
      final cubit = cubitFor(isIndexed: true)
        ..search(query: "dep")
        ..search(query: "deploy");

      expect(_shown(cubit.state), (ids: "new", earlier: EarlierPromptSearch.pending));
      async.elapse(const Duration(milliseconds: 249));
      verifyZeroInteractions(repository);
      async.elapse(const Duration(milliseconds: 1));
      verify(() => repository.searchPrompts(sessionId: "s1", query: "deploy")).called(1);
      async.elapse(const Duration(milliseconds: 149));
      expect(_shown(cubit.state)?.earlier, EarlierPromptSearch.pending);
      async.elapse(const Duration(milliseconds: 1));
      expect(_shown(cubit.state)?.earlier, EarlierPromptSearch.slow);

      bridge.complete(const SessionPromptSearchAvailable(matches: [_oldMatch]));
      async.flushMicrotasks();

      expect(_shown(cubit.state), (ids: "old,new", earlier: EarlierPromptSearch.done));
      verifyNoMoreInteractions(repository);
    });
  });

  test("drops an answer to a search the latest query replaced", () {
    fakeAsync((async) {
      final first = Completer<SessionPromptSearchResult>();
      answer(query: "deploy", result: () => first.future);
      answer(
        query: "it",
        result: () => const SessionPromptSearchAvailable(matches: []),
      );
      final cubit = cubitFor(isIndexed: true)..search(query: "deploy");
      async.elapse(const Duration(milliseconds: 250));

      cubit.search(query: "it");
      first.complete(const SessionPromptSearchAvailable(matches: [_oldMatch]));
      async.elapse(const Duration(milliseconds: 250));

      expect(_shown(cubit.state), (ids: "new", earlier: EarlierPromptSearch.done));
    });
  });

  test("a bridge that predates search leaves the listed prompts alone, and is not asked again", () {
    fakeAsync((async) {
      answer(query: "deploy", result: () => const SessionPromptSearchUnsupported());
      final cubit = cubitFor(isIndexed: true)..search(query: "deploy");
      async.elapse(const Duration(milliseconds: 250));

      expect(_shown(cubit.state), (ids: "new", earlier: EarlierPromptSearch.listedOnly));
      cubit.search(query: "it");
      async.elapse(const Duration(seconds: 1));
      verify(
        () => repository.searchPrompts(
          sessionId: "s1",
          query: any(named: "query"),
        ),
      ).called(1);
    });
  });

  test("a failure keeps the listed matches and Retry asks again", () {
    fakeAsync((async) {
      final results = <SessionPromptSearchResult>[
        SessionPromptSearchFailure(error: ApiError.generic()),
        const SessionPromptSearchAvailable(matches: [_oldMatch]),
      ];
      answer(query: "deploy", result: () => results.removeAt(0));
      final cubit = cubitFor(isIndexed: true)..search(query: "deploy");
      async.elapse(const Duration(milliseconds: 250));

      expect(_shown(cubit.state), (ids: "new", earlier: EarlierPromptSearch.failed));
      cubit.retry();
      expect(_shown(cubit.state)?.earlier, EarlierPromptSearch.pending);
      async.flushMicrotasks();

      expect(_shown(cubit.state), (ids: "old,new", earlier: EarlierPromptSearch.done));
    });
  });

  test("the prompt index arriving mid-search asks the bridge", () {
    fakeAsync((async) {
      answer(
        query: "deploy",
        result: () => const SessionPromptSearchAvailable(matches: [_oldMatch]),
      );
      final cubit = cubitFor(isIndexed: false)..search(query: "deploy");
      async.elapse(const Duration(milliseconds: 250));
      verifyZeroInteractions(repository);

      cubit.showPrompts(prompts: _prompts(isIndexed: true));
      expect(_shown(cubit.state)?.earlier, EarlierPromptSearch.pending);
      async.elapse(const Duration(milliseconds: 250));

      expect(_shown(cubit.state), (ids: "old,new", earlier: EarlierPromptSearch.done));
    });
  });

  test("a blank query is no search", () {
    final cubit = cubitFor(isIndexed: true)..search(query: "  ");

    expect(cubit.state, isA<PromptSearchIdle>().having((state) => state.query, "query", "  "));
  });
}
