import "package:flutter/services.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_app_ui/sesori_app_ui.dart";
import "package:sesori_app_ui/src/features/session_detail/file_preview/file_reference_code_syntax.dart";
import "package:sesori_app_ui/src/widgets/chat_link.dart";
import "package:theme_prego/module_prego.dart";

const _message =
    "PR https://github.com/acme/widgets/pull/12, site https://docs.flutter.dev/ui, "
    "[the guide](https://example.com/guide), code `lib/src/path.dart:12`, "
    "lock `lib/pubspec.lock` and [mail](mailto:team@example.com).";

void main() {
  late List<String> tapped;

  Future<void> pumpMessage({required WidgetTester tester}) async {
    tapped = [];
    void onTapLink(String text, String? href, String title) => tapped.add(href ?? "");
    final prego = PregoDesignSystem.light;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildPregoThemeData(brightness: Brightness.light),
        home: Scaffold(
          body: SelectionArea(
            child: MarkdownBody(
              data: _message,
              selectable: false,
              onTapLink: onTapLink,
              styleSheet: buildChatMessageMarkdownStyleSheet(prego: prego),
              inlineSyntaxes: sessionMarkdownInlineSyntaxes,
              builders: buildSessionMarkdownBuilders(highlightEnabled: false, copyTooltip: null, onTapLink: onTapLink),
            ),
          ),
        ),
      ),
    );
  }

  Finder link({required String label}) => find.byWidgetPredicate(
    (widget) => widget is ChatLink && widget.presentation.label == label,
    description: "ChatLink labelled $label",
  );

  testWidgets("each link shows its icon and short label in the link colour", (tester) async {
    await pumpMessage(tester: tester);

    final prego = PregoDesignSystem.light;
    expect(
      find.descendant(
        of: link(label: "widgets PR #12"),
        matching: find.byIcon(TablerRegular.brand_github),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: link(label: "docs.flutter.dev"),
        matching: find.byIcon(TablerRegular.world),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: link(label: "the guide"),
        matching: find.byIcon(TablerRegular.world),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: link(label: "path.dart (line 12)"),
        matching: find.text("DART"),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: link(label: "pubspec.lock"),
        matching: find.byIcon(TablerRegular.file),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: link(label: "mail"),
        matching: find.byType(Icon),
      ),
      findsNothing,
    );

    final chatLink = tester.widget<ChatLink>(link(label: "the guide"));
    expect(chatLink.style?.color, prego.colors.textBrandSecondary);
    expect(chatLink.style?.decoration, TextDecoration.none);
  });

  testWidgets("a tap opens the original target", (tester) async {
    await pumpMessage(tester: tester);

    await tester.tap(link(label: "widgets PR #12"));
    await tester.tap(link(label: "path.dart (line 12)"));
    expect(tapped, ["https://github.com/acme/widgets/pull/12", "lib/src/path.dart:12"]);
  });

  testWidgets("copying a selection copies the full targets", (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == "Clipboard.setData") copied = (call.arguments as Map<Object?, Object?>)["text"] as String?;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await pumpMessage(tester: tester);

    final region = tester.state<SelectableRegionState>(find.byType(SelectableRegion));
    region.selectAll(SelectionChangedCause.keyboard);
    await tester.pump();
    // ignore: deprecated_member_use, the direct way to run the region's copy action
    region.copySelection(SelectionChangedCause.keyboard);
    await tester.pump();

    expect(copied, contains("https://github.com/acme/widgets/pull/12"));
    expect(copied, contains("https://docs.flutter.dev/ui"));
    expect(copied, contains("https://example.com/guide"));
    expect(copied, contains("lib/src/path.dart:12"));
    expect(copied, isNot(contains("widgets PR #12")));
  });
}
