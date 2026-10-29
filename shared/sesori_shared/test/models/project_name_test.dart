import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("a project's own name is its stored name, else its directory's, and No project has none", () {
    const named = ProjectSummary(id: "a", name: "Sesori", path: "/work/app", time: null);
    const unnamed = ProjectSummary(id: "b", name: null, path: "/work/app", time: null);
    const scratch = ProjectSummary(id: "c", name: "Renamed", path: "/s", time: null, kind: ProjectKind.scratch);
    expect(projectOwnName(project: named), "Sesori");
    expect(projectOwnName(project: unnamed), "app");
    expect(projectOwnName(project: scratch), isNull);
  });

  test("hostPathBasename returns the last folder for either separator", () {
    expect(hostPathBasename(path: "/Users/me/app"), "app");
    expect(hostPathBasename(path: r"C:\work\app"), "app");
  });

  test("hostPathBasename keeps a Windows drive root whole", () {
    expect(hostPathBasename(path: r"C:\"), r"C:\");
    expect(hostPathBasename(path: "C:/"), "C:/");
  });

  test("hostPathBasename keeps a colon-suffixed folder's name", () {
    expect(hostPathBasename(path: "/work/build:"), "build:");
  });
}
