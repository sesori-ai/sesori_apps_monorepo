import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

ProjectSummary _project(String id, String path) => ProjectSummary(id: id, name: null, path: path, time: null);

Map<String, String> _labels(List<ProjectSummary> projects) =>
    projectPathLabels(projects: projects, nameOf: (project) => project.path.split(RegExp(r"[/\\]")).last);

void main() {
  test("a unique name keeps its last two folders", () {
    expect(_labels([_project("a", "/Users/me/work/app")]), {"a": "…/work/app"});
  });

  test("same-named projects grow until their paths differ", () {
    final labels = _labels([
      _project("a", "/Users/me/one/src/app"),
      _project("b", "/Users/me/two/src/app"),
      _project("c", "/Users/me/web"),
    ]);
    expect(labels, {"a": "…/one/src/app", "b": "…/two/src/app", "c": "…/me/web"});
  });

  test("a path shown whole keeps its root", () {
    expect(_labels([_project("a", "/app"), _project("b", "/work/app")]), {"a": "/app", "b": "/work/app"});
    expect(_labels([_project("a", r"C:\app"), _project("b", r"D:\app")]), {"a": "C:/app", "b": "D:/app"});
  });
}
