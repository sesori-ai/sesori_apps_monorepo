import "dart:io";

import "package:codex_plugin/src/api/codex_app_server_api.dart";
import "package:codex_plugin/src/api/codex_rollout_api.dart";
import "package:codex_plugin/src/api/codex_tool_outcome_storage.dart";
import "package:codex_plugin/src/api/models/codex_tool_outcome_dto.dart";
import "package:codex_plugin/src/codex_app_server_client.dart";
import "package:codex_plugin/src/codex_config_reader.dart";
import "package:codex_plugin/src/codex_metadata_repository.dart";
import "package:codex_plugin/src/models/codex_collaboration_mode.dart";
import "package:codex_plugin/src/models/codex_replay_tool_disposition.dart";
import "package:codex_plugin/src/repositories/codex_catalog_repository.dart";
import "package:codex_plugin/src/repositories/codex_message_repository.dart";
import "package:codex_plugin/src/repositories/codex_model_repository.dart";
import "package:codex_plugin/src/repositories/codex_skill_repository.dart";
import "package:codex_plugin/src/repositories/codex_thread_repository.dart";
import "package:codex_plugin/src/repositories/codex_tool_outcome_repository.dart";
import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_rollout_tool_mapper.dart";
import "package:codex_plugin/src/repositories/models/codex_thread_record.dart";
import "package:codex_plugin/src/services/codex_session_service.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/codex_plugin_test_factory.dart";

