import "package:flutter_bloc/flutter_bloc.dart";
import "package:flutter_keyboard_visibility/flutter_keyboard_visibility.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:material_ui/material_ui.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/core/widgets/mobile_composer_presentation_scope.dart";

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() async {
    KeyboardVisibilityTesting.setVisibilityForTesting(false);
    await GetIt.instance.reset();
    GetIt.instance.registerSingleton<ComposerAttachmentDispatcher>(_MockComposerAttachmentDispatcher());
    GetIt.instance.registerSingleton<ImageClipboard>(_MockImageClipboard());
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  testWidgets("injects the modifier-enter mobile send policy", (tester) async {
    final cubit = _FakeChatInputModeCubit();
    addTearDown(cubit.close);
    ComposerSendKeyPolicy? sendKeyPolicy;

    await tester.pumpWidget(
      BlocProvider<ChatInputModeCubit>.value(
        value: cubit,
        child: MaterialApp(
          home: MobileComposerPresentationScope(
            child: Builder(
              builder: (context) {
                sendKeyPolicy = ComposerPresentationScope.of(context).sendKeyPolicy;
                return const SizedBox();
              },
            ),
          ),
        ),
      ),
    );

    expect(sendKeyPolicy, ComposerSendKeyPolicy.modifierEnterSends);
  });
}

class _MockComposerAttachmentDispatcher() extends Mock implements ComposerAttachmentDispatcher;

class _MockImageClipboard() extends Mock implements ImageClipboard;

class _FakeChatInputModeCubit() extends Cubit<ChatInputMode> implements ChatInputModeCubit {
  this : super(ChatInputMode.textFirst);

  @override
  Future<void> select({required ChatInputMode mode}) async => emit(mode);
}
