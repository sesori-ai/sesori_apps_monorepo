import "dart:io";

import "package:sesori_bridge/src/foundation/bridge_startup_banner_formatter.dart";
import "package:test/test.dart";

void main() {
  group("BridgeStartupBannerFormatter", () {
    test("renders the installer wordmark and version for a capable terminal", () {
      final output = BridgeStartupBannerFormatter(
        out: _FakeStdout(hasTerminal: true, supportsAnsiEscapes: true, terminalColumns: 80),
        environment: const {"LANG": "en_US.UTF-8"},
      ).format(version: "1.8.0");

      expect(output, contains("███████╗███████╗███████╗"));
      expect(output, contains("\x1B[0;2m"));
      expect(output, contains("\x1B[38;5;39m\x1B[1mBRIDGE\x1B[0m"));
      expect(output, contains("v1.8.0  |  AI coding sessions on your phone"));
    });

    test("uses the ASCII wordmark when the locale is not UTF-8", () {
      final output = BridgeStartupBannerFormatter(
        out: _FakeStdout(hasTerminal: true, supportsAnsiEscapes: true, terminalColumns: 80),
        environment: const {"LANG": "C"},
      ).format(version: "1.8.0");

      expect(output, contains(" ____  _____ ____   ___  ____  ___"));
      expect(output, isNot(contains("███████╗")));
    });

    test("keeps the wordmark but omits ANSI when color is disabled", () {
      final output = BridgeStartupBannerFormatter(
        out: _FakeStdout(hasTerminal: true, supportsAnsiEscapes: true, terminalColumns: 80),
        environment: const {"LANG": "en_US.UTF-8", "NO_COLOR": ""},
      ).format(version: "1.8.0");

      expect(output, contains("███████╗███████╗███████╗"));
      expect(output, isNot(contains("\x1B[")));
    });

    test("uses compact ASCII output when the Unicode banner would wrap", () {
      final output = BridgeStartupBannerFormatter(
        out: _FakeStdout(hasTerminal: true, supportsAnsiEscapes: false, terminalColumns: 40),
        environment: const {"LANG": "en_US.UTF-8"},
      ).format(version: "1.8.0");

      expect(output, contains(" ____  _____ ____   ___  ____  ___"));
      expect(output, isNot(contains("███████╗")));
      expect(output, contains("BRIDGE v1.8.0"));
      expect(output, isNot(contains("AI coding sessions on your phone")));
      expect(output!.split("\n").every((line) => line.length <= 40), isTrue);
    });

    test("does not render into redirected output", () {
      final output = BridgeStartupBannerFormatter(
        out: _FakeStdout(hasTerminal: false, supportsAnsiEscapes: false, terminalColumns: 80),
        environment: const {"LANG": "en_US.UTF-8"},
      ).format(version: "1.8.0");

      expect(output, isNull);
    });
  });
}

class _FakeStdout({
  @override required final bool hasTerminal,
  @override required final bool supportsAnsiEscapes,
  @override required final int terminalColumns,
}) implements Stdout {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
