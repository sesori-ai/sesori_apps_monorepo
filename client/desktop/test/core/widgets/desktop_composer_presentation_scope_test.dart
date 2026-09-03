import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_desktop/core/widgets/desktop_composer_presentation_scope.dart";

void main() {
  testWidgets("desktop composer is explicitly text-first with voice unavailable", (tester) async {
    ChatInputMode? inputMode;
    ComposerVoiceSupport? voiceSupport;

    await tester.pumpWidget(
      MaterialApp(
        home: DesktopComposerPresentationScope(
          child: Builder(
            builder: (context) {
              final scope = ComposerPresentationScope.of(context);
              inputMode = scope.inputMode;
              voiceSupport = scope.voiceSupport;
              return const SizedBox();
            },
          ),
        ),
      ),
    );

    expect(inputMode, ChatInputMode.textFirst);
    expect(voiceSupport, ComposerVoiceSupport.unsupported);
  });
}
