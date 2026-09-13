import "package:hermes_plugin/src/api/hermes_acp_api.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

const _sessionId = "catalog-session";
const _timeout = Duration(seconds: 2);
const _environment = {"HERMES_HOME": "/fixture/state"};

void main() {
  test("deletes the named persisted discovery session with its isolated environment", () async {
    final api = _api(
      result: const CommandResult(exitCode: 0, stdout: "Deleted session '$_sessionId'.\n", stderr: ""),
    );

    await api.deletePersistedSession(sessionId: _sessionId, timeout: _timeout);
  });

  test("an unpersisted discovery session completes cleanup", () async {
    final api = _api(
      result: const CommandResult(exitCode: 1, stdout: "Session '$_sessionId' not found.\n", stderr: ""),
    );

    await api.deletePersistedSession(sessionId: _sessionId, timeout: _timeout);
  });

  test("database failures retain both diagnostic streams", () async {
    final api = _api(
      result: const CommandResult(
        exitCode: 1,
        stdout: "Could not delete discovery session",
        stderr: "database is locked",
      ),
    );

    await expectLater(
      api.deletePersistedSession(sessionId: _sessionId, timeout: _timeout),
      throwsA(
        isA<PluginOperationException>()
            .having((error) => error.operation, "operation", "hermes sessions delete")
            .having((error) => error.message, "message", contains("database is locked"))
            .having((error) => error.message, "message", contains("Could not delete discovery session")),
      ),
    );
  });

  for (final result in [
    const CommandResult(exitCode: 2, stdout: "Session '$_sessionId' not found.", stderr: ""),
    const CommandResult(exitCode: 1, stdout: "Session 'different-session' not found.", stderr: ""),
    const CommandResult(exitCode: 1, stdout: "Session '$_sessionId' not found.", stderr: "database close failed"),
  ]) {
    test("only a clean not-found response for the requested session is accepted: $result", () async {
      final api = _api(result: result);

      await expectLater(
        api.deletePersistedSession(sessionId: _sessionId, timeout: _timeout),
        throwsA(isA<PluginOperationException>()),
      );
    });
  }
}

HermesAcpApi _api({required CommandResult result}) => HermesAcpApi(
  binaryPath: "/fixture/hermes",
  processFactory: (_) => throw StateError("Unexpected ACP process operation"),
  commandExecutor: _DeleteCommandExecutor(result: result),
  environment: _environment,
);

class _DeleteCommandExecutor({required final CommandResult result}) implements CommandExecutor {
  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    expect(executable, "/fixture/hermes");
    expect(arguments, ["sessions", "delete", _sessionId, "--yes"]);
    expect(environment, _environment);
    expect(timeout, _timeout);
    return result;
  }
}
