import "dart:convert";
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:path/path.dart" as p;
import "package:test/test.dart";

void main() {
  group("CodexMetadataRepository", () {
    late Directory codexHome;
    late Directory launchProject;
    late Directory otherProject;

    setUp(() {
      codexHome = Directory.systemTemp.createTempSync("codex-home-meta-");
      launchProject = Directory.systemTemp.createTempSync("codex-launch-meta-");
      otherProject = Directory.systemTemp.createTempSync("codex-other-meta-");
    });

    tearDown(() {
      for (final dir in [codexHome, launchProject, otherProject]) {
        try {
          dir.deleteSync(recursive: true);
        } catch (_) {}
      }
    });

    CodexMetadataRepository newRepository() => CodexMetadataRepository(
      skillReader: CodexSkillReader(
        environment: {"CODEX_HOME": codexHome.path},
      ),
      rolloutReader: SessionRolloutReader(
        environment: {"CODEX_HOME": codexHome.path},
      ),
      configReader: CodexConfigReader(
        environment: {"CODEX_HOME": codexHome.path},
      ),
      launchDirectory: launchProject.path,
    );

    group("getCommands", () {
      test("scopes project-local skills to the selected project directory", () {
        _writeSkill(codexHome, "skills/shared/SKILL.md", name: "shared");
        _writeSkill(
          launchProject,
          ".codex/skills/launch-only/SKILL.md",
          name: "launch-only",
        );
        _writeSkill(
          otherProject,
          ".codex/skills/other-only/SKILL.md",
          name: "other-only",
        );

        final repository = newRepository();
        expect(
          repository
              .getCommands(projectId: launchProject.path)
              .map((c) => c.name)
              .toList(),
          equals(["launch-only", "shared"]),
        );
        expect(
          repository
              .getCommands(projectId: otherProject.path)
              .map((c) => c.name)
              .toList(),
          equals(["other-only", "shared"]),
        );
      });

      test("null projectId falls back to the launch directory", () {
        _writeSkill(
          launchProject,
          ".codex/skills/launch-only/SKILL.md",
          name: "launch-only",
        );

        final commands = newRepository().getCommands(projectId: null);
        expect(commands.map((c) => c.name).toList(), equals(["launch-only"]));
      });

      test("empty skill descriptions map to null", () {
        _writeSkill(
          launchProject,
          ".codex/skills/terse/SKILL.md",
          name: "terse",
          description: "",
        );

        final command = newRepository()
            .getCommands(projectId: launchProject.path)
            .single;
        expect(command.description, isNull);
      });
    });

    group("resolveModelDefaults", () {
      test("the selected project's own latest rollout wins over a newer rollout elsewhere", () {
        _writeRollout(
          codexHome,
          id: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
          timestamp: "2026-06-01T10:00:00Z",
          cwd: launchProject.path,
          modelProvider: "openai",
          model: "gpt-5.4-codex",
        );
        // Newer, but in a different derived project.
        _writeRollout(
          codexHome,
          id: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
          timestamp: "2026-06-02T10:00:00Z",
          cwd: otherProject.path,
          modelProvider: "anthropic",
          model: "claude-x",
        );

        final repository = newRepository();
        final launchDefaults =
            repository.resolveModelDefaults(projectId: launchProject.path);
        expect(launchDefaults.modelID, equals("gpt-5.4-codex"));
        expect(launchDefaults.providerID, equals("openai"));

        final otherDefaults =
            repository.resolveModelDefaults(projectId: otherProject.path);
        expect(otherDefaults.modelID, equals("claude-x"));
        expect(otherDefaults.providerID, equals("anthropic"));
      });

      test("a newer dedicated-worktree session inside the project tree wins the parent project's defaults", () {
        _writeRollout(
          codexHome,
          id: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
          timestamp: "2026-06-01T10:00:00Z",
          cwd: launchProject.path,
          modelProvider: "openai",
          model: "gpt-5.4-codex",
        );
        // The bridge runs dedicated-worktree sessions in a subdirectory of the
        // project while attributing them to the parent project.
        _writeRollout(
          codexHome,
          id: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
          timestamp: "2026-06-02T10:00:00Z",
          cwd: p.join(launchProject.path, ".worktrees", "feature-x"),
          modelProvider: "openai",
          model: "gpt-5.5",
        );

        final defaults = newRepository()
            .resolveModelDefaults(projectId: launchProject.path);
        expect(defaults.modelID, equals("gpt-5.5"));
      });

      test("a worktree session does not leak into an unrelated project's defaults", () {
        _writeRollout(
          codexHome,
          id: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
          timestamp: "2026-06-02T10:00:00Z",
          cwd: p.join(launchProject.path, ".worktrees", "feature-x"),
          modelProvider: "openai",
          model: "gpt-5.5",
        );

        final defaults = newRepository()
            .resolveModelDefaults(projectId: otherProject.path);
        expect(defaults.modelID, isNull);
        expect(defaults.providerID, equals("openai"));
      });

      test("a rollout without a cwd groups under the launch directory", () {
        _writeRollout(
          codexHome,
          id: "019a0000-1111-2222-3333-aaaaaaaaaaaa",
          timestamp: "2026-06-01T10:00:00Z",
          cwd: null,
          modelProvider: "openai",
          model: "gpt-5.4-codex",
        );

        final defaults = newRepository()
            .resolveModelDefaults(projectId: launchProject.path);
        expect(defaults.modelID, equals("gpt-5.4-codex"));
      });

      test("a project with no sessions falls back to config.toml", () {
        File(p.join(codexHome.path, "config.toml")).writeAsStringSync(
          'model = "gpt-5.5"\nmodel_provider = "azure"\n',
        );
        _writeRollout(
          codexHome,
          id: "019a0000-1111-2222-3333-bbbbbbbbbbbb",
          timestamp: "2026-06-02T10:00:00Z",
          cwd: otherProject.path,
          modelProvider: "anthropic",
          model: "claude-x",
        );

        final defaults = newRepository()
            .resolveModelDefaults(projectId: launchProject.path);
        expect(defaults.modelID, equals("gpt-5.5"));
        expect(defaults.providerID, equals("azure"));
      });

      test("no sessions and no config resolves to a null model and openai", () {
        final defaults = newRepository()
            .resolveModelDefaults(projectId: launchProject.path);
        expect(defaults.modelID, isNull);
        expect(defaults.providerID, equals("openai"));
      });
    });

    group("selectCatalogDefaultModel", () {
      test("the project-scoped model wins over the catalog default when in the catalog", () {
        final selected = newRepository().selectCatalogDefaultModel(
          scopedModelID: "gpt-5.4-mini",
          catalogModelIds: ["gpt-5.5", "gpt-5.4-mini"],
          catalogDefaultId: "gpt-5.5",
        );
        expect(selected, equals("gpt-5.4-mini"));
      });

      test("a scoped model missing from the catalog falls back to the catalog default", () {
        final selected = newRepository().selectCatalogDefaultModel(
          scopedModelID: "retired-model",
          catalogModelIds: ["gpt-5.5", "gpt-5.4-mini"],
          catalogDefaultId: "gpt-5.5",
        );
        expect(selected, equals("gpt-5.5"));
      });

      test("no scoped model and no catalog default falls back to the first catalog model", () {
        final selected = newRepository().selectCatalogDefaultModel(
          scopedModelID: null,
          catalogModelIds: ["gpt-5.5", "gpt-5.4-mini"],
          catalogDefaultId: null,
        );
        expect(selected, equals("gpt-5.5"));
      });

      test("an empty catalog resolves to null", () {
        final selected = newRepository().selectCatalogDefaultModel(
          scopedModelID: "gpt-5.5",
          catalogModelIds: const [],
          catalogDefaultId: null,
        );
        expect(selected, isNull);
      });
    });
  });
}

