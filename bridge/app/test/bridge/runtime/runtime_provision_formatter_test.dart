import "package:sesori_bridge/src/bridge/runtime/runtime_provision_formatter.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  RuntimeProvisionFormatter build({required bool interactive}) =>
      RuntimeProvisionFormatter(interactive: interactive, runtimeName: "OpenCode");

  group("RuntimeProvisionFormatter", () {
    test("formats nothing on the happy PATH case (resolving then ready, no work)", () {
      final formatter = build(interactive: false);

      expect(formatter.format(const ProvisionResolving()), isNull);
      expect(formatter.format(const ProvisionReady(binaryPath: "opencode")), isNull);
    });

    test("uses the injected runtime name, not a hard-coded backend", () {
      final formatter = build(interactive: false);
      expect(formatter.format(const ProvisionVerifying()), contains("OpenCode"));
    });

    test("non-interactive download yields throttled percentage lines", () {
      final formatter = build(interactive: false);

      final lines = <String>[];
      for (var pct = 0; pct <= 100; pct += 5) {
        final out = formatter.format(ProvisionDownloading(receivedBytes: pct, totalBytes: 100));
        if (out != null) {
          lines.add(out);
        }
      }

      final out = lines.join();
      expect(out, contains("0%"));
      expect(out, contains("100%"));
      expect(out, isNot(contains("\r")));
      // Throttled to ~10% steps rather than a line every 5%.
      expect(lines.length, lessThan(15));
    });

    test("interactive download redraws a single bar with carriage returns", () {
      final formatter = build(interactive: true);

      final first = formatter.format(const ProvisionDownloading(receivedBytes: 50, totalBytes: 100));
      final second = formatter.format(const ProvisionDownloading(receivedBytes: 100, totalBytes: 100));
      final extracting = formatter.format(const ProvisionExtracting());

      expect(first, startsWith("\r"));
      expect(first, contains("50%"));
      expect(second, contains("100%"));
      // The next status line first closes the active bar with a newline.
      expect(extracting, startsWith("\n"));
      expect(extracting, contains("Extracting"));
    });

    test("formats notice, verifying, and a ready line after real work", () {
      final formatter = build(interactive: false);

      expect(formatter.format(const ProvisionNotice(message: "using a managed runtime")), contains("using a managed runtime"));
      formatter.format(const ProvisionDownloading(receivedBytes: 1, totalBytes: 2));
      expect(formatter.format(const ProvisionVerifying()), contains("Verifying"));
      expect(formatter.format(const ProvisionReady(binaryPath: "/x/opencode")), contains("runtime ready"));
    });

    test("formats a non-fatal failure line", () {
      final formatter = build(interactive: false);
      expect(formatter.format(const ProvisionFailed(message: "network down")), contains("network down"));
    });
  });
}
