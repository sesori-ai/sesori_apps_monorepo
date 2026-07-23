import "dart:async";
import "dart:convert";

import "package:codex_plugin/src/runtime/codex_model_catalog.dart";
import "package:path/path.dart" as p;
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  group("prepareCodexModelCatalog", () {
    test("stores a validated catalog rendered by the selected binary", () async {
      final executor = _FakeCommandExecutor(
        result: const CommandResult(
          exitCode: 0,
          stdout: '{"models":[{"slug":"gpt-test"}]}',
          stderr: "",
        ),
      );
      final store = _MemoryJsonStore();

      final path = await prepareCodexModelCatalog(
        commandExecutor: executor,
        store: store,
        stateDirectory: "/state/runtime",
        executablePath: "/managed/codex",
        environment: const {"CODEX_HOME": "/codex-home"},
        timeout: const Duration(seconds: 10),
      );

      expect(
        path,
        p.join("/state/runtime", codexModelCatalogFileName),
      );
      expect(executor.executable, "/managed/codex");
      expect(executor.arguments, const ["debug", "models", "--bundled"]);
      expect(executor.environment, const {"CODEX_HOME": "/codex-home"});
      expect(executor.timeout, const Duration(seconds: 10));
      expect(
        jsonDecode(store.files[codexModelCatalogFileName]!),
        {
          "models": [
            {"slug": "gpt-test"},
          ],
        },
      );
    });

    test("falls back without writing when catalog generation fails", () async {
      final store = _MemoryJsonStore();

      final path = await prepareCodexModelCatalog(
        commandExecutor: _FakeCommandExecutor(
          result: const CommandResult(
            exitCode: 2,
            stdout: "",
            stderr: "unsupported",
          ),
        ),
        store: store,
        stateDirectory: "/state/runtime",
        executablePath: "/custom/codex",
        environment: const {},
        timeout: const Duration(seconds: 10),
      );

      expect(path, isNull);
      expect(store.files, isEmpty);
    });

    test("rejects malformed or empty catalog output", () async {
      final store = _MemoryJsonStore();

      final path = await prepareCodexModelCatalog(
        commandExecutor: _FakeCommandExecutor(
          result: const CommandResult(
            exitCode: 0,
            stdout: '{"models":[]}',
            stderr: "",
          ),
        ),
        store: store,
        stateDirectory: "/state/runtime",
        executablePath: "/custom/codex",
        environment: const {},
        timeout: const Duration(seconds: 10),
      );

      expect(path, isNull);
      expect(store.files, isEmpty);
    });

    test("rejects non-object model entries", () async {
      final store = _MemoryJsonStore();

      final path = await prepareCodexModelCatalog(
        commandExecutor: _FakeCommandExecutor(
          result: const CommandResult(
            exitCode: 0,
            stdout: '{"models":[{"slug":"valid"},"invalid"]}',
            stderr: "",
          ),
        ),
        store: store,
        stateDirectory: "/state/runtime",
        executablePath: "/custom/codex",
        environment: const {},
        timeout: const Duration(seconds: 10),
      );

      expect(path, isNull);
      expect(store.files, isEmpty);
    });
  });
}

class _FakeCommandExecutor implements CommandExecutor {
  _FakeCommandExecutor({required this.result});

  final CommandResult result;
  String? executable;
  List<String>? arguments;
  Map<String, String>? environment;
  Duration? timeout;

  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async {
    this.executable = executable;
    this.arguments = arguments;
    this.environment = environment;
    this.timeout = timeout;
    return result;
  }
}

class _MemoryJsonStore implements HostJsonStore {
  final Map<String, String> files = {};

  @override
  Future<void> delete({required String name}) async {
    files.remove(name);
  }

  @override
  Future<void> quarantine({
    required String name,
    required String quarantinedName,
  }) async {
    final value = files.remove(name);
    if (value != null) files[quarantinedName] = value;
  }

  @override
  Future<String?> read({required String name}) async => files[name];

  @override
  Future<String?> update({
    required String name,
    required FutureOr<String?> Function(String? current) transform,
  }) async {
    final next = await transform(files[name]);
    if (next == null) {
      files.remove(name);
    } else {
      files[name] = next;
    }
    return next;
  }

  @override
  Future<void> write({
    required String name,
    required String contents,
  }) async {
    files[name] = contents;
  }
}
