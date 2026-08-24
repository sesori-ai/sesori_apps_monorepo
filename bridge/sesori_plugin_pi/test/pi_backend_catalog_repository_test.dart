import "dart:async";

import "package:path/path.dart" as path;
import "package:pi_plugin/pi_plugin.dart";
import "package:pi_plugin/pi_testing.dart";
import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("maps providers, deduped exact IDs, reasoning levels, and command sources", () async {
    final harness = _ProbeHarness(
      stateModel: _model(provider: "anthropic", id: "claude/team", name: "Claude Team", reasoning: true),
      models: [
        _model(provider: "custom/team", id: "model/v2", name: "Team", reasoning: false),
        _model(provider: "anthropic", id: "claude/team", name: "Claude Team", reasoning: true),
        _model(provider: "anthropic", id: "claude/team", name: "Duplicate", reasoning: true),
        _model(provider: "custom/team", id: "model/v2", name: "Duplicate", reasoning: false),
      ],
      thinking: const ["off", "max", "future", "max"],
      commands: const [
        {"name": "extension", "description": "Extension", "source": "extension"},
        {"name": "template", "source": "prompt-template"},
        {"name": "prompt", "source": "prompt"},
        {"name": "skill:review", "source": "skill"},
        {"name": "future", "source": "future"},
      ],
    );

    final options = await harness.probe();

    expect(harness.specs.single.arguments, ["--mode", "rpc", "--no-session", "--approve"]);
    expect(harness.specs.single.workingDirectory, path.normalize(path.absolute("project/./nested/..")));
    expect(options.completeness, PluginSessionOptionsCompleteness.complete);
    expect(options.agents.single.name, "pi");
    expect(options.agents.single.mode, PluginAgentMode.primary);
    expect(options.agents.single.hidden, isFalse);
    expect(options.agents.single.model, isNull);
    expect(options.providers.providers, hasLength(2));
    final anthropic = options.providers.providers.first;
    expect(anthropic, isA<PluginProviderAnthropic>());
    expect(anthropic.authType, PluginProviderAuthType.unknown);
    expect(anthropic.defaultModelID, "claude/team");
    expect(anthropic.models.single.id, "claude/team");
    expect(anthropic.models.single.variants, ["off", "max"]);
    final custom = options.providers.providers.last;
    expect(custom, isA<PluginProviderCustom>());
    expect(custom.id, "custom/team");
    expect(custom.models.single.id, "model/v2");
    expect(custom.models.single.variants, isEmpty);
    expect(harness.selected, [("anthropic", "claude/team")]);
    expect(options.commands.map((command) => command.source), [
      PluginCommandSource.command,
      PluginCommandSource.command,
      PluginCommandSource.command,
      PluginCommandSource.skill,
      PluginCommandSource.unknown,
    ]);
    expect(harness.processes.single.stdinClosed, isTrue);
    expect(harness.processes.single.killed, isTrue);
  });

  test("cancels every probe dialog and ignores notifications", () async {
    final harness = _ProbeHarness(
      stateModel: _model(provider: "openai", id: "gpt", reasoning: false),
      models: [_model(provider: "openai", id: "gpt", reasoning: false)],
      emitDialogs: true,
    );

    await harness.probe();

    final replies = harness.processes.single.written.where((frame) => frame["type"] == "extension_ui_response");
    expect(replies.map((frame) => frame["id"]), ["select", "confirm", "input", "editor"]);
    expect(replies.every((frame) => frame["cancelled"] == true), isTrue);
  });

  test("hydrates every advertised model and keeps large catalogs complete", () async {
    final models = [
      for (var index = 0; index < 101; index++) _model(provider: "google", id: "model-$index", reasoning: true),
    ];
    final harness = _ProbeHarness(
      stateModel: _model(provider: "google", id: "model-100", reasoning: true),
      models: models,
    );

    final options = await harness.probe();
    final discovered = options.providers.providers.single.models;

    expect(options.completeness, PluginSessionOptionsCompleteness.complete);
    expect(discovered, hasLength(models.length));
    expect(discovered.first.id, "model-100");
    expect(discovered.last.id, "model-99");
    expect(harness.selected, hasLength(models.length));
  });

  test("optional thinking and command failures preserve partial catalogs", () async {
    final thinkingFailure = _ProbeHarness(
      stateModel: _model(provider: "groq", id: "reasoner", reasoning: true),
      models: [_model(provider: "groq", id: "reasoner", reasoning: true)],
      failThinking: true,
    );
    final commandsFailure = _ProbeHarness(
      stateModel: _model(provider: "groq", id: "plain", reasoning: false),
      models: [_model(provider: "groq", id: "plain", reasoning: false)],
      failCommands: true,
    );

    final withoutThinking = await thinkingFailure.probe();
    final withoutCommands = await commandsFailure.probe();

    expect(withoutThinking.completeness, PluginSessionOptionsCompleteness.partial);
    expect(withoutThinking.providers.providers.single.models.single.variants, isEmpty);
    expect(withoutCommands.completeness, PluginSessionOptionsCompleteness.partial);
    expect(withoutCommands.commands, isEmpty);
  });

  test("thinking timeout preserves discovered models when command budget is exhausted", () async {
    final harness = _ProbeHarness(
      stateModel: _model(provider: "groq", id: "reasoner", reasoning: true),
      models: [_model(provider: "groq", id: "reasoner", reasoning: true)],
      ignoreThinking: true,
    );

    final options = await harness.probe(timeout: const Duration(milliseconds: 20));

    expect(options.completeness, PluginSessionOptionsCompleteness.partial);
    expect(options.providers.providers.single.models.single.id, "reasoner");
    expect(options.commands, isEmpty);
  });

  test("no model, auth-shaped empty catalog, process exit, and timeout fail with diagnostics", () async {
    final noModel = _ProbeHarness(stateModel: null, models: const []);
    final auth = _ProbeHarness(
      stateModel: _model(provider: "unknown", id: "unknown", reasoning: false),
      models: const [],
      stderr: PiRpcClient.noModelsDiagnosticPrefix,
    );
    final exited = _ProbeHarness(
      stateModel: _model(provider: "openai", id: "gpt", reasoning: false),
      models: const [],
      exitOnModels: true,
    );
    final timedOut = _ProbeHarness(
      stateModel: _model(provider: "openai", id: "gpt", reasoning: false),
      models: const [],
      ignoreModels: true,
    );

    await expectLater(noModel.probe(), throwsA(isA<PiCatalogProbeException>()));
    await expectLater(
      auth.probe(),
      throwsA(
        isA<PiCatalogProbeException>().having(
          (error) => error.stderrDiagnostics,
          "stderrDiagnostics",
          contains(PiRpcClient.noModelsDiagnosticPrefix),
        ),
      ),
    );
    await expectLater(
      exited.probe(),
      throwsA(
        isA<PiCatalogProbeException>().having(
          (error) => error.cause,
          "cause",
          isA<PiRpcProcessExitException>(),
        ),
      ),
    );
    await expectLater(
      timedOut.probe(timeout: const Duration(milliseconds: 20)),
      throwsA(
        isA<PiCatalogProbeException>().having((error) => error.cause, "cause", isA<TimeoutException>()),
      ),
    );
  });
}

