import "package:sesori_plugin_interface/src/terminal_glyph_validator.dart";
import "package:test/test.dart";

void main() {
  group("TerminalGlyphValidator", () {
    test("supported for a UTF-8 LANG", () {
      expect(
        TerminalGlyphValidator.isSupported(environment: const {"LANG": "en_US.UTF-8"}),
        isTrue,
      );
    });

    test("supported for a 'utf8' spelling", () {
      expect(
        TerminalGlyphValidator.isSupported(environment: const {"LANG": "C.UTF8"}),
        isTrue,
      );
    });

    test("matched case-insensitively", () {
      expect(
        TerminalGlyphValidator.isSupported(environment: const {"LANG": "en_US.utf-8"}),
        isTrue,
      );
    });

    test("not supported for a non-UTF-8 locale", () {
      expect(
        TerminalGlyphValidator.isSupported(environment: const {"LANG": "POSIX"}),
        isFalse,
      );
    });

    test("not supported when no locale variable is set", () {
      expect(
        TerminalGlyphValidator.isSupported(environment: const {}),
        isFalse,
      );
    });

    test("LC_ALL takes precedence over LANG", () {
      expect(
        TerminalGlyphValidator.isSupported(
          environment: const {"LC_ALL": "C", "LANG": "en_US.UTF-8"},
        ),
        isFalse,
        reason: "LC_ALL wins, and a bare C locale is not UTF-8",
      );
    });

    test("LC_CTYPE takes precedence over LANG", () {
      expect(
        TerminalGlyphValidator.isSupported(
          environment: const {"LC_CTYPE": "en_US.UTF-8", "LANG": "POSIX"},
        ),
        isTrue,
      );
    });

    test("TERM=dumb forces ASCII even with a UTF-8 locale", () {
      expect(
        TerminalGlyphValidator.isSupported(
          environment: const {"TERM": "dumb", "LANG": "en_US.UTF-8"},
        ),
        isFalse,
      );
    });
  });
}
