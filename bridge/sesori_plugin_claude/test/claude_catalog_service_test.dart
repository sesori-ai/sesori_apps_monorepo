import "dart:async";
import "dart:io";

import "package:claude_plugin/claude_plugin.dart";
import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/claude_stream_client_test_factory.dart";
import "support/fake_claude_process.dart";

void main() {
  group("ClaudeCatalogService", () {
    late Directory temporary;
    late String projectA;
    late String projectB;
    late String missingProject;
    late List<FakeClaudeProcess> spawned;
    late List<ClaudeLaunchSpec> specs;
    late ClaudeSessionProcessRepository processes;
    late ClaudeCatalogService service;

    setUp(() {
      temporary = Directory.systemTemp.createTempSync("claude-catalog-service-");
      projectA = p.join(temporary.path, "project-a");
      projectB = p.join(temporary.path, "project-b");
      missingProject = p.join(temporary.path, "deleted-project");
      final configDirectory = p.join(temporary.path, "config");
      _writeSkill(root: p.join(projectA, ".claude", "skills"), folder: "deploy", frontmatterName: "ship-it");
      _writeSkill(root: p.join(configDirectory, "skills"), folder: "user-skill", frontmatterName: null);
      spawned = [];
      specs = [];
      processes = ClaudeSessionProcessRepository(
        supportsMcpAuthentication: true,
        processFactory: (spec) async {
          if (spec.workingDirectory == missingProject) {
            throw PluginWorkingDirectoryMissingException(
              operation: "spawn Claude",
              path: spec.workingDirectory,
              cause: null,
            );
          }
          final process = FakeClaudeProcess();
          specs.add(spec);
          spawned.add(process);
          unawaited(
            _answerCatalogControls(
              process,
              commandNames: [
                "review",
                "user-skill",
                if (spec.workingDirectory == projectA) ...["project-command", "ship-it"],
              ],
            ),
          );
          return process;
        },
        binaryPath: "claude",
        environment: const {},
      );
      var probeCount = 0;
      service = ClaudeCatalogService(
        catalog: ClaudeBackendCatalogRepository(
          skills: ClaudeSkillsApi(environment: {"CLAUDE_CONFIG_DIR": configDirectory}),
        ),
        processes: processes,
        generateProbeSessionId: () => _probeSessionId(++probeCount),
        discoveryDirectory: "/tmp/claude-state",
      );
    });

    tearDown(() async {
      await processes.dispose();
      for (final process in spawned) {
        await process.close();
      }
      temporary.deleteSync(recursive: true);
    });

    test("discovers in the discovery directory without a project and reaps the probe", () async {
      final catalog = await service.getCatalog(directory: null, refresh: false);

      expect(catalog.providers.providers.single.models, hasLength(2));
      expect(specs.single.workingDirectory, "/tmp/claude-state");
      expect(_controlSubtypes(spawned.single), ["initialize"]);
      expect(spawned.single.killed, isTrue);
    });

    test("starts the probe with hooks and MCP servers off", () async {
      await service.getCatalog(directory: projectA, refresh: false);

      expect(specs.single.purpose, ClaudeProcessPurpose.catalogProbe);
      expect(specs.single.arguments, containsAllInOrder(ClaudeLaunchSpec.catalogProbeIsolationArguments));
    });

    test("probes each project in its own directory and lists only its own entries", () async {
      final first = await service.getCatalog(directory: projectA, refresh: false);
      final second = await service.getCatalog(directory: projectB, refresh: false);

      expect(specs.map((spec) => spec.workingDirectory), [projectA, projectB]);
      expect(first.commands.map((command) => command.name), containsAll(["project-command", "ship-it"]));
      expect(second.commands.map((command) => command.name), ["review", "user-skill"]);
    });

    test("lists a deleted project's options from the discovery directory", () async {
      final catalog = await service.getCatalog(directory: missingProject, refresh: false);

      expect(specs.single.workingDirectory, "/tmp/claude-state");
      expect(catalog.commands.map((command) => command.name), ["review", "user-skill"]);
    });

    test("labels the project's and the user's skills as skills", () async {
      final catalog = await service.getCatalog(directory: projectA, refresh: false);

      expect(
        {for (final command in catalog.commands) command.name: command.source},
        {
          "review": PluginCommandSource.command,
          "user-skill": PluginCommandSource.skill,
          "project-command": PluginCommandSource.command,
          "ship-it": PluginCommandSource.skill,
        },
      );
    });

    test("serves each directory's cached catalog without another probe", () async {
      await service.getCatalog(directory: projectA, refresh: false);
      await service.getCatalog(directory: projectB, refresh: false);
      await service.getCatalog(directory: projectA, refresh: false);

      expect(spawned, hasLength(2));
      expect(service.latest?.commands.map((command) => command.name), ["review", "user-skill"]);
    });

    test("refreshes models through a new probe while retaining commands", () async {
      await service.getCatalog(directory: null, refresh: false);
      final refreshed = await service.getCatalog(directory: null, refresh: true);

      expect(spawned, hasLength(2));
      expect(specs.map((spec) => spec.workingDirectory), everyElement("/tmp/claude-state"));
      expect(_controlSubtypes(spawned.last), contains("list_models"));
      expect(refreshed.providers.providers.single.models.single.id, "new");
      expect(refreshed.commands.first.name, "review");
      expect(spawned.last.killed, isTrue);
    });

    test("coalesces concurrent reads of one directory", () async {
      final first = service.getCatalog(directory: projectA, refresh: false);
      final second = service.getCatalog(directory: projectA, refresh: false);

      expect(await first, same(await second));
      expect(spawned, hasLength(1));
    });

    test("queues an explicit refresh behind an in-flight reuse discovery", () async {
      final reuse = service.getCatalog(directory: null, refresh: false);
      final refresh = service.getCatalog(directory: null, refresh: true);

      await reuse;
      final refreshed = await refresh;
      expect(spawned, hasLength(2));
      expect(_controlSubtypes(spawned.last), contains("list_models"));
      expect(refreshed.providers.providers.single.models.single.id, "new");
    });
  });

  group("ClaudeCatalogService fast-mode availability", () {
    late FakeClaudeProcess process;
    late ClaudeSessionProcessRepository processes;
    late ClaudeCatalogService service;

    ClaudeCatalogService serviceAnswering({required bool failOptIn}) {
      process = FakeClaudeProcess();
      processes = ClaudeSessionProcessRepository(
        supportsMcpAuthentication: true,
        processFactory: (_) async {
          unawaited(_answerFastModeProbe(process, failOptIn: failOptIn));
          return process;
        },
        binaryPath: "claude",
        environment: const {},
      );
      return ClaudeCatalogService(
        catalog: ClaudeBackendCatalogRepository(skills: ClaudeSkillsApi(environment: const {})),
        processes: processes,
        generateProbeSessionId: () => otherTestSessionId,
        discoveryDirectory: "/tmp/claude-state",
      );
    }

    tearDown(() async {
      await processes.dispose();
      await process.close();
    });

    test("opts the probe in and reports the account reason the SDK opt-in masked", () async {
      service = serviceAnswering(failOptIn: false);

      final catalog = await service.getCatalog(directory: null, refresh: false);

      expect(_controlSubtypes(process), ["initialize", "apply_flag_settings", "initialize"]);
      final optIn = process.written.firstWhere(
        (frame) => frame["type"] == "control_request" && _request(frame)["subtype"] == "apply_flag_settings",
      );
      expect(_request(optIn)["settings"], {"fastMode": true});
      expect(
        catalog.providers.providers.single.models.single.fastMode,
        const PluginFastModeSupport.unavailable(reason: PluginFastModeUnavailableReason.extraUsageDisabled),
      );
      expect(process.killed, isTrue);
    });

    test("keeps fast mode available when the opt-in fails", () async {
      service = serviceAnswering(failOptIn: true);

      final catalog = await service.getCatalog(directory: null, refresh: false);

      expect(_controlSubtypes(process), ["initialize", "apply_flag_settings"]);
      expect(
        catalog.providers.providers.single.models.single.fastMode,
        const PluginFastModeSupport.available(promptCacheTtlSeconds: 3600),
      );
    });
  });
}

