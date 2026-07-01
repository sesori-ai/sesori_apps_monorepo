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
}
