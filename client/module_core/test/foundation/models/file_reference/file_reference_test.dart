import "package:sesori_dart_core/src/foundation/models/file_reference/file_reference.dart";
import "package:test/test.dart";

const _directory = "/work/repo";

FileReference? _parse(String raw) => parseFileReference(raw: raw, sessionDirectory: _directory);

void main() {
  group("parseFileReference", () {
    test("keeps an absolute path", () {
      expect(_parse("/etc/app/config.yaml"), const FileReference(absolutePath: "/etc/app/config.yaml", line: null));
    });

    test("resolves a relative path against the session directory", () {
      expect(_parse("lib/main.dart"), const FileReference(absolutePath: "/work/repo/lib/main.dart", line: null));
      expect(_parse("./lib/main.dart"), const FileReference(absolutePath: "/work/repo/lib/main.dart", line: null));
      expect(_parse("../other/a.ts"), const FileReference(absolutePath: "/work/other/a.ts", line: null));
    });

    test("reads a :line and drops a :col", () {
      expect(_parse("lib/main.dart:42"), const FileReference(absolutePath: "/work/repo/lib/main.dart", line: 42));
      expect(_parse("/a/b.py:7:13"), const FileReference(absolutePath: "/a/b.py", line: 7));
    });

    test("accepts a file:// URI", () {
      expect(_parse("file:///Users/me/notes.md"), const FileReference(absolutePath: "/Users/me/notes.md", line: null));
    });

    test("trims surrounding whitespace", () {
      expect(_parse("  src/app.tsx  "), const FileReference(absolutePath: "/work/repo/src/app.tsx", line: null));
    });

    test("rejects text that is not a file path", () {
      for (final raw in [
        "foo()",
        "v1.2",
        "main.dart",
        "https://example.com/a/b.dart",
        "mailto:me@example.com",
        "lib/src",
        "1.2/3.4",
        "src/**/*.dart",
        "dart run tool/build.dart",
        "~/notes.md",
        "file://host/a/b.txt",
        "",
      ]) {
        expect(_parse(raw), isNull, reason: raw);
      }
    });

    test("names the file", () {
      expect(const FileReference(absolutePath: "/a/b/c.md", line: null).fileName, "c.md");
    });
  });

  group("looksLikeFileReference", () {
    test("matches paths before they are resolved", () {
      expect(looksLikeFileReference(raw: "lib/main.dart:3"), isTrue);
      expect(looksLikeFileReference(raw: "foo()"), isFalse);
    });
  });
}