Map<String, Object?> _model({
  required String provider,
  required String id,
  String? name,
  required bool reasoning,
}) => {
  "provider": provider,
  "id": id,
  "name": name,
  "reasoning": reasoning,
  "input": const ["text", "image"],
};

final class const _CommandExecutor() implements CommandExecutor {
  @override
  Future<CommandResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String>? environment,
    Duration? timeout,
  }) async => const CommandResult(exitCode: 0, stdout: "", stderr: "");
}

class _ProbeHarness({
  required final Map<String, Object?>? stateModel,
  required final List<Map<String, Object?>> models,
  final List<String> thinking = const ["off", "high"],
  final List<Map<String, Object?>> commands = const [],
  final bool emitDialogs = false,
  final bool failThinking = false,
  final bool ignoreThinking = false,
  final bool failCommands = false,
  final bool exitOnModels = false,
  final bool ignoreModels = false,
  final String? stderr,
}) {
  final List<PiLaunchSpec> specs = [];
  final List<FakePiProcess> processes = [];
  final List<(String, String)> selected = [];

  Future<PluginSessionOptions> probe({
    Duration timeout = const Duration(seconds: 2),
  }) async {
    final snapshot =
        await PiBackendCatalogRepository(
          binaryPath: "pi",
          environment: const {},
          processFactory: ({required spec}) async {
            specs.add(spec);
            final process = FakePiProcess();
            processes.add(process);
            if (stderr case final value?) scheduleMicrotask(() => process.emitStderrRaw(bytes: "$value\n".codeUnits));
            unawaited(_answer(process));
            return process;
          },
          commandExecutor: const _CommandExecutor(),
          healthTimeout: const Duration(seconds: 1),
        ).probe(
          projectId: path.normalize(path.absolute("project/./nested/..")),
          totalTimeout: timeout,
        );
    return PluginSessionOptions(
      agents: snapshot.agents,
      providers: snapshot.providers,
      commands: snapshot.commands,
      completeness: snapshot.complete
          ? PluginSessionOptionsCompleteness.complete
          : PluginSessionOptionsCompleteness.partial,
    );
  }

  Future<void> _answer(FakePiProcess process) async {
    final answered = <String>{};
    while (!process.stdinClosed && !process.killed) {
      for (final frame in process.written.toList()) {
        final id = frame["id"] as String?;
        if (id == null || !answered.add(id)) continue;
        final type = frame["type"] as String?;
        switch (type) {
          case "get_state":
            if (emitDialogs) _dialogs(process);
            process.emitResponse(
              id: id,
              command: type!,
              data: {if (stateModel != null) "model": stateModel},
            );
          case "get_available_models":
            if (exitOnModels) {
              process.exit(code: 7);
            } else if (!ignoreModels) {
              process.emitResponse(id: id, command: type!, data: {"models": models});
            }
          case "set_model":
            selected.add((frame["provider"]! as String, frame["modelId"]! as String));
            process.emitResponse(id: id, command: type!);
          case "get_available_thinking_levels":
            if (ignoreThinking) {
              continue;
            } else if (failThinking) {
              process.emitFailure(id: id, command: type!, error: "thinking unavailable");
            } else {
              process.emitResponse(id: id, command: type!, data: {"levels": thinking});
            }
          case "get_commands":
            if (failCommands) {
              process.emitFailure(id: id, command: type!, error: "commands unavailable");
            } else {
              process.emitResponse(id: id, command: type!, data: {"commands": commands});
            }
        }
      }
      await Future<void>.delayed(Duration.zero);
    }
  }

  void _dialogs(FakePiProcess process) {
    process.emit(
      frame: {
        "type": "extension_ui_request",
        "id": "select",
        "method": "select",
        "title": "Select",
        "options": ["one"],
      },
    );
    process.emit(
      frame: {
        "type": "extension_ui_request",
        "id": "confirm",
        "method": "confirm",
        "title": "Confirm",
        "message": "Continue?",
      },
    );
    process.emit(
      frame: {
        "type": "extension_ui_request",
        "id": "input",
        "method": "input",
        "title": "Input",
      },
    );
    process.emit(
      frame: {
        "type": "extension_ui_request",
        "id": "editor",
        "method": "editor",
        "title": "Editor",
      },
    );
    process.emit(
      frame: {
        "type": "extension_ui_request",
        "id": "notify",
        "method": "notify",
        "message": "Done",
      },
    );
  }
}
