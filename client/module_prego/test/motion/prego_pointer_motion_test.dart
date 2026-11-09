import "package:flutter/services.dart";
import "package:flutter_test/flutter_test.dart";
import "package:theme_prego/module_prego.dart";

void main() {
  testWidgets("a held modifier alone is still a click, and any other key is the keyboard", (tester) async {
    expect(pregoActivatedByKeyboard, isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    expect(pregoActivatedByKeyboard, isFalse);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyK);
    expect(pregoActivatedByKeyboard, isTrue);

    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyK);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    expect(pregoActivatedByKeyboard, isFalse);
  });
}
