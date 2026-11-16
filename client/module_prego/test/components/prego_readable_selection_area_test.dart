import "dart:ui" show PointerDeviceKind;

import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  testWidgets("copy uses one newline regardless of visual block spacing", (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PregoReadableSelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Heading"),
                SizedBox(height: 8),
                Text("First paragraph."),
                SizedBox(height: 8),
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: "Second "),
                      TextSpan(
                        text: "bold",
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      TextSpan(text: " paragraph."),
                    ],
                  ),
                ),
                SizedBox(height: 8),
                Row(mainAxisSize: MainAxisSize.min, children: [Text("•"), SizedBox(width: 8), Text("item one")]),
                SizedBox(height: 32),
                Row(mainAxisSize: MainAxisSize.min, children: [Text("•"), SizedBox(width: 8), Text("item two")]),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      await _copyAll(tester: tester),
      "Heading\nFirst paragraph.\nSecond bold paragraph.\n• item one\n• item two",
    );
  });

  testWidgets("preserves empty text blocks when requested", (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PregoReadableSelectionArea(
            preserveEmptyLines: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("first"),
                Text(PregoReadableSelectionArea.emptyLineMarker),
                Text("third"),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(await _copyAll(tester: tester), "first\n\nthird");
  });

  testWidgets("preserves a literal marker in source text", (tester) async {
    final encodedSource = PregoReadableSelectionArea.encodeText(
      text: PregoReadableSelectionArea.emptyLineMarker,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PregoReadableSelectionArea(
            preserveEmptyLines: true,
            child: Text(encodedSource),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(await _copyAll(tester: tester), PregoReadableSelectionArea.emptyLineMarker);
  });

  testWidgets("updates empty-line preservation when the widget changes", (tester) async {
    Widget buildArea({required bool preserveEmptyLines}) {
      return MaterialApp(
        home: Scaffold(
          body: PregoReadableSelectionArea(
            preserveEmptyLines: preserveEmptyLines,
            child: const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("first"),
                Text(PregoReadableSelectionArea.emptyLineMarker),
                Text("third"),
              ],
            ),
          ),
        ),
      );
    }

    await tester.pumpWidget(buildArea(preserveEmptyLines: false));
    await tester.pump();
    expect(await _copyAll(tester: tester), "first\nthird");

    await tester.pumpWidget(buildArea(preserveEmptyLines: true));
    await tester.pump();
    expect(await _copyAll(tester: tester), "first\n\nthird");
  });

  testWidgets("copy separates adjacent text on the same visual line", (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PregoReadableSelectionArea(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [Text("•"), SizedBox(width: 8), Text("item")],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(await _copyAll(tester: tester), "• item");
  });

  testWidgets("partial copy preserves a boundary between selected blocks", (tester) async {
    const firstKey = Key("first");
    const secondKey = Key("second");
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PregoReadableSelectionArea(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("First paragraph.", key: firstKey),
                SizedBox(height: 8),
                Text("Second paragraph.", key: secondKey),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final first = _renderParagraph(tester: tester, textKey: firstKey);
    final second = _renderParagraph(tester: tester, textKey: secondKey);
    final gesture = await tester.startGesture(
      _textPosition(paragraph: first, offset: 6),
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(_textPosition(paragraph: second, offset: 6));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    expect(await _copySelection(tester: tester), "paragraph.\nSecond");
  });

  testWidgets("a selection across nested areas paints as one continuous highlight", (tester) async {
    const firstKey = Key("first");
    const bulletKey = Key("bullet");
    const lastKey = Key("last");
    final moved = ChangeNotifier();
    addTearDown(moved.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PregoReadableSelectionArea(
            child: PregoNestedSelectionHighlight(
              moved: moved,
              child: const Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 400,
                      child: PregoReadableSelectionArea(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("First message.", key: firstKey),
                            SizedBox(height: 12),
                            Row(
                              children: [
                                Text("•", key: bulletKey),
                                SizedBox(width: 8),
                                Text("An item"),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    SizedBox(height: 40),
                    SizedBox(
                      width: 400,
                      child: PregoReadableSelectionArea(child: Text("Last message.", key: lastKey)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final first = _renderParagraph(tester: tester, textKey: firstKey);
    final last = _renderParagraph(tester: tester, textKey: lastKey);
    final gesture = await tester.startGesture(
      _textPosition(paragraph: first, offset: 6),
      kind: PointerDeviceKind.mouse,
    );
    addTearDown(gesture.removePointer);
    await tester.pump();
    await gesture.moveTo(_textPosition(paragraph: last, offset: 4));
    await tester.pump();
    await gesture.up();
    await tester.pump();

    // The text paints no boxes of its own, which would show as patches.
    for (final key in [firstKey, bulletKey, lastKey]) {
      expect(_renderParagraph(tester: tester, textKey: key).selectionColor?.a, 0);
    }

    final highlight = tester.renderObject<RenderBox>(find.byType(PregoNestedSelectionHighlight));
    Offset local(Offset global) => highlight.globalToLocal(global);
    final firstLine = _lineCenter(paragraph: first);
    final lastLine = _lineCenter(paragraph: last);
    final bullet = tester.getCenter(find.byKey(bulletKey));
    final gapBelowFirst = (tester.getBottomLeft(find.byKey(firstKey)).dy + bullet.dy) / 2;
    final gapBetweenAreas = tester.getTopLeft(find.byKey(lastKey)).dy - 20;
    final color = DefaultSelectionStyle.of(tester.element(find.byType(PregoNestedSelectionHighlight))).selectionColor;
    expect(
      highlight,
      paints..path(
        color: color,
        includes: [
          // The first line, from the start to the areas' far edge.
          local(Offset(_textPosition(paragraph: first, offset: 8).dx, firstLine.dy)),
          local(Offset(410, firstLine.dy)),
          // The gap between paragraphs, the bullet, and the gap between areas.
          local(Offset(30, gapBelowFirst)),
          local(bullet),
          local(Offset(400, gapBetweenAreas)),
          // The last line, from the near edge to the end.
          local(Offset(22, lastLine.dy)),
          local(Offset(_textPosition(paragraph: last, offset: 2).dx, lastLine.dy)),
        ],
        excludes: [
          local(Offset(22, firstLine.dy)),
          local(Offset(_textPosition(paragraph: last, offset: 8).dx, lastLine.dy)),
          local(Offset(10, gapBetweenAreas)),
          local(Offset(430, gapBetweenAreas)),
        ],
      ),
    );
    // Copying, which clears the selection on a phone, is as it was.
    expect(await _copySelection(tester: tester), "message.\n• An item\nLast");
  });
}

/// The middle of [paragraph]'s first line, in global coordinates.
Offset _lineCenter({required RenderParagraph paragraph}) =>
    paragraph.localToGlobal(Offset(0, paragraph.size.height / 2));

Future<String?> _copyAll({required WidgetTester tester}) async {
  final selectionArea = tester.state<SelectionAreaState>(find.byType(SelectionArea));
  selectionArea.selectableRegion.selectAll();
  await tester.pump();
  return await _copySelection(tester: tester);
}

Future<String?> _copySelection({required WidgetTester tester}) async {
  String? copiedText;
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
    if (call.method == "Clipboard.setData") {
      copiedText = (call.arguments as Map<Object?, Object?>)["text"] as String?;
    }
    return null;
  });
  addTearDown(() => messenger.setMockMethodCallHandler(SystemChannels.platform, null));

  final selectionArea = tester.state<SelectionAreaState>(find.byType(SelectionArea));
  final copy = selectionArea.selectableRegion.contextMenuButtonItems.singleWhere(
    (item) => item.type == ContextMenuButtonType.copy,
  );
  (copy.onPressed ?? fail("the copy menu item is disabled"))();
  await tester.pump();
  return copiedText;
}

RenderParagraph _renderParagraph({required WidgetTester tester, required Key textKey}) {
  return tester.renderObject<RenderParagraph>(
    find.descendant(of: find.byKey(textKey), matching: find.byType(RichText)),
  );
}

Offset _textPosition({required RenderParagraph paragraph, required int offset}) {
  const caret = Rect.fromLTWH(0, 0, 2, 20);
  return paragraph.localToGlobal(
        paragraph.getOffsetForCaret(TextPosition(offset: offset), caret) + Offset(0, paragraph.preferredLineHeight),
      ) +
      const Offset(0, -2);
}
