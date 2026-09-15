import "package:flutter/rendering.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/components/buttons/prego_buttons_solid.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  for (final brightness in Brightness.values) {
    testWidgets("queue shows a half-row scroll cue in $brightness", (tester) async {
      var removed = -1;
      Future<void> pump({required int count, required double scale}) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            extensions: [brightness == Brightness.light ? PregoDesignSystem.light : PregoDesignSystem.dark],
          ),
          home: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(scale)),
            child: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 358,
                  child: PregoQueuedMessageList(
                    rows: [
                      for (var i = 0; i < count; i++)
                        PregoQueuedMessageRow(
                          key: ValueKey(i),
                          preview: "Message $i with a very long preview\nand another line of content",
                          statusLabel: "Queued",
                          warning: null,
                          trailing: PregoButtonsSolid.iconOnly(
                            leadingIcon: TablerRegular.trash,
                            hierarchy: PregoButtonsSolidHierarchy.tertiary,
                            size: PregoButtonsSolidSize.sm,
                            onPressed: () => removed = i,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await pump(count: 3, scale: 1);
      expect(tester.getSize(find.byType(PregoQueuedMessageList)), const Size(358, 120));
      expect(tester.getSize(find.byType(PregoQueuedMessageRow).first).height, 40);
      final text = tester.widget<Text>(find.textContaining("Message 0"));
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(text.data, isNot(contains("\n")));
      final paragraph = tester.renderObject<RenderParagraph>(find.textContaining("Message 0"));
      expect(paragraph.didExceedMaxLines, isTrue);
      expect(tester.state<ScrollableState>(find.byType(Scrollable)).position.maxScrollExtent, 0);
      await tester.tap(find.byIcon(TablerRegular.trash).at(1));
      expect(removed, 1);
      await pump(count: 5, scale: 1);
      expect(tester.getSize(find.byType(PregoQueuedMessageList)).height, 140);
      expect(tester.state<ScrollableState>(find.byType(Scrollable)).position.maxScrollExtent, 60);
      final queueRect = tester.getRect(find.byType(PregoQueuedMessageList));
      final fourthRowRect = tester.getRect(find.byKey(const ValueKey(3)));
      expect(queueRect.intersect(fourthRowRect).height, 20);
      await tester.drag(find.byType(PregoQueuedMessageList), const Offset(0, -100));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byKey(const ValueKey(4)), matching: find.byIcon(TablerRegular.trash)));
      expect(removed, 4);
      await pump(count: 3, scale: 2);
      expect(tester.getSize(find.byType(PregoQueuedMessageList)).height, 156);
      await pump(count: 4, scale: 2);
      expect(tester.getSize(find.byType(PregoQueuedMessageList)).height, 182);
      expect(tester.state<ScrollableState>(find.byType(Scrollable)).position.maxScrollExtent, 26);
      expect(tester.takeException(), isNull);
    });
  }
}
