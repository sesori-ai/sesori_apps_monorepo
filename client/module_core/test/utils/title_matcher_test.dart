import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:test/test.dart";

void main() {
  List<TitleMatch<String?>> match(String query, List<String?> titles) =>
      matchTitles(items: titles, titleOf: (title) => title, query: query);

  test("a blank query keeps every item, untitled ones too, with no ranges", () {
    final matches = match("  ", ["Fix the build", null]);
    expect(matches.map((m) => m.item), ["Fix the build", null]);
    expect(matches.every((m) => m.ranges.isEmpty), isTrue);
  });

  test("matching ignores case and keeps the original order", () {
    final matches = match("BUILD", ["Fix the build", "Write docs", "Build the app", null]);
    expect(matches.map((m) => m.item), ["Fix the build", "Build the app"]);
    expect(matches.first.ranges, [(start: 8, end: 13)]);
  });

  test("every word must match, anywhere in the title, and ranges come sorted", () {
    final matches = match("build fix", ["Fix the build", "Fix the docs"]);
    expect(matches.map((m) => m.item), ["Fix the build"]);
    expect(matches.single.ranges, [(start: 0, end: 3), (start: 8, end: 13)]);
  });

  test("overlapping words merge into one range", () {
    expect(match("fix fixes", ["fixes"]).single.ranges, [(start: 0, end: 5)]);
  });
}
