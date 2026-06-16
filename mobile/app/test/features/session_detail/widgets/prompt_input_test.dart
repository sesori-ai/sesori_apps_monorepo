import "dart:async";

import "package:flutter/material.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:get_it/get_it.dart";
import "package:mocktail/mocktail.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_mobile/capabilities/voice/voice_transcription_service.dart";
import "package:sesori_mobile/features/session_detail/widgets/prompt_input.dart";
import "package:sesori_mobile/l10n/app_localizations.dart";
import "package:theme_zyra/module_zyra.dart";

class MockVoiceTranscriptionService extends Mock implements VoiceTranscriptionService {}

class MockClipboardImageReader extends Mock implements ClipboardImageReader {}

/// A real, minimal 1x1 transparent PNG so the preview's `Image.memory` has valid
/// bytes to decode.
final _tinyPng = Uint8List.fromList([
  137, 80, 78, 71, 13, 10, 26, 10, //
  0, 0, 0, 13, 73, 72, 68, 82, //
  0, 0, 0, 1, 0, 0, 0, 1, //
  8, 6, 0, 0, 0, 31, 21, 196, 137, //
  0, 0, 0, 10, 73, 68, 65, 84, //
  120, 156, 99, 0, 1, 0, 0, 5, 0, 1, //
  13, 10, 45, 180, //
  0, 0, 0, 0, 73, 69, 78, 68, 174, 66, 96, 130,
]);

void main() {
  late MockVoiceTranscriptionService voice;
  late MockClipboardImageReader clipboard;
  late List<List<PickedMedia>> sentAttachments;

  setUp(() async {
    await GetIt.instance.reset();
    voice = MockVoiceTranscriptionService();
    clipboard = MockClipboardImageReader();
    sentAttachments = [];

    final maxDuration = StreamController<void>.broadcast();
    addTearDown(maxDuration.close);
    when(() => voice.onMaxDurationReached).thenAnswer((_) => maxDuration.stream);

    GetIt.instance.registerSingleton<VoiceTranscriptionService>(voice);
    GetIt.instance.registerSingleton<ClipboardImageReader>(clipboard);
  });

  tearDown(() async {
    await GetIt.instance.reset();
  });

  Widget buildApp() {
    return MaterialApp(
      theme: ThemeData(extensions: [ZyraDesignSystem.light]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: PromptInput(
          isBusy: false,
          onSend: (text, command, attachments) => sentAttachments.add(attachments),
          onAbort: () {},
          composerHeader: null,
          availableCommands: const [],
          stagedCommand: null,
          onCommandSelected: (_) {},
          onCommandCleared: () {},
        ),
      ),
    );
  }

  testWidgets("attaches a pasted image chosen from the attachment sheet", (tester) async {
    when(() => clipboard.readImage()).thenAnswer(
      (_) async => PickedMedia(bytes: _tinyPng, mimeType: "image/png", filename: "clipboard.png"),
    );

    await tester.pumpWidget(buildApp());

    await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Paste Image"));
    await tester.pumpAndSettle();

    // The attachment chip (with its remove button) is now in the composer.
    expect(find.byIcon(Icons.close), findsOneWidget);

    // Sending forwards the pasted attachment unchanged.
    await tester.tap(find.byIcon(Icons.send));
    await tester.pump();

    expect(sentAttachments, hasLength(1));
    expect(sentAttachments.single, hasLength(1));
    expect(sentAttachments.single.single.bytes, _tinyPng);
    verify(() => clipboard.readImage()).called(1);
  });

  testWidgets("warns when pasting from the sheet with no clipboard image", (tester) async {
    when(() => clipboard.readImage()).thenAnswer((_) async => null);

    await tester.pumpWidget(buildApp());

    await tester.tap(find.byIcon(Icons.add_photo_alternate_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Paste Image"));
    await tester.pump();

    expect(find.text("No image to paste from the clipboard"), findsOneWidget);
  });

  testWidgets("Cmd+V attaches a clipboard image", (tester) async {
    when(() => clipboard.readImage()).thenAnswer(
      (_) async => PickedMedia(bytes: _tinyPng, mimeType: "image/png", filename: "clipboard.png"),
    );

    await tester.pumpWidget(buildApp());

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.close), findsOneWidget);
    verify(() => clipboard.readImage()).called(1);
  });

  testWidgets("Cmd+V stays silent when the clipboard read fails (text paste path)", (tester) async {
    when(() => clipboard.readImage()).thenAnswer((_) async => throw const MediaPickerException("boom"));

    await tester.pumpWidget(buildApp());

    await tester.tap(find.byType(TextField));
    await tester.pump();

    await tester.sendKeyDownEvent(LogicalKeyboardKey.meta);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyV);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.meta);
    await tester.pumpAndSettle();

    // No attachment chip and no error toast — the keystroke may have been a
    // plain-text paste, so a clipboard failure must not nag the user.
    expect(find.byIcon(Icons.close), findsNothing);
    expect(find.text("Could not attach image. Please try again."), findsNothing);
  });
}
