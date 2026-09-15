import "package:flutter/semantics.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/interactions/prego_tappable.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  for (final brightness in Brightness.values) {
    testWidgets("image preview matches Figma geometry and tokens in $brightness", (tester) async {
      final semantics = tester.ensureSemantics();
      final prego = brightness == Brightness.light ? PregoDesignSystem.light : PregoDesignSystem.dark;
      var removed = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [prego]),
          home: Scaffold(
            body: Center(
              child: PregoImageAttachmentPreview(
                image: const ColoredBox(color: Colors.red),
                imageLabel: "Photo.png",
                removeLabel: "Remove attachment",
                onRemove: () => removed = true,
              ),
            ),
          ),
        ),
      );
      final tile = tester.getRect(find.byType(PregoImageAttachmentPreview));
      expect(tile.size, const Size(52, 52));
      final clip = tester.widget<ClipRRect>(find.byType(ClipRRect).first);
      expect(clip.borderRadius, BorderRadius.circular(10));
      final border = tester.widget<DecoratedBox>(
        find.byWidgetPredicate((widget) => widget is DecoratedBox && widget.position == DecorationPosition.foreground),
      );
      expect((border.decoration as BoxDecoration).border, Border.all(color: prego.colors.borderSecondary));
      final badgeFinder = find.byWidgetPredicate(
        (widget) =>
            widget is Container &&
            widget.decoration is BoxDecoration &&
            (widget.decoration! as BoxDecoration).shape == BoxShape.circle,
      );
      final badge = tester.getRect(badgeFinder);
      expect(badge.size, const Size(14, 14));
      expect(badge.top - tile.top, 3);
      expect(tile.right - badge.right, 4);
      expect((tester.widget<Container>(badgeFinder).decoration! as BoxDecoration).color, prego.colors.bgSurface5);
      final icon = tester.widget<Icon>(find.byIcon(TablerRegular.x));
      expect(icon.size, 10);
      expect(icon.color, prego.colors.textPrimary);
      expect(tester.getSize(find.byType(PregoTappable)), const Size(44, 44));
      expect(
        tester.getSemantics(find.bySemanticsLabel("Photo.png")),
        matchesSemantics(label: "Photo.png", isImage: true),
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel("Remove attachment"))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      // Tap outside the tiny badge but inside its accessible target.
      await tester.tapAt(tile.topRight + const Offset(-30, 30));
      await tester.pumpAndSettle();
      expect(removed, isTrue);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  }

  testWidgets("many images scroll in one row and remain removable after shrinking", (tester) async {
    var count = 8;
    var removed = -1;
    Future<void> pump() => tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(extensions: [PregoDesignSystem.light]),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 240,
              child: PregoImageAttachmentStrip(
                children: [
                  for (var i = 0; i < count; i++)
                    PregoImageAttachmentPreview(
                      key: ValueKey(i),
                      image: const ColoredBox(color: Colors.red),
                      imageLabel: "Image $i",
                      removeLabel: "Remove $i",
                      onRemove: () => removed = i,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await pump();
    final strip = find.byType(PregoImageAttachmentStrip);
    expect(tester.getSize(strip), const Size(240, 52));
    expect(
      tester.getTopLeft(find.byKey(const ValueKey(1))).dx - tester.getTopLeft(find.byKey(const ValueKey(0))).dx,
      60,
    );
    final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
    expect(position.maxScrollExtent, 232);
    await tester.drag(strip, const Offset(-400, 0));
    await tester.pumpAndSettle();
    expect(position.pixels, position.maxScrollExtent);
    final lastRect = tester.getRect(find.byKey(const ValueKey(7)));
    expect(tester.getRect(strip).intersect(lastRect), lastRect);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey(7)), matching: find.byType(PregoTappable)));
    await tester.pumpAndSettle();
    expect(removed, 7);
    count = 2;
    await pump();
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
    expect(position.maxScrollExtent, 0);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey(1)), matching: find.byType(PregoTappable)));
    expect(removed, 1);
    expect(tester.getSize(strip).height, 52);
    expect(tester.takeException(), isNull);
  });
}
