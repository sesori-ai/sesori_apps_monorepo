import "dart:ui" as ui;

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
      var opened = false;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [prego]),
          home: Scaffold(
            body: Center(
              child: PregoImageAttachmentPreview(
                image: const ColoredBox(color: Colors.red),
                imageLabel: "Photo.png",
                onOpen: () => opened = true,
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
      expect(tester.getSize(find.byType(PregoTappable).last), const Size(24, 24));
      expect(
        tester.getSemantics(find.bySemanticsLabel("Photo.png")),
        matchesSemantics(label: "Photo.png", isImage: true, isButton: true, hasTapAction: true),
      );
      expect(
        tester
            .getSemantics(find.bySemanticsLabel("Remove attachment"))
            .getSemanticsData()
            .hasAction(SemanticsAction.tap),
        isTrue,
      );
      // Past the remove target, the tile opens the image instead.
      await tester.tapAt(tile.topRight + const Offset(-30, 30));
      await tester.pumpAndSettle();
      expect((opened, removed), (true, false));
      // Just outside the tiny badge but inside its target.
      await tester.tapAt(tile.topRight + const Offset(-21, 21));
      await tester.pumpAndSettle();
      expect(removed, isTrue);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));
  }

  for (final direction in TextDirection.values) {
    testWidgets("edge fades track both scroll directions and clear after removal in $direction", (tester) async {
      Future<void> pump({required int count}) => tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: [PregoDesignSystem.light]),
          home: Directionality(
            textDirection: direction,
            child: Center(
              child: SizedBox(
                width: 364,
                child: PregoImageAttachmentStrip(
                  children: [
                    for (var i = 0; i < count; i++)
                      PregoImageAttachmentPreview(
                        image: const ColoredBox(color: Colors.red),
                        imageLabel: "Image $i",
                        onOpen: () {},
                        removeLabel: "Remove $i",
                        onRemove: () {},
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      Future<List<int>> maskAlphas() async {
        final mask = tester.widget<ShaderMask>(find.byType(ShaderMask));
        final alphas = await tester.runAsync(() async {
          const bounds = Rect.fromLTWH(0, 0, 364, 52);
          final recorder = ui.PictureRecorder();
          Canvas(recorder).drawRect(bounds, Paint()..shader = mask.shaderCallback(bounds));
          final picture = recorder.endRecording();
          final image = await picture.toImage(364, 52);
          final pixels = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!;
          final result = [
            for (final x in [6, 182, 357]) pixels.getUint8((26 * 364 + x) * 4 + 3),
          ];
          image.dispose();
          picture.dispose();
          return direction == TextDirection.ltr ? result : result.reversed.toList();
        });
        return alphas!;
      }

      await pump(count: 12);
      final position = tester.state<ScrollableState>(find.byType(Scrollable)).position;
      expect(await maskAlphas(), [255, 255, lessThan(20)]);
      position.jumpTo(position.maxScrollExtent / 2);
      await tester.pump();
      expect(await maskAlphas(), [lessThan(20), 255, lessThan(20)]);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      expect(await maskAlphas(), [lessThan(20), 255, 255]);
      position.jumpTo(0);
      await tester.pump();
      expect(await maskAlphas(), [255, 255, lessThan(20)]);
      position.jumpTo(position.maxScrollExtent);
      await tester.pump();
      await pump(count: 2);
      await tester.pumpAndSettle();
      expect(await maskAlphas(), [255, 255, 255]);
      expect(tester.takeException(), isNull);
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
                      onOpen: () {},
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
    await tester.tap(find.descendant(of: find.byKey(const ValueKey(7)), matching: find.byType(PregoTappable)).last);
    await tester.pumpAndSettle();
    expect(removed, 7);
    count = 2;
    await pump();
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
    expect(position.maxScrollExtent, 0);
    await tester.tap(find.descendant(of: find.byKey(const ValueKey(1)), matching: find.byType(PregoTappable)).last);
    expect(removed, 1);
    expect(tester.getSize(strip).height, 52);
    expect(tester.takeException(), isNull);
  });
}
