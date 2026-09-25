import "dart:io";

import "package:opencode_plugin/src/v2/api/opencode_v2_api.dart";
import "package:opencode_plugin/src/v2/models/openapi/agent_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/command_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/form_answer.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/form_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/form_reply.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/location_public_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/location_public_ref.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/model_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/permission_reply.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/permission_request.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/project.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/provider_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_active.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_inbox_compaction.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_inbox_synthetic.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_inbox_user.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_interrupt_response.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_message_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/worktree_remove_input.g.dart";
import "package:opencode_plugin/src/v2/models/v2_request_bodies.dart";
import "package:opencode_plugin/src/v2/repositories/opencode_v2_repository.dart";
import "package:opencode_plugin/src/v2/repositories/v2_message_mapper.dart";
import "package:opencode_plugin/src/v2/repositories/v2_model_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show jsonCastMap, jsonDecodeMap;
import "package:test/test.dart";

const directory = "/fixture/project";
const worktree = "/fixture/worktree";

void main() {
  final fixture = jsonDecodeMap(File("test/v2/fixtures/native_2_0_16.json").readAsStringSync());
  Map<String, dynamic> native({required String key}) => jsonCastMap(fixture[key]);
  late FakeV2Api api;
  late OpenCodeV2Repository repository;
  setUp(() {
    api = FakeV2Api(
      project: Project.fromJson(native(key: "project")),
      initialSession: SessionInfo.fromJson(native(key: "session")),
      agent: AgentInfo.fromJson(native(key: "agent")),
      provider: ProviderInfo.fromJson(native(key: "provider")),
      model: ModelInfo.fromJson(native(key: "model")),
    );
    repository = OpenCodeV2Repository(
      api: api,
      modelMapper: const V2ModelMapper(pluginId: "fixture-plugin"),
      messageMapper: const V2MessageMapper(),
    );
  });

  test("derives project activity from root sessions across worktrees", () async {
    api.projects = [
      api.project.copyWith(sandboxes: [worktree]),
      api.project.copyWith(id: "unused", canonical: "/unused"),
    ];
    api.sessions = [
      api.initialSession.copyWith(time: api.initialSession.time.copyWith(created: 10, updated: 20)),
      api.initialSession.copyWith(
        id: "worktree-root",
        location: const LocationPublicRef(directory: worktree),
        time: api.initialSession.time.copyWith(created: 5, updated: 40),
      ),
      api.initialSession.copyWith(
        id: "child",
        parentID: "session-fixture",
        time: api.initialSession.time.copyWith(created: 1, updated: 999),
      ),
    ];
    final projects = await repository.getProjects();
    expect(projects.first.project.id, directory);
    expect(projects.first.sandboxes, [worktree]);
    expect(projects.first.project.activity!.createdAt, 5);
    expect(projects.first.project.activity!.updatedAt, 40);
    expect(projects.last.project.activity, isNull);
    expect(api.rootQueries, <String?>[null]);
  });

  test("keeps opened worktree directory separate from canonical project identity", () async {
    final project = await repository.getProject(directory: worktree);
    expect(project.id, directory);
    expect(project.directory, worktree);
    final renamed = await repository.renameProject(directory: worktree, name: "Renamed");
    expect(renamed.name, "Renamed");
    expect(renamed.directory, worktree);
    expect(api.updatedProjectId, "project-fixture");
    expect(api.projectBody!.canonical, isNull);
  });

  test("reads project roots and direct children with native identity filters", () async {
    api.sessions = [api.initialSession, api.initialSession.copyWith(id: "child", parentID: "session-fixture")];
    final roots = await repository.getSessions(directory: directory);
    expect(api.rootQueries.single, "project-fixture");
    expect(roots.map((session) => session.id), ["session-fixture"]);
    final children = await repository.getChildSessions(sessionId: "session-fixture");
    expect(children.single.parentID, "session-fixture");
    expect(children.single.projectID, directory);
    expect(api.sessionQueries.single, (directory: null, parentId: "session-fixture"));
  });

  test("uses the session location for display names and preserves native transcript identities", () async {
    api.currentSession = api.initialSession.copyWith(
      agent: "build",
      location: const LocationPublicRef(directory: worktree),
    );
    api.messages = [
      SessionMessageInfo.fromJson(const <String, dynamic>{
        "type": "assistant",
        "id": "message",
        "agent": "build",
        "model": <String, dynamic>{"id": "model", "providerID": "opencode"},
        "time": <String, int>{"created": 1},
        "content": <Object>[
          <String, dynamic>{"type": "text", "text": "Fixture"},
        ],
      }),
    ];
    final details = await repository.getSessionDetails(sessionId: "session-fixture");
    expect(details.projectID, directory);
    expect(details.directory, worktree);
    expect(details.promptDefaults!.agent, "Build");
    expect(details.pluginId, "fixture-plugin");
    final messages = await repository.getMessages(sessionId: "session-fixture");
    expect((messages.single.info as PluginMessageAssistant).agent, "Build");
    expect(messages.single.parts.single.id, "message:0");
    expect(api.agentDirectories, [worktree, worktree]);
  });

  test("composes catalogs without inventing a separate identity or default", () async {
    expect((await repository.getAgents(directory: worktree)).single.name, "Build");
    final providers = await repository.getProviders(directory: worktree);
    expect(providers.providers.single.defaultModelID, api.model.id);
    expect(providers.providers.single.models.single.id, api.model.id);
    expect((await repository.getCommands(directory: worktree)).single.name, "review");
    expect(api.catalogDirectories, [worktree, worktree, worktree, worktree]);
  });

  test("reads global activity and preserves location-scoped native input constraints", () async {
    final permissions = await repository.getPendingPermissions(directory: worktree);
    final forms = await repository.getPendingForms(directory: worktree);
    expect(identical(permissions, api.permissions), isTrue);
    expect(identical(forms, api.forms), isTrue);
    expect(api.pendingDirectories, [worktree, worktree]);
    expect(await repository.getActiveSessionIds(), {"session-fixture", "child"});
  });

  test("translates display selections before native creation and selection writes", () async {
    const model = PluginAgentModel(providerID: "opencode", modelID: "model", variant: "high");
    final created = await repository.createSession(directory: worktree, title: "New", agent: "Build", model: model);
    expect(created.projectID, directory);
    expect(created.directory, worktree);
    expect(api.createBody!.agent, "build");
    expect(api.createBody!.location.directory, worktree);
    expect(api.createBody!.model!.variant, "high");
    await repository.switchAgent(sessionId: created.id, directory: worktree, agent: "Build");
    await repository.switchModel(sessionId: created.id, model: model);
    expect(api.agentBody!.agent, "build");
    expect(api.modelBody!.model.id, "model");
    api.agents = [];
    await expectLater(
      repository.switchAgent(sessionId: created.id, directory: worktree, agent: "Build"),
      throwsA(isA<PluginStaleOptionsException>()),
    );
    expect(api.calls.where((call) => call == "agent:session-fixture"), hasLength(1));
  });

  test("preserves native defaults without fetching an agent catalog", () async {
    api.agents = [];
    await repository.createSession(directory: directory, title: null, agent: null, model: null);
    expect(api.createBody!.agent, isNull);
    expect(api.createBody!.model, isNull);
    expect(api.createBody!.title, isNull);
    expect(api.agentDirectories, isEmpty);
  });

  test("serializes text and supported file parts without adding inbox behavior", () async {
    await repository.sendPrompt(
      sessionId: "session-fixture",
      parts: const [
        PluginPromptPart.text(text: "First"),
        PluginPromptPart.text(text: "Second"),
        PluginPromptPart.filePath(mime: "text/plain", path: "/fixture/file name.txt", filename: "file name.txt"),
        PluginPromptPart.fileUrl(mime: "image/png", url: "https://fixture.invalid/image.png", filename: null),
        PluginPromptPart.fileData(mime: "image/png", base64: "AQID", filename: "fixture.png"),
      ],
    );
    final body = api.promptBody!;
    expect(body.text, "First\nSecond");
    expect(body.files!.map((file) => file.uri), [
      Uri.file("/fixture/file name.txt").toString(),
      "https://fixture.invalid/image.png",
      "data:image/png;base64,AQID",
    ]);
    expect(body.files!.first.name, "file name.txt");
    expect(body.id, isNull);
    expect(body.delivery, isNull);
    await repository.sendCommand(sessionId: "session-fixture", command: "review", arguments: "fixture args");
    expect(api.commandBody!.name, "review");
    expect(api.commandBody!.text, "fixture args");
  });

  test("routes mutations with native IDs and leaves synthetic presentation explicit", () async {
    final renamed = await repository.renameSession(sessionId: "session-fixture", title: "Renamed");
    expect(renamed.title, "Renamed");
    await repository.deleteSession(sessionId: "session-fixture");
    await repository.deleteWorktree(directory: directory, worktreePath: worktree, force: true);
    expect(api.worktreeBody!.projectID, "project-fixture");
    expect(api.worktreeBody!.directory, worktree);
    expect(api.worktreeBody!.force, isTrue);
    expect(await repository.interrupt(sessionId: "session-fixture", resume: false), isTrue);
    expect(api.interruptResume, isFalse);
    await repository.addSyntheticMessage(
      sessionId: "session-fixture",
      text: "Internal fixture",
      description: "Visible fixture",
      resume: false,
    );
    expect(api.syntheticBody!.text, "Internal fixture");
    expect(api.syntheticBody!.description, "Visible fixture");
    expect(api.syntheticBody!.resume, isFalse);
    await repository.compact(sessionId: "session-fixture");
    for (final reply in PluginPermissionReply.values) {
      await repository.replyToPermission(sessionId: "session-fixture", requestId: "permission", reply: reply);
    }
    expect(api.decisions, [PermissionReply.once, PermissionReply.always, PermissionReply.reject]);
    final form = FormReply(answer: FormAnswer.fromJson(const <String, dynamic>{"count": 2}));
    await repository.replyToForm(sessionId: "session-fixture", formId: "form", body: form);
    expect(api.formBody, same(form));
    await repository.cancelForm(sessionId: "session-fixture", formId: "form");
    expect(
      api.calls,
      containsAll([
        "delete:session-fixture",
        "compact:session-fixture",
        "permission:session-fixture/permission",
        "form:session-fixture/form",
        "cancel:session-fixture/form",
      ]),
    );
  });

  test("propagates history failures rather than returning an empty transcript", () async {
    final failure = StateError("Fixture transport failure");
    api.historyFailure = failure;
    await expectLater(repository.getMessages(sessionId: "session-fixture"), throwsA(same(failure)));
  });
}

