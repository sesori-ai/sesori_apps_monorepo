import "dart:async";
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
import "package:codex_plugin/src/repositories/codex_sub_agent_tracker.dart";
import "package:codex_plugin/src/repositories/codex_thread_repository.dart";
import "package:codex_plugin/src/repositories/codex_tool_outcome_repository.dart";
import "package:codex_plugin/src/repositories/mappers/codex_image_attachment_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_rollout_tool_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_session_mapper.dart";
import "package:codex_plugin/src/repositories/mappers/codex_user_content_mapper.dart";
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
      clientUserMessageId: "prm_1",
      model: "gpt-5.6",
      effort: "high",
      collaborationMode: CodexCollaborationMode.plan,
    );

    final input = threadRepository.lastParts.single as PluginPromptPartText;
    expect(input.text, r"$review staged changes");
    expect(threadRepository.lastModel, "gpt-5.6");
    expect(threadRepository.lastEffort, "high");
    expect(threadRepository.lastClientUserMessageId, "prm_1");
    expect(dispatched.turnId, "turn");

    final compacted = await service.sendCommand(
      threadId: "thread-id",
      command: "compact",
      arguments: "",
      clientUserMessageId: "prm_2",
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
    expect(options.agents.map((agent) => agent.name), ["Agent", "Plan"]);
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

    await service.deleteSessionSubtree(sessionIds: const ["session-1"]);

    expect(await outcomes.readStatuses(sessionId: "session-1"), isEmpty);
  });

  test("keeps structured tool errors when session deletion fails", () async {
    final outcomes = createMemoryCodexToolOutcomeRepository();
    await outcomes.recordError(sessionId: "session-1", callId: "call-1");
    final service = _newService(
      catalogRepository: _DeleteFailingCatalogRepository(),
      toolOutcomeRepository: outcomes,
    );

    await service.deleteSessionSubtree(sessionIds: const ["session-1"]);

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
      service.getSessionMessages(
        sessionId: "session-1",
        read: (await service.prepareSessionMessageRead(sessionId: "session-1"))!,
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
    final read = await service.prepareSessionMessageRead(
      sessionId: "session-1",
    );

    for (final status in const [
      PluginSessionStatus.busy(),
      PluginSessionStatus.retry(attempt: 1, message: "retrying", next: 2),
    ]) {
      service.getSessionMessages(
        sessionId: "session-1",
        read: read!,
        sessionStatus: status,
      );
      expect(
        messageRepository.replayToolDisposition,
        CodexReplayToolDisposition.preserveRunning,
      );
    }
  });

  test("prepares the transcript before replay activity is supplied", () async {
    final messageRepository = _RecordingMessageRepository();
    final outcomes = _DelayedToolOutcomeRepository();
    final service = _newService(
      catalogRepository: _FixedPathCatalogRepository(),
      messageRepository: messageRepository,
      toolOutcomeRepository: outcomes,
    );
    var sessionStatus = const PluginSessionStatus.idle();

    final readFuture = service.prepareSessionMessageRead(
      sessionId: "session-1",
    );
    await outcomes.readStarted.future;
    outcomes.allowRead.complete();
    final read = await readFuture;
    expect(messageRepository.prepareCount, 1);
    sessionStatus = const PluginSessionStatus.busy();
    service.getSessionMessages(
      sessionId: "session-1",
      read: read!,
      sessionStatus: sessionStatus,
    );

    expect(
      messageRepository.replayToolDisposition,
      CodexReplayToolDisposition.preserveRunning,
    );
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
          userContentMapper: const CodexUserContentMapper(),
        ),
    metadataRepository:
        metadataRepository ??
        CodexMetadataRepository(
          configReader: CodexConfigReader(environment: const {}),
        ),
    toolOutcomeRepository: toolOutcomeRepository ?? createMemoryCodexToolOutcomeRepository(),
    subAgentTracker: CodexSubAgentTracker(),
    sessionMapper: const CodexSessionMapper(),
    launchDirectory: "/repo",
  );
}

