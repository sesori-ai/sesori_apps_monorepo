import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  for (final brightness in Brightness.values) {
    final prego = brightness == Brightness.light ? PregoDesignSystem.light : PregoDesignSystem.dark;

    for (final paneWidth in [402.0, 600.0]) {
      testWidgets("${brightness.name} user bubble fits a $paneWidth transcript pane", (tester) async {
        tester.view.physicalSize = const Size(1200, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        for (final outlined in [false, true]) {
          await tester.pumpWidget(
            _app(
              brightness: brightness,
              child: Center(
                child: SizedBox(
                  key: const Key("pane"),
                  width: paneWidth,
                  child: UserMessageBubble(
                    markdown:
                        "Search codebase for relevant files, checking type definitions and resolving import paths.",
                    attachments: const [],
                    outlined: outlined,
                    transitionDuration: Duration.zero,
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          final surface = tester.widget<AnimatedContainer>(find.byType(AnimatedContainer));
          final decoration = surface.decoration as BoxDecoration?;
          final foreground = surface.foregroundDecoration as BoxDecoration?;
          expect(decoration?.color, prego.colors.bgSurface2);
          expect(decoration?.borderRadius, BorderRadius.circular(12));
          expect(surface.padding, const EdgeInsets.all(10));
          expect(foreground?.borderRadius, decoration?.borderRadius);
          expect(
            foreground?.border?.top.color,
            prego.colors.borderBrand.withValues(alpha: outlined ? 0.55 : 0),
          );

          final bubbleRect = tester.getRect(
            find.byWidgetPredicate((widget) => widget is DecoratedBox && widget.decoration == decoration),
          );
          final paneRect = tester.getRect(find.byKey(const Key("pane")));
          expect(bubbleRect.width, closeTo((paneWidth - 32) * 0.76, 0.01));
          expect(bubbleRect.right, closeTo(paneRect.right - 16, 0.01));
          final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
          expect(markdown.styleSheet?.p?.color, prego.colors.textPrimary);
          expect(markdown.styleSheet?.p?.letterSpacing, 0.14);
          expect(tester.takeException(), isNull);
        }
      });
    }

    testWidgets("${brightness.name} assistant keeps chat typography while streaming and settled", (tester) async {
      for (final streaming in [true, false]) {
        await tester.pumpWidget(
          _app(
            brightness: brightness,
            child: TextPartWidget(
              text: "A **response** with a [link](https://example.com).\n\n- First item\n- Second item",
              isStreaming: streaming,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final markdown = tester.widget<MarkdownBody>(find.byType(MarkdownBody));
        final expected = buildChatMessageMarkdownStyleSheet(prego: prego);
        expect(markdown.styleSheet?.p, expected.p);
        expect(markdown.styleSheet?.listBullet, expected.listBullet);
        expect(markdown.styleSheet?.a, expected.a);
        expect(tester.takeException(), isNull);
      }
    });
  }
}

Widget _app({required Brightness brightness, required Widget child}) => MaterialApp(
  theme: buildPregoThemeData(brightness: brightness),
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);
