import "package:sesori_bridge/src/bridge/runtime/runtime_provision_reporter.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("RuntimeProvisionReporter", () {
    test("emits nothing on the happy PATH case (resolving then ready, no work)", () {
      final buffer = StringBuffer();
      final reporter = RuntimeProvisionReporter(sink: buffer, interactive: false);

      reporter.report(const ProvisionResolving());
      reporter.report(const ProvisionReady(binaryPath: "opencode"));

      expect(buffer.toString(), isEmpty);
    });

    test("non-interactive download prints throttled percentage lines", () {
      final buffer = StringBuffer();
      final reporter = RuntimeProvisionReporter(sink: buffer, interactive: false);

      for (var pct = 0; pct <= 100; pct += 5) {
        reporter.report(ProvisionDownloading(receivedBytes: pct, totalBytes: 100));
      }

      final out = buffer.toString();
      expect(out, contains("0%"));
      expect(out, contains("100%"));
      expect(out, isNot(contains("\r")));
      // Throttled to ~10% steps rather than a line every 5%.
      expect("\n".allMatches(out).length, lessThan(15));
    });

    test("interactive download redraws a single bar with carriage returns", () {
      final buffer = StringBuffer();
      final reporter = RuntimeProvisionReporter(sink: buffer, interactive: true);

      reporter.report(const ProvisionDownloading(receivedBytes: 50, totalBytes: 100));
      reporter.report(const ProvisionDownloading(receivedBytes: 100, totalBytes: 100));
      reporter.report(const ProvisionExtracting());

      final out = buffer.toString();
      expect(out, contains("\r"));
      expect(out, contains("50%"));
      expect(out, contains("100%"));
      expect(out, contains("Extracting"));
    });

    test("renders notice, verifying, and a ready line after real work", () {
      final buffer = StringBuffer();
      final reporter = RuntimeProvisionReporter(sink: buffer, interactive: false);

      reporter.report(const ProvisionNotice(message: "using a managed runtime"));
      reporter.report(const ProvisionDownloading(receivedBytes: 1, totalBytes: 2));
      reporter.report(const ProvisionVerifying());
      reporter.report(const ProvisionReady(binaryPath: "/x/opencode"));

      final out = buffer.toString();
      expect(out, contains("using a managed runtime"));
      expect(out, contains("Verifying"));
      expect(out, contains("OpenCode runtime ready"));
    });

    test("renders a non-fatal failure line", () {
      final buffer = StringBuffer();
      final reporter = RuntimeProvisionReporter(sink: buffer, interactive: false);

      reporter.report(const ProvisionFailed(message: "network down"));

      expect(buffer.toString(), contains("network down"));
    });
  });
}