class _DeleteFailingCatalogRepository() extends CodexCatalogRepository {
  this : super(rolloutApi: CodexRolloutApi(environment: const {}));

  @override
  bool deleteSession({required String sessionId}) => false;
}

class _DelayedToolOutcomeRepository() extends CodexToolOutcomeRepository {
  this
    : super(
        storage: _ReadFailingToolOutcomeStorage(),
      );

  final readStarted = Completer<void>();
  final allowRead = Completer<void>();

  @override
  Future<Map<String, PluginToolStatus>> readStatuses({required String sessionId}) async {
    readStarted.complete();
    await allowRead.future;
    return const {};
  }
}

class _FixedPathCatalogRepository() extends CodexCatalogRepository {
  this : super(rolloutApi: CodexRolloutApi(environment: const {}));

  @override
  String? findRolloutPath({required String sessionId}) => "/rollout.jsonl";
}

class _RecordingMessageRepository() extends CodexMessageRepository {
  this
    : super(
        rolloutApi: CodexRolloutApi(environment: const {}),
        rolloutToolMapper: const CodexRolloutToolMapper(
          imageAttachmentMapper: CodexImageAttachmentMapper(),
        ),
        userContentMapper: const CodexUserContentMapper(),
      );

  Map<String, PluginToolStatus>? statuses;
  CodexReplayToolDisposition? replayToolDisposition;
  int prepareCount = 0;

  @override
  CodexPreparedMessageRead prepareMessageRead({
    required String rolloutPath,
    required String sessionId,
  }) {
    prepareCount += 1;
    return CodexPreparedMessageRead(lines: const []);
  }

  @override
  List<PluginMessageWithParts> projectMessages({
    required CodexPreparedMessageRead read,
    required String sessionId,
    required List<CodexThreadRecord> children,
    required CodexReplayToolDisposition replayToolDisposition,
    required Map<String, PluginToolStatus> structuredToolStatusByCallId,
    CodexConfigDefaults config = const CodexConfigDefaults.empty(),
  }) {
    statuses = structuredToolStatusByCallId;
    this.replayToolDisposition = replayToolDisposition;
    return const [];
  }
}

class _ReadFailingToolOutcomeStorage() implements CodexToolOutcomeStorage {
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

class _StubMetadataRepository({required final CodexConfigDefaults defaults}) extends CodexMetadataRepository {
  this : super(configReader: CodexConfigReader(environment: const {}));

  @override
  CodexConfigDefaults readConfigDefaults() => defaults;
}

class _StubModelRepository({
  final CodexModelCatalog catalog = const (
    defaultModelID: null,
    models: <PluginModel>[],
  ),
  final Object? error,
}) extends CodexModelRepository {
  this
    : super(
        appServerApi: CodexAppServerApi(
          client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0"),
        ),
      );

  int listCount = 0;

  @override
  Future<CodexModelCatalog> listModels() async {
    listCount += 1;
    final failure = error;
    if (failure != null) throw failure;
    return catalog;
  }
}

class _StubSkillRepository({var List<PluginCommand> commands = const [], final Object? error})
    extends CodexSkillRepository {
  this
    : super(
        appServerApi: CodexAppServerApi(
          client: CodexAppServerClient(serverUrl: "ws://127.0.0.1:0"),
        ),
      );

  @override
  Future<List<PluginCommand>> listCommands({required String cwd}) async {
    final failure = error;
    if (failure != null) throw failure;
    return commands;
  }
}

class _StubThreadRepository() extends CodexThreadRepository {
  this
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
  String? lastClientUserMessageId;

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
      parentId: null,
      agentNickname: null,
      agentPath: null,
    );
  }

  @override
  Future<String?> startTurn({
    required String threadId,
    required List<PluginPromptPart> parts,
    required String? clientUserMessageId,
    required String? model,
    required String? effort,
    required CodexCollaborationMode? collaborationMode,
  }) async {
    lastParts = parts;
    lastModel = model;
    lastEffort = effort;
    lastClientUserMessageId = clientUserMessageId;
    return "turn";
  }

  @override
  Future<void> compactThread({required String threadId}) async {
    compactCount += 1;
  }
}
