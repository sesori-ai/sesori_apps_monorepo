import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

class _MockChatInputModeStore extends Mock implements ChatInputModeStore {}

void main() {
  late _MockChatInputModeStore store;

  setUpAll(() => registerFallbackValue(ChatInputMode.voiceFirst));

  setUp(() {
    store = _MockChatInputModeStore();
    when(() => store.write(mode: any(named: "mode"))).thenAnswer((_) async {});
  });

  test("starts in the persisted mode handed to it", () {
    final cubit = ChatInputModeCubit(store: store, initialMode: ChatInputMode.textFirst);

    expect(cubit.state, ChatInputMode.textFirst);
  });

  test("select switches the composer and persists the choice", () async {
    final cubit = ChatInputModeCubit(store: store, initialMode: ChatInputMode.voiceFirst);

    await cubit.select(mode: ChatInputMode.textFirst);

    expect(cubit.state, ChatInputMode.textFirst);
    verify(() => store.write(mode: ChatInputMode.textFirst)).called(1);
  });

  test("re-selecting the current mode does not rewrite storage", () async {
    final cubit = ChatInputModeCubit(store: store, initialMode: ChatInputMode.voiceFirst);

    await cubit.select(mode: ChatInputMode.voiceFirst);

    verifyNever(() => store.write(mode: any(named: "mode")));
  });

  test("rapid re-selection serializes writes so the last choice persists last", () async {
    final firstWrite = Completer<void>();
    final writeStarts = <ChatInputMode>[];
    when(() => store.write(mode: any(named: "mode"))).thenAnswer((invocation) {
      final mode = invocation.namedArguments[#mode] as ChatInputMode;
      writeStarts.add(mode);
      return mode == ChatInputMode.textFirst ? firstWrite.future : Future<void>.value();
    });
    final cubit = ChatInputModeCubit(store: store, initialMode: ChatInputMode.voiceFirst);

    final first = cubit.select(mode: ChatInputMode.textFirst);
    final second = cubit.select(mode: ChatInputMode.voiceFirst);
    await Future<void>.delayed(Duration.zero);

    // The second write queues behind the slow first instead of overlapping it.
    expect(writeStarts, [ChatInputMode.textFirst]);

    firstWrite.complete();
    await Future.wait([first, second]);
    expect(writeStarts, [ChatInputMode.textFirst, ChatInputMode.voiceFirst]);
    expect(cubit.state, ChatInputMode.voiceFirst);
  });
}