String _probeSessionId(int index) => "00000000-0000-4000-8000-${index.toString().padLeft(12, "0")}";

void _writeSkill({required String root, required String folder, required String? frontmatterName}) {
  final file = File(p.join(root, folder, "SKILL.md"))..createSync(recursive: true);
  file.writeAsStringSync(
    [
      "---",
      if (frontmatterName case final name?) "name: $name",
      "description: Fixture skill",
      "---",
      "Say hi.",
    ].join("\n"),
  );
}

Future<void> _answerCatalogControls(FakeClaudeProcess process, {required List<String> commandNames}) async {
  final answered = <String>{};
  while (!process.killed) {
    for (final frame in process.written) {
      if (frame["type"] != "control_request") continue;
      final requestId = frame.field<String>("request_id");
      if (!answered.add(requestId)) continue;
      final subtype = _request(frame)["subtype"];
      process.emitControlResponse(
        requestId: requestId,
        payload: switch (subtype) {
          "initialize" => {
            ...sampleHandshake,
            "commands": [
              for (final name in commandNames) {"name": name, "description": "Fixture entry", "argumentHint": "[path]"},
            ],
          },
          "list_models" => {
            "models": [
              {"value": "new", "displayName": "New model"},
            ],
          },
          _ => const {},
        },
      );
    }
    await pump();
  }
}

Future<void> _answerFastModeProbe(FakeClaudeProcess process, {required bool failOptIn}) async {
  final answered = <String>{};
  var optedIn = false;
  while (!process.killed) {
    for (final frame in process.written) {
      if (frame["type"] != "control_request") continue;
      final requestId = frame.field<String>("request_id");
      if (!answered.add(requestId)) continue;
      switch (_request(frame)["subtype"]) {
        case "apply_flag_settings" when failOptIn:
          process.emitControlError(requestId: requestId, error: "rejected");
        case "apply_flag_settings":
          optedIn = true;
          process.emitControlResponse(requestId: requestId, payload: const {});
        case _:
          process.emitControlResponse(
            requestId: requestId,
            payload: {
              "models": [
                {"value": "opus", "supportsFastMode": true},
              ],
              "fast_mode_disabled_reason": optedIn ? "extra_usage_disabled" : "sdk_opt_in_required",
            },
          );
      }
    }
    await pump();
  }
}

Map<String, Object?> _request(Map<String, Object?> frame) => frame.field<Map<String, Object?>>("request");

Iterable<String?> _controlSubtypes(FakeClaudeProcess process) => process.written
    .where((frame) => frame["type"] == "control_request")
    .map((frame) => _request(frame)["subtype"] as String?);