void _writeSkill(
  Directory root,
  String relPath, {
  required String name,
  String description = "A skill",
}) {
  final full = p.join(root.path, relPath);
  Directory(p.dirname(full)).createSync(recursive: true);
  File(full).writeAsStringSync(
    [
      "---",
      "name: $name",
      if (description.isNotEmpty) "description: $description",
      "---",
      "",
      "Body.",
    ].join("\n"),
  );
}

void _writeRollout(
  Directory codexHome, {
  required String id,
  required String timestamp,
  required String? cwd,
  required String modelProvider,
  required String model,
}) {
  final day = timestamp.substring(0, 10).replaceAll("-", "/");
  final stamp = timestamp.replaceAll(":", "-").substring(0, 19);
  final full = p.join(
    codexHome.path,
    "sessions/$day/rollout-$stamp-$id.jsonl",
  );
  Directory(p.dirname(full)).createSync(recursive: true);
  File(full).writeAsStringSync(
    "${jsonEncode({
      "type": "session_meta",
      "payload": {
        "id": id,
        "timestamp": timestamp,
        "cwd": ?cwd,
        "model_provider": modelProvider,
      },
    })}\n"
    "${jsonEncode({
      "type": "turn_context",
      "payload": {"model": model},
    })}\n",
  );
}
