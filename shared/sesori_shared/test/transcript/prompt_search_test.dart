import "dart:convert";

import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("a blank query searches for nothing, and any other matches literally and ignoring case", () {
    expect(promptSearchPattern(query: "  \n"), isNull);
    final pattern = promptSearchPattern(query: " a.B ");
    expect(pattern?.hasMatch("xA.bx"), isTrue);
    expect(pattern?.hasMatch("aXb"), isFalse);
  });

  test("an excerpt keeps one line around the match and marks a cut start", () {
    final text = "${"word " * 10}find\nthe   needle here";
    final match = RegExp("needle").firstMatch(text);
    expect(match, isNotNull);
    if (match == null) return;

    expect(
      promptExcerpt(text: text, match: match),
      const SessionPromptExcerpt(before: "…rd word word find the ", match: "needle", after: " here"),
    );
  });

  test("an excerpt never cuts an emoji in half", () {
    // Both cut points fall on the second half of an emoji.
    final text = "${"😀" * 20}xneedley${"😀" * 50}";
    final match = RegExp("needle").firstMatch(text);
    expect(match, isNotNull);
    if (match == null) return;
    final excerpt = promptExcerpt(text: text, match: match);
    for (final part in [excerpt.before, excerpt.after]) {
      expect(part.runes.where((rune) => rune >= 0xD800 && rune <= 0xDFFF), isEmpty);
    }
  });

  test("search matches round-trip on the wire", () {
    const response = SessionPromptSearchResponse(
      matches: [
        SessionPromptSearchMatch(
          messageId: "u1",
          excerpt: SessionPromptExcerpt(before: "the ", match: "build", after: " broke"),
        ),
      ],
    );

    final json = jsonDecode(jsonEncode(response.toJson())) as Map<String, dynamic>;

    expect(json, {
      "matches": [
        {
          "messageId": "u1",
          "excerpt": {"before": "the ", "match": "build", "after": " broke"},
        },
      ],
    });
    expect(SessionPromptSearchResponse.fromJson(json), response);
  });
}
