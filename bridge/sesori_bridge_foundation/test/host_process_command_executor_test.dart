import "dart:convert";
import "dart:io";

import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("caps captured output while continuing to drain both process streams", () async {
    final process = _FakeSpawnedProcess(
      stdoutChunks: [utf8.encode("12345"), utf8.encode("67890")],
      stderrChunks: [utf8.encode("abcde"), utf8.encode("fghij")],
    );
    final executor = HostProcessCommandExecutor(
      processes: _FakeHostProcessService(process: process),
      runInShell: false,
      maxCapturedOutputCharactersPerStream: 6,
    );

    final result = await executor.run("probe", const []);

    expect(result.stdout, "123456");
    expect(result.stderr, "abcdef");
    expect(process.stdoutChunksDelivered, 2);
    expect(process.stderrChunksDelivered, 2);
  });
}

class _FakeHostProcessService implements HostProcessService {
  const _FakeHostProcessService({required this.process});

  final SpawnedProcess process;

  @override
  Future<SpawnedProcess> spawn({
    required String executable,
    required List<String> arguments,
    required Map<String, String>? environment,
    required String? workingDirectory,
    required bool runInShell,
  }) async => process;

  @override
  Future<ProcessIdentity?> inspect({required int pid}) async => null;

  @override
  Future<SignalResult> signalForce({required int pid}) => throw UnsupportedError("not used");

  @override
  Future<SignalResult> signalGraceful({required int pid}) => throw UnsupportedError("not used");
}

class _FakeSpawnedProcess implements SpawnedProcess {
  _FakeSpawnedProcess({required this.stdoutChunks, required this.stderrChunks});

  final List<List<int>> stdoutChunks;
  final List<List<int>> stderrChunks;
  int stdoutChunksDelivered = 0;
  int stderrChunksDelivered = 0;

  @override
  Future<int> get exitCode => Future<int>.value(0);

  @override
  ProcessIdentity get identity => throw UnsupportedError("not used");

  @override
  int get pid => 42;

  @override
  Stream<List<int>> get stderr async* {
    for (final chunk in stderrChunks) {
      stderrChunksDelivered++;
      yield chunk;
    }
  }

  @override
  IOSink get stdin => throw UnsupportedError("not used");

  @override
  Stream<List<int>> get stdout async* {
    for (final chunk in stdoutChunks) {
      stdoutChunksDelivered++;
      yield chunk;
    }
  }
}
