import "package:codex_plugin/src/api/codex_app_server_api.dart";
import "package:codex_plugin/src/api/codex_rollout_api.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/codex_config_reader.dart";
import "package:codex_plugin/src/codex_metadata_repository.dart";
import "package:codex_plugin/src/models/codex_collaboration_mode.dart";
import "package:codex_plugin/src/repositories/codex_catalog_repository.dart";
import "package:codex_plugin/src/repositories/codex_message_repository.dart";
import "package:codex_plugin/src/repositories/codex_skill_repository.dart";
import "package:codex_plugin/src/repositories/codex_thread_repository.dart";
import "package:codex_plugin/src/repositories/models/codex_thread_record.dart";
import "package:codex_plugin/src/services/codex_session_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("detaching clears app-server loaded-thread state", () async {
    final service = _newService();
    final firstRepository = _StubThreadRepository();
    service.attachAppServerRepositories(
      threadRepository: firstRepository,
      skillRepository: _StubSkillRepository(),
    );
    await service.resumeThreadIfNeeded(threadId: "thread-id", force: false);

    service.detachAppServerRepositories();
    final secondRepository = _StubThreadRepository();
    service.attachAppServerRepositories(
      threadRepository: secondRepository,
      skillRepository: _StubSkillRepository(),
    );
    await service.resumeThreadIfNeeded(threadId: "thread-id", force: false);

    expect(firstRepository.resumeCount, 1);
    expect(secondRepository.resumeCount, 1);
  });

  test("getCommands always includes compact without duplicating an advertised command", () async {
    final service = _newService();
    final threadRepository = _StubThreadRepository();
    final skillRepository = _StubSkillRepository(
      commands: const [
        PluginCommand(
          name: "review",
          provider: null,
          source: PluginCommandSource.skill,
        ),
      ],
    );
    service.attachAppServerRepositories(
      threadRepository: threadRepository,
      skillRepository: skillRepository,
    );

    final commands = await service.getCommands(projectId: "/repo");
    expect(commands.map((command) => command.name), ["review", "compact"]);

    skillRepository.commands = const [
      PluginCommand(
        name: "compact",
        provider: null,
        source: PluginCommandSource.skill,
      ),
    ];
    final deduplicated = await service.getCommands(projectId: "/repo");
    expect(deduplicated.where((command) => command.name == "compact"), hasLength(1));
  });

  test("getCommands still exposes compact when skill discovery fails", () async {
    final service = _newService();
    service.attachAppServerRepositories(
      threadRepository: _StubThreadRepository(),
      skillRepository: _StubSkillRepository(error: StateError("skills unavailable")),
    );

    final commands = await service.getCommands(projectId: "/repo");

    expect(commands.map((command) => command.name), ["compact"]);
  });

  test("sendCommand invokes skills with dollar syntax and uses native compaction", () async {
    final service = _newService();
    final threadRepository = _StubThreadRepository();
    service.attachAppServerRepositories(
      threadRepository: threadRepository,
      skillRepository: _StubSkillRepository(),
    );

    await service.sendCommand(
      threadId: "thread-id",
      command: "review",
      arguments: "staged changes",
      model: "gpt-5.6",
      effort: "high",
      collaborationMode: CodexCollaborationMode.plan,
    );

    final input = threadRepository.lastParts.single as PluginPromptPartText;
    expect(input.text, r"$review staged changes");
    expect(threadRepository.lastModel, "gpt-5.6");
    expect(threadRepository.lastEffort, "high");

    await service.sendCommand(
      threadId: "thread-id",
      command: "compact",
      arguments: "",
      model: null,
      effort: null,
      collaborationMode: null,
    );
    expect(threadRepository.compactCount, 1);
  });
}

CodexSessionService _newService() {
  final rolloutApi = CodexRolloutApi(environment: const {});
  return CodexSessionService(
    catalogRepository: CodexCatalogRepository(rolloutApi: rolloutApi),
    messageRepository: CodexMessageRepository(rolloutApi: rolloutApi),
    metadataRepository: CodexMetadataRepository(
      configReader: CodexConfigReader(environment: const {}),
    ),
    launchDirectory: "/repo",
  );
}

class _StubSkillRepository extends CodexSkillRepository {
  _StubSkillRepository({this.commands = const [], this.error})
    : super(
        appServerApi: CodexAppServerApi(
          client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0"),
        ),
      );

  List<PluginCommand> commands;
  final Object? error;

  @override
  Future<List<PluginCommand>> listCommands({required String cwd}) async {
    final failure = error;
    if (failure != null) throw failure;
    return commands;
  }
}

class _StubThreadRepository extends CodexThreadRepository {
  _StubThreadRepository()
    : super(
        appServerApi: CodexAppServerApi(
          client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0"),
        ),
      );

  int resumeCount = 0;
  int compactCount = 0;
  List<PluginPromptPart> lastParts = const [];
  String? lastModel;
  String? lastEffort;

  @override
  Future<CodexThreadRecord> resumeThread({required String threadId}) async {
    resumeCount += 1;
    return CodexThreadRecord(
      id: threadId,
      name: null,
      directory: "/repo",
      createdAt: null,
      updatedAt: null,
      model: null,
      modelProvider: null,
    );
  }

  @override
  Future<bool> startTurn({
    required String threadId,
    required List<PluginPromptPart> parts,
    required String? model,
    required String? effort,
    required CodexCollaborationMode? collaborationMode,
  }) async {
    lastParts = parts;
    lastModel = model;
    lastEffort = effort;
    return true;
  }

  @override
  Future<void> compactThread({required String threadId}) async {
    compactCount += 1;
  }
}
