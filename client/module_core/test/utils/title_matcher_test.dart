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
}
