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
}