void main() {
  test("detaching clears app-server loaded-thread state", () async {
    final service = _newService();
    final firstRepository = _StubThreadRepository();
    service.attachAppServerRepositories(
      threadRepository: firstRepository,
      modelRepository: _StubModelRepository(),
      skillRepository: _StubSkillRepository(),
    );
    await service.resumeThreadIfNeeded(threadId: "thread-id", force: false);

    service.detachAppServerRepositories();
    final secondRepository = _StubThreadRepository();
    service.attachAppServerRepositories(
      threadRepository: secondRepository,
      modelRepository: _StubModelRepository(),
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
      modelRepository: _StubModelRepository(),
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
      modelRepository: _StubModelRepository(),
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
      modelRepository: _StubModelRepository(),
      skillRepository: _StubSkillRepository(),
    );

    final dispatched = await service.sendCommand(
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
    expect(dispatched.turnId, "turn");

    final compacted = await service.sendCommand(
      threadId: "thread-id",
      command: "compact",
      arguments: "",
      model: null,
      effort: null,
      collaborationMode: null,
    );
    expect(threadRepository.compactCount, 1);
    expect(compacted.turnId, isNull);
  });

  test("getSessionOptions uses one model catalog read for coherent agents and providers", () async {
    final service = _newService(
      metadataRepository: _StubMetadataRepository(
        defaults: const CodexConfigDefaults(
          model: "gpt-project",
          modelProvider: "azure",
        ),
      ),
    );
    final modelRepository = _StubModelRepository(
      catalog: (
        defaultModelID: "gpt-default",
        models: const [
          PluginModel(
            id: "gpt-default",
            name: "Default model",
            variants: [],
            family: null,
            isAvailable: true,
            releaseDate: null,
          ),
          PluginModel(
            id: "gpt-project",
            name: "Project model",
            variants: ["medium", "high"],
            family: null,
            isAvailable: true,
            releaseDate: null,
          ),
        ],
      ),
    );
    service.attachAppServerRepositories(
      threadRepository: _StubThreadRepository(),
      modelRepository: modelRepository,
      skillRepository: _StubSkillRepository(
        commands: const [
          PluginCommand(
            name: "review",
            provider: null,
            source: PluginCommandSource.skill,
          ),
        ],
      ),
    );

    final result = await service.getSessionOptions(projectId: "/repo");

    expect(modelRepository.listCount, 1);
    expect(result, isA<PluginSessionOptionsDiscoveryObserved>());
    final options = (result as PluginSessionOptionsDiscoveryObserved).options;
    expect(options.completeness, PluginSessionOptionsCompleteness.complete);
    expect(options.agents.map((agent) => agent.name), ["Default", "Plan"]);
    expect(
      options.agents.map((agent) => agent.model?.modelID),
      everyElement("gpt-project"),
    );
    final provider = options.providers.providers.single;
    expect(provider.id, "azure");
    expect(provider.name, "Azure OpenAI");
    expect(provider.defaultModelID, "gpt-project");
    expect(provider.models.map((model) => model.id), [
      "gpt-default",
      "gpt-project",
    ]);
    expect(options.commands.map((command) => command.name), [
      "review",
      "compact",
    ]);
  });

  test("model discovery failure retains the configured model fallback", () async {
    final service = _newService(
      metadataRepository: _StubMetadataRepository(
        defaults: const CodexConfigDefaults(
          model: "configured-model",
          modelProvider: "openai",
        ),
      ),
    );
    service.attachAppServerRepositories(
      threadRepository: _StubThreadRepository(),
      modelRepository: _StubModelRepository(
        error: StateError("models unavailable"),
      ),
      skillRepository: _StubSkillRepository(),
    );

    final providers = await service.getProviders(projectId: "/repo");

    final provider = providers.providers.single;
    expect(provider.defaultModelID, "configured-model");
    expect(provider.models.single.id, "configured-model");
    expect(provider.models.single.name, "configured-model");
  });

  test("aggregate marks model fallback partial and still lists models exactly once", () async {
    final service = _newService(
      metadataRepository: _StubMetadataRepository(
        defaults: const CodexConfigDefaults(
          model: "configured-model",
          modelProvider: "openai",
        ),
      ),
    );
    final modelRepository = _StubModelRepository(error: StateError("models unavailable"));
    service.attachAppServerRepositories(
      threadRepository: _StubThreadRepository(),
      modelRepository: modelRepository,
      skillRepository: _StubSkillRepository(),
    );

    final result = await service.getSessionOptions(projectId: "/repo");

    expect(modelRepository.listCount, 1);
    final options = (result as PluginSessionOptionsDiscoveryObserved).options;
    expect(options.completeness, PluginSessionOptionsCompleteness.partial);
    expect(options.providers.providers.single.defaultModelID, "configured-model");
    expect(options.commands.single.name, "compact");
  });

  test("aggregate marks the deliberate skill fallback partial", () async {
    final service = _newService();
    service.attachAppServerRepositories(
      threadRepository: _StubThreadRepository(),
      modelRepository: _StubModelRepository(),
      skillRepository: _StubSkillRepository(error: StateError("skills unavailable")),
    );

    final result = await service.getSessionOptions(projectId: "/repo");

    final options = (result as PluginSessionOptionsDiscoveryObserved).options;
    expect(options.completeness, PluginSessionOptionsCompleteness.partial);
    expect(options.commands.single.name, "compact");
  });

  test("deleting a session removes persisted structured tool errors", () async {
    final outcomes = createMemoryCodexToolOutcomeRepository();
    await outcomes.recordError(sessionId: "session-1", callId: "call-1");
    final service = _newService(toolOutcomeRepository: outcomes);

    await service.deleteSession(sessionId: "session-1");

    expect(await outcomes.readStatuses(sessionId: "session-1"), isEmpty);
  });

  test("keeps structured tool errors when session deletion fails", () async {
    final outcomes = createMemoryCodexToolOutcomeRepository();
    await outcomes.recordError(sessionId: "session-1", callId: "call-1");
    final service = _newService(
      catalogRepository: _DeleteFailingCatalogRepository(),
      toolOutcomeRepository: outcomes,
    );

    await service.deleteSession(sessionId: "session-1");

    expect(
      await outcomes.readStatuses(sessionId: "session-1"),
      {"call-1": PluginToolStatus.error},
    );
  });

  test("reads history without overlays when outcome storage fails", () async {
    final messageRepository = _RecordingMessageRepository();
    final service = _newService(
      catalogRepository: _FixedPathCatalogRepository(),
      messageRepository: messageRepository,
      toolOutcomeRepository: CodexToolOutcomeRepository(
        storage: _ReadFailingToolOutcomeStorage(),
      ),
    );

    expect(
      await service.getSessionMessages(
        sessionId: "session-1",
        sessionStatus: const PluginSessionStatus.idle(),
      ),
      isEmpty,
    );
    expect(messageRepository.statuses, isEmpty);
    expect(
      messageRepository.replayToolDisposition,
      CodexReplayToolDisposition.terminalize,
    );
  });

  test("preserves unfinished replay tools for active session states", () async {
    final messageRepository = _RecordingMessageRepository();
    final service = _newService(
      catalogRepository: _FixedPathCatalogRepository(),
      messageRepository: messageRepository,
    );

    for (final status in const [
      PluginSessionStatus.busy(),
      PluginSessionStatus.retry(attempt: 1, message: "retrying", next: 2),
    ]) {
      await service.getSessionMessages(
        sessionId: "session-1",
        sessionStatus: status,
      );
      expect(
        messageRepository.replayToolDisposition,
        CodexReplayToolDisposition.preserveRunning,
      );
    }
  });
}

CodexSessionService _newService({
  CodexCatalogRepository? catalogRepository,
  CodexMessageRepository? messageRepository,
  CodexMetadataRepository? metadataRepository,
  CodexToolOutcomeRepository? toolOutcomeRepository,
}) {
  final rolloutApi = CodexRolloutApi(environment: const {});
  return CodexSessionService(
    catalogRepository: catalogRepository ?? CodexCatalogRepository(rolloutApi: rolloutApi),
    messageRepository:
        messageRepository ??
        CodexMessageRepository(
          rolloutApi: rolloutApi,
          rolloutToolMapper: const CodexRolloutToolMapper(
            imageAttachmentMapper: CodexImageAttachmentMapper(),
          ),
        ),
    metadataRepository:
        metadataRepository ??
        CodexMetadataRepository(
          configReader: CodexConfigReader(environment: const {}),
        ),
    toolOutcomeRepository: toolOutcomeRepository ?? createMemoryCodexToolOutcomeRepository(),
    launchDirectory: "/repo",
  );
}

class _DeleteFailingCatalogRepository extends CodexCatalogRepository {
  _DeleteFailingCatalogRepository() : super(rolloutApi: CodexRolloutApi(environment: const {}));

  @override
  bool deleteSession({required String sessionId}) => false;
}

class _FixedPathCatalogRepository extends CodexCatalogRepository {
  _FixedPathCatalogRepository() : super(rolloutApi: CodexRolloutApi(environment: const {}));

  @override
  String? findRolloutPath({required String sessionId}) => "/rollout.jsonl";
}

class _RecordingMessageRepository extends CodexMessageRepository {
  _RecordingMessageRepository()
    : super(
        rolloutApi: CodexRolloutApi(environment: const {}),
        rolloutToolMapper: const CodexRolloutToolMapper(
          imageAttachmentMapper: CodexImageAttachmentMapper(),
        ),
      );

  Map<String, PluginToolStatus>? statuses;
  CodexReplayToolDisposition? replayToolDisposition;

  @override
  List<PluginMessageWithParts> readMessages({
    required String rolloutPath,
    required String sessionId,
    required CodexReplayToolDisposition replayToolDisposition,
    required Map<String, PluginToolStatus> structuredToolStatusByCallId,
    CodexConfigDefaults config = const CodexConfigDefaults.empty(),
  }) {
    statuses = structuredToolStatusByCallId;
    this.replayToolDisposition = replayToolDisposition;
    return const [];
  }
}

class _ReadFailingToolOutcomeStorage implements CodexToolOutcomeStorage {
  @override
  Future<List<CodexStoredToolErrorDto>> readErrors() {
    throw const FileSystemException("denied");
  }

  @override
  Future<void> updateErrors({
    required List<CodexStoredToolErrorDto> Function(
      List<CodexStoredToolErrorDto> current,
    )
    transform,
  }) async {}
}

class _StubMetadataRepository extends CodexMetadataRepository {
  _StubMetadataRepository({required this.defaults}) : super(configReader: CodexConfigReader(environment: const {}));

  final CodexConfigDefaults defaults;

  @override
  CodexConfigDefaults readConfigDefaults() => defaults;
}

class _StubModelRepository extends CodexModelRepository {
  _StubModelRepository({
    this.catalog = const (
      defaultModelID: null,
      models: <PluginModel>[],
    ),
    this.error,
  }) : super(
         appServerApi: CodexAppServerApi(
           client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0"),
         ),
       );

  final CodexModelCatalog catalog;
  final Object? error;
  int listCount = 0;

  @override
  Future<CodexModelCatalog> listModels() async {
    listCount += 1;
    final failure = error;
    if (failure != null) throw failure;
    return catalog;
  }
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
  Future<String?> startTurn({
    required String threadId,
    required List<PluginPromptPart> parts,
    required String? model,
    required String? effort,
    required CodexCollaborationMode? collaborationMode,
  }) async {
    lastParts = parts;
    lastModel = model;
    lastEffort = effort;
    return "turn";
  }

  @override
  Future<void> compactThread({required String threadId}) async {
    compactCount += 1;
  }
}
