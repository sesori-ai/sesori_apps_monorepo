import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:test/test.dart";

void main() {
  group("normalizeProjectDirectory", () {
    test("collapses a trailing separator", () {
      expect(
        normalizeProjectDirectory("/tmp/projects/alpha/"),
        normalizeProjectDirectory("/tmp/projects/alpha"),
      );
    });

    test("collapses `.` and `..` segments", () {
      expect(
        normalizeProjectDirectory("/tmp/projects/alpha/."),
        "/tmp/projects/alpha",
      );
      expect(
        normalizeProjectDirectory("/tmp/projects/beta/../alpha"),
        "/tmp/projects/alpha",
      );
    });

    test("leaves an already-canonical absolute path unchanged", () {
      expect(normalizeProjectDirectory("/tmp/projects/alpha"), "/tmp/projects/alpha");
    });
  });
}