class FakeV2Api({
  required final Project project,
  required final SessionInfo initialSession,
  required final AgentInfo agent,
  required final ProviderInfo provider,
  required final ModelInfo model,
}) implements OpenCodeV2Api {
  late List<Project> projects = [project];
  late List<SessionInfo> sessions = [initialSession];
  late SessionInfo currentSession = initialSession;
  late List<AgentInfo> agents = [agent];
  List<SessionMessageInfo> messages = [];
  final sessionQueries = <({String? directory, String? parentId})>[];
  final agentDirectories = <String>[];
  final catalogDirectories = <String>[];
  final pendingDirectories = <String>[];
  final calls = <String>[];
  final decisions = <PermissionReply>[];
  final permissions = [
    PermissionRequest.fromJson(const <String, dynamic>{
      "id": "permission",
      "sessionID": "session-fixture",
      "action": "shell",
      "resources": <String>["pwd"],
    }),
  ];
  final forms = [
    FormInfo.fromJson(const <String, dynamic>{
      "id": "form",
      "sessionID": "session-fixture",
      "fields": <Object>[
        <String, dynamic>{"type": "integer", "key": "count"},
      ],
    }),
  ];
  final rootQueries = <String?>[];
  String? updatedProjectId;
  Object? historyFailure;
  V2UpdateProjectBody? projectBody;
  V2CreateSessionBody? createBody;
  V2SwitchAgentBody? agentBody;
  V2SwitchModelBody? modelBody;
  V2PromptBody? promptBody;
  V2CommandBody? commandBody;
  WorktreeRemoveInput? worktreeBody;
  V2SyntheticBody? syntheticBody;
  FormReply? formBody;
  bool? interruptResume;

  @override
  Future<List<Project>> listProjects() async => projects;
  @override
  Future<LocationPublicInfo> getLocation({required String directory}) async => LocationPublicInfo(
    directory: directory,
    project: LocationPublicInfoProject(id: project.id, directory: directory, canonical: project.canonical),
  );
  @override
  Future<Project> updateProject({required String projectId, required V2UpdateProjectBody body}) async {
    updatedProjectId = projectId;
    projectBody = body;
    return project.copyWith(name: body.name);
  }

  @override
  Future<List<SessionInfo>> listSessions({required String? directory, required String? parentId}) async {
    sessionQueries.add((directory: directory, parentId: parentId));
    return parentId == null ? sessions : sessions.where((session) => session.parentID == parentId).toList();
  }

  @override
  Future<List<SessionInfo>> listRootSessions({required String? projectId}) async {
    rootQueries.add(projectId);
    return sessions
        .where((session) => session.parentID == null && (projectId == null || session.projectID == projectId))
        .toList();
  }

  @override
  Future<SessionInfo> getSession({required String sessionId}) async => currentSession;
  @override
  Future<List<SessionMessageInfo>> listMessages({required String sessionId}) async {
    if (historyFailure case final failure?) throw failure;
    return messages;
  }

  @override
  Future<List<AgentInfo>> listAgents({required String directory}) async {
    agentDirectories.add(directory);
    return agents;
  }

  @override
  Future<List<ProviderInfo>> listProviders({required String directory}) async {
    catalogDirectories.add(directory);
    return [provider];
  }

  @override
  Future<List<ModelInfo>> listModels({required String directory}) async {
    catalogDirectories.add(directory);
    return [model];
  }

  @override
  Future<ModelInfo?> getDefaultModel({required String directory}) async {
    catalogDirectories.add(directory);
    return model;
  }

  @override
  Future<List<CommandInfo>> listCommands({required String directory}) async {
    catalogDirectories.add(directory);
    return [
      CommandInfo.fromJson(const <String, dynamic>{"name": "review"}),
    ];
  }

  @override
  Future<Map<String, SessionActive>> getActiveSessions() async => {
    "session-fixture": const SessionActive(type: "running"),
    "child": const SessionActive(type: "running"),
  };
  @override
  Future<List<PermissionRequest>> listPermissions({required String directory}) async {
    pendingDirectories.add(directory);
    return permissions;
  }

  @override
  Future<List<FormInfo>> listForms({required String directory}) async {
    pendingDirectories.add(directory);
    return forms;
  }

  @override
  Future<SessionInfo> createSession({required V2CreateSessionBody body}) async {
    createBody = body;
    return initialSession.copyWith(title: body.title, agent: body.agent, model: body.model, location: body.location);
  }

  @override
  Future<void> switchAgent({required String sessionId, required V2SwitchAgentBody body}) async {
    calls.add("agent:$sessionId");
    agentBody = body;
  }

  @override
  Future<void> switchModel({required String sessionId, required V2SwitchModelBody body}) async {
    modelBody = body;
  }

  @override
  Future<SessionInboxUser> prompt({required String sessionId, required V2PromptBody body}) async {
    promptBody = body;
    return SessionInboxUser.fromJson(_ack(payload: <String, dynamic>{"text": body.text}));
  }

  @override
  Future<void> command({required String sessionId, required V2CommandBody body}) async {
    commandBody = body;
  }

  @override
  Future<void> renameSession({required String sessionId, required V2RenameSessionBody body}) async {
    currentSession = currentSession.copyWith(title: body.title);
  }

  @override
  Future<void> deleteSession({required String sessionId}) async {
    calls.add("delete:$sessionId");
  }

  @override
  Future<void> removeWorktree({required WorktreeRemoveInput body}) async {
    worktreeBody = body;
  }

  @override
  Future<SessionInterruptResponse> interrupt({required String sessionId, required bool resume}) async {
    interruptResume = resume;
    return const SessionInterruptResponse(interrupted: true);
  }

  @override
  Future<SessionInboxSynthetic> synthetic({required String sessionId, required V2SyntheticBody body}) async {
    syntheticBody = body;
    return SessionInboxSynthetic.fromJson(_ack(payload: <String, dynamic>{"text": body.text}));
  }

  @override
  Future<SessionInboxCompaction> compact({required String sessionId, required V2CompactBody body}) async {
    calls.add("compact:$sessionId");
    return SessionInboxCompaction.fromJson(_ack(payload: const <Object?>[]));
  }

  @override
  Future<void> replyPermission({
    required String sessionId,
    required String requestId,
    required V2PermissionReplyBody body,
  }) async {
    calls.add("permission:$sessionId/$requestId");
    decisions.add(body.decision);
  }

  @override
  Future<void> replyForm({required String sessionId, required String formId, required FormReply body}) async {
    calls.add("form:$sessionId/$formId");
    formBody = body;
  }

  @override
  Future<void> cancelForm({required String sessionId, required String formId}) async {
    calls.add("cancel:$sessionId/$formId");
  }

  Map<String, dynamic> _ack({required Object payload}) => <String, dynamic>{
    "id": "inbox-fixture",
    "sessionID": "session-fixture",
    "time": <String, int>{"created": 1},
    "delivery": "queue",
    "payload": payload,
  };

  @override
  dynamic noSuchMethod(Invocation invocation) => throw StateError("Unexpected API call: ${invocation.memberName}");
}
