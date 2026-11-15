import "package:flutter/gestures.dart" show PointerDeviceKind, kSecondaryButton;
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/widgets/transcript_message_menu.dart";
import "package:theme_prego/module_prego.dart";

const _text = "alpha beta gamma delta";
const _markdown = "**alpha** beta gamma delta";

void main() {
  late List<String?> copied;

  setUp(() => copied = []);

  Future<void> pumpMessage(WidgetTester tester, {required PregoInteractionMode mode}) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == "Clipboard.setData") {
        copied.add((call.arguments as Map<Object?, Object?>)["text"] as String?);
      }
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));

    await tester.pumpWidget(
      PregoInteractionScope(
        mode: mode,
        child: MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.only(top: 100),
              child: Align(
                alignment: Alignment.topLeft,
                child: TranscriptMessageMenu(
                  copyText: _markdown,
                  builder: (context, selectionArea) =>
                      PregoReadableSelectionArea(key: selectionArea, child: const Text(_text)),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    // The text registers with its selection area after the first frame.
    await tester.pump();
  }

  PregoReadableSelectionAreaState area(WidgetTester tester) =>
      tester.state<PregoReadableSelectionAreaState>(find.byType(PregoReadableSelectionArea));

  testWidgets("a long-press offers Copy, which copies the message's Markdown and says so", (tester) async {
    await pumpMessage(tester, mode: PregoInteractionMode.touch);

    await tester.longPress(find.text(_text));
    await tester.pumpAndSettle();
    expect(find.text("Select text"), findsOneWidget);

    await tester.tap(find.text("Copy"));
    await tester.pumpAndSettle();

    expect(copied, [_markdown]);
    expect(find.text("Copied to clipboard"), findsOneWidget);
    await tester.pumpAndSettle(PregoPopupAlertPresenter.defaultDuration);
  });

  testWidgets("Select text closes the menu and selects the message's text", (tester) async {
    await pumpMessage(tester, mode: PregoInteractionMode.touch);

    await tester.longPress(find.text(_text));
    await tester.pumpAndSettle();
    await tester.tap(find.text("Select text"));
    await tester.pumpAndSettle();

    expect(find.text("Select text"), findsNothing);
    expect(area(tester).selectedText, _text);
    // The selection's own toolbar takes over, as after a long-press selection.
    expect(find.byType(AdaptiveTextSelectionToolbar), findsOneWidget);
  });

  testWidgets(
    "a right-click on a selection copies just the selection",
    (tester) async {
      await pumpMessage(tester, mode: PregoInteractionMode.pointer);
      final start = tester.getTopLeft(find.text(_text)) + const Offset(1, 5);
      final drag = await tester.startGesture(start, kind: PointerDeviceKind.mouse);
      await tester.pump();
      await drag.moveTo(start + const Offset(60, 0));
      await drag.up();
      await tester.pumpAndSettle();
      final selected = area(tester).selectedText;
      expect(selected, isNotNull);
      expect(selected, isNot(_text));

      await tester.tapAt(tester.getCenter(find.text(_text)), buttons: kSecondaryButton, kind: PointerDeviceKind.mouse);
      await tester.pumpAndSettle();
      await tester.tap(find.text("Copy"));
      await tester.pumpAndSettle();

      expect(copied, [selected]);
      await tester.pumpAndSettle(PregoPopupAlertPresenter.defaultDuration);
    },
    variant: const TargetPlatformVariant({TargetPlatform.macOS}),
  );
}
