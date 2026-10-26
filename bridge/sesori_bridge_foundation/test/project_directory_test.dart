import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

void main() {
  group("normalizeProjectDirectory", () {
    test("collapses a trailing separator", () {
      expect(
        normalizeProjectDirectory(directory: "/tmp/projects/alpha/"),
        normalizeProjectDirectory(directory: "/tmp/projects/alpha"),
      );
    });

    test("collapses `.` and `..` segments", () {
      expect(
        normalizeProjectDirectory(directory: "/tmp/projects/alpha/."),
        "/tmp/projects/alpha",
      );
      expect(
        normalizeProjectDirectory(directory: "/tmp/projects/beta/../alpha"),
        "/tmp/projects/alpha",
      );
    });

    test("leaves an already-canonical absolute path unchanged", () {
      expect(normalizeProjectDirectory(directory: "/tmp/projects/alpha"), "/tmp/projects/alpha");
    });
  });

  group("normalizeProjectDirectoryWithContext", () {
    test("applies the same rule under the host path style", () {
      expect(
        normalizeProjectDirectoryWithContext(pathContext: p.context, directory: "/tmp/projects/beta/../alpha/"),
        normalizeProjectDirectory(directory: "/tmp/projects/beta/../alpha/"),
      );
    });

    test("normalizes Windows separators and segments under the Windows style", () {
      expect(
        normalizeProjectDirectoryWithContext(
          pathContext: p.Context(style: p.Style.windows),
          directory: r"C:/Users/Alex/.sesori\scratch\.\run\..\",
        ),
        r"C:\Users\Alex\.sesori\scratch",
      );
    });
  });
}
