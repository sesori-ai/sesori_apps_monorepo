import "dart:convert";

import "package:sesori_bridge/src/api/git_tracked_files_api.dart";
import "package:sesori_bridge/src/foundation/streaming_process_runner.dart";
import "package:test/test.dart";

void main() {
  test("streams only the requested tracked-file prefix through the injected process boundary", () async {
    final process = _FakeStreamingProcess(
      stdoutChunks: [utf8.encode("a.dart\u0000b."), utf8.encode("dart\u0000c.dart\u0000")],
    );
    final runner = _FakeStreamingProcessRunner(process);
    final api = GitTrackedFilesApi(processRunner: runner);

    final paths = await api.listTrackedFiles(projectPath: "/project", maximumPaths: 2);

    expect(paths, ["a.dart", "b.dart"]);
    expect(runner.executable, "git");
    expect(runner.arguments, ["ls-files", "--cached", "-z", "--", "."]);
    expect(runner.workingDirectory, "/project");
    expect(runner.environment, const {"LC_ALL": "C"});
  });

  test("rejects a non-positive bound before starting the process", () async {
    final runner = _FakeStreamingProcessRunner(_FakeStreamingProcess(stdoutChunks: const []));
    final api = GitTrackedFilesApi(processRunner: runner);

    await expectLater(
      () => api.listTrackedFiles(projectPath: "/unused", maximumPaths: 0),
      throwsArgumentError,
    );

    expect(runner.runCount, 0);
  });
}

class _FakeStreamingProcessRunner(final StreamingProcess process) extends StreamingProcessRunner {
  int runCount = 0;
  String? executable;
  List<String>? arguments;
  String? workingDirectory;
  Map<String, String>? environment;

  @override
  Future<T> run<T>({
    required String executable,
    required List<String> arguments,
    required Future<T> Function({required StreamingProcess process}) operation,
    String? workingDirectory,
    Map<String, String>? environment,
    Duration timeout = const Duration(seconds: 15),
  }) {
    runCount++;
    this.executable = executable;
    this.arguments = arguments;
    this.workingDirectory = workingDirectory;
    this.environment = environment;
    return operation(process: process);
  }
}

class _FakeStreamingProcess({required final List<List<int>> stdoutChunks}) implements StreamingProcess {
  @override
  Stream<List<int>> get stdout => Stream.fromIterable(stdoutChunks);

  @override
  Stream<List<int>> get stderr => const Stream.empty();

  @override
  Future<int> get exitCode async => 0;

  @override
  bool kill() => true;
}
