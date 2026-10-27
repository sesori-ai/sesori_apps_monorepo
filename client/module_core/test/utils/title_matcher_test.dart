import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  List<String?> match(String query, List<String?> titles) =>
      matchTitles(items: titles, titleOf: (title) => title, query: query);

  test("a blank query keeps every item, untitled ones too", () {
    expect(match("  ", ["Fix the build", null]), ["Fix the build", null]);
  });

  test("matching ignores case and keeps the original order", () {
    expect(match("BUILD", ["Fix the build", "Write docs", "Build the app", null]), ["Fix the build", "Build the app"]);
  });

  test("every word must match, in any order", () {
    expect(match("build fix", ["Fix the build", "Fix the docs"]), ["Fix the build"]);
  });

  test("over several texts, each word may match a different one", () {
    final items = [("Fix the header", "sesori"), ("Fix the parser", "landing"), (null, "sesori")];
    List<(String?, String)> matchBoth(String query) =>
        matchTexts(items: items, textsOf: (item) => [item.$1, item.$2], query: query);
    expect(matchBoth("SESORI fix"), [items[0]]);
    expect(matchBoth("sesori"), [items[0], items[2]], reason: "a null text leaves the others to match");
    expect(matchBoth("sesori parser"), isEmpty);
  });

  test("match ranges cover every occurrence of each word, merged and sorted", () {
    expect(titleMatchRanges(title: "Fix the build", query: "BUILD fix"), [(start: 0, end: 3), (start: 8, end: 13)]);
    expect(titleMatchRanges(title: "aaa", query: "a"), [(start: 0, end: 3)]);
    expect(titleMatchRanges(title: "Build a builder", query: "build uild"), [(start: 0, end: 5), (start: 8, end: 13)]);
    expect(titleMatchRanges(title: "Fix the build", query: "  "), isEmpty);
  });
}
