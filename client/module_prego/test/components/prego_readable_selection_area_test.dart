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
}

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
  selectionArea.selectableRegion.contextMenuButtonItems
      .singleWhere((item) => item.type == ContextMenuButtonType.copy)
      .onPressed!
      .call();
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
