import "dart:io" show Directory;

import "package:acp_plugin/acp_plugin.dart";
import "package:acp_plugin/acp_testing.dart";
import "package:omp_plugin/src/api/omp_acp_api.dart";
import "package:test/test.dart";

void main() {
  test("catalog lease launches with and removes its scratch session directory", () async {
    final parent = Directory.systemTemp.createTempSync("omp-api-test-");
    final fake = FakeAcpProcess();
    late AcpLaunchSpec launchSpec;
    final api = OmpAcpApi(
      binaryPath: "omp",
      processFactory: (spec) async {
        launchSpec = spec;
        return fake;
      },
      logTag: "omp-test",
      isolateSessionHistory: true,
      scratchParent: parent.path,
    );

    try {
      final opening = api.open(cwd: "/repo", timeout: const Duration(seconds: 2));
      final initialize = await _waitForFrame(fake: fake, method: AcpMethods.initialize);
      fake.emit({
        "jsonrpc": "2.0",
        "id": initialize["id"],
        "result": {
          "protocolVersion": 1,
          "agentCapabilities": <String, dynamic>{},
        },
      });
      await opening;

      expect(launchSpec.args, ["acp", "--session-dir", isA<String>()]);
      final scratch = Directory(launchSpec.args.last);
      expect(scratch.existsSync(), isTrue);

      await api.settle();
      expect(scratch.existsSync(), isFalse);
    } finally {
      await api.dispose();
      await fake.close();
      if (parent.existsSync()) parent.deleteSync(recursive: true);
    }
  });
}

Future<Map<String, dynamic>> _waitForFrame({
  required FakeAcpProcess fake,
  required String method,
}) async {
  for (var i = 0; i < 200; i++) {
    for (final frame in fake.written) {
      if (frame["method"] == method) return frame;
    }
    await Future<void>.delayed(const Duration(milliseconds: 5));
  }
  throw StateError("OMP never wrote '$method'");
}
