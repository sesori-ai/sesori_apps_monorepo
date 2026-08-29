import "dart:ui" show PointerDeviceKind;

import "package:flutter/rendering.dart";
import "package:flutter/services.dart";
import "package:flutter_markdown_plus/flutter_markdown_plus.dart";
import "package:flutter_test/flutter_test.dart";
import "package:material_ui/material_ui.dart";
import "package:sesori_mobile/core/widgets/readable_selection_area.dart";

void main() {
  testWidgets("copy preserves Markdown block and list boundaries", (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReadableSelectionArea(
            child: MarkdownBody(
              data: "# Heading\n\nFirst paragraph.\n\nSecond **bold** paragraph.\n\n- item one\n- item two",
              selectable: false,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(
      await _copyAll(tester: tester),
      "Heading\n\nFirst paragraph.\n\nSecond bold paragraph.\n\n• item one\n\n• item two",
    );
  });

  testWidgets("copy separates adjacent text on the same visual line", (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: ReadableSelectionArea(
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
          body: ReadableSelectionArea(
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

    expect(await _copySelection(tester: tester), "paragraph.\n\nSecond");
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
