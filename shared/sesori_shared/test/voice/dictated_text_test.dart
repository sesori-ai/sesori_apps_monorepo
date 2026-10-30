import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("wraps the whole message in the marker the agent reads", () {
    expect(wrapDictatedText(text: "fix the parser"), '\u{1F399}\u{FE0F} "fix the parser"');
  });

  test("round trips words, quotes and whitespace exactly", () {
    for (final words in [
      "fix the parser",
      'rename "foo" to "bar"',
      '"quoted"',
      'ends with a quote"',
      "  spaced\n\nlines  ",
      "",
      wrapDictatedText(text: "already marked"),
    ]) {
      expect(unwrapDictatedText(text: wrapDictatedText(text: words)), words);
    }
  });

  test("leaves text that is not exactly marked unchanged", () {
    for (final text in [
      "fix the parser",
      '"fix the parser"',
      "",
      "\u{1F399}\u{FE0F}",
      '\u{1F399}\u{FE0F} "',
      "\u{1F399}\u{FE0F} fix the parser",
      '\u{1F399}\u{FE0F} "no closing quote',
      ' \u{1F399}\u{FE0F} "leading space"',
      '\u{1F399}\u{FE0F} "trailing space" ',
      'before \u{1F399}\u{FE0F} "words"',
    ]) {
      expect(unwrapDictatedText(text: text), text);
    }
  });
}
