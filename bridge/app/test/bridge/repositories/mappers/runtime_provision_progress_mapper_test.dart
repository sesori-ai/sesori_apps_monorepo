import "package:sesori_bridge/src/bridge/repositories/mappers/runtime_provision_progress_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("RuntimeProvisionProgressMapping.toControlProvisionProgress", () {
    test("resolving maps to the resolving wire variant", () {
      expect(
        const ProvisionResolving().toControlProvisionProgress(),
        equals(const ControlProvisionProgress.resolving()),
      );
    });

    test("downloading carries received/total bytes (fraction dropped)", () {
      expect(
        const ProvisionDownloading(receivedBytes: 512, totalBytes: 2048).toControlProvisionProgress(),
        equals(const ControlProvisionProgress.downloading(receivedBytes: 512, totalBytes: 2048)),
      );
    });

    test("downloading preserves a null total (indeterminate progress)", () {
      expect(
        const ProvisionDownloading(receivedBytes: 100, totalBytes: null).toControlProvisionProgress(),
        equals(const ControlProvisionProgress.downloading(receivedBytes: 100, totalBytes: null)),
      );
    });

    test("extracting maps to the extracting wire variant", () {
      expect(
        const ProvisionExtracting().toControlProvisionProgress(),
        equals(const ControlProvisionProgress.extracting()),
      );
    });

    test("verifying maps to the verifying wire variant", () {
      expect(
        const ProvisionVerifying().toControlProvisionProgress(),
        equals(const ControlProvisionProgress.verifying()),
      );
    });

    test("notice carries its message", () {
      expect(
        const ProvisionNotice(message: "using managed runtime").toControlProvisionProgress(),
        equals(const ControlProvisionProgress.notice(message: "using managed runtime")),
      );
    });

    test("ready carries the binary path", () {
      expect(
        const ProvisionReady(binaryPath: "/opt/opencode/bin/opencode").toControlProvisionProgress(),
        equals(const ControlProvisionProgress.ready(binaryPath: "/opt/opencode/bin/opencode")),
      );
    });

    test("failed carries its message", () {
      expect(
        const ProvisionFailed(message: "checksum mismatch").toControlProvisionProgress(),
        equals(const ControlProvisionProgress.failed(message: "checksum mismatch")),
      );
    });
  });
}
