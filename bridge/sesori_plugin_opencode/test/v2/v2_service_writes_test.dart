import "dart:async";

import "package:opencode_plugin/src/v2/mappers/v2_form_answer_mapper.dart";
import "package:opencode_plugin/src/v2/mappers/v2_form_answer_validator.dart";
import "package:opencode_plugin/src/v2/models/openapi/form_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/form_reply.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/permission_request.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_info.g.dart";
import "package:opencode_plugin/src/v2/models/v2_event.g.dart";
import "package:opencode_plugin/src/v2/repositories/opencode_v2_activity_tracker.dart";
import "package:opencode_plugin/src/v2/repositories/opencode_v2_repository.dart";
import "package:opencode_plugin/src/v2/repositories/v2_message_mapper.dart";
import "package:opencode_plugin/src/v2/repositories/v2_model_mapper.dart";
import "package:opencode_plugin/src/v2/services/opencode_v2_service.dart";
import "package:opencode_plugin/src/v2/sse/v2_event_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

import "support/v2_fixtures.dart";

const directory = "/fixture/project";
const models = V2ModelMapper(pluginId: "fixture-plugin");
final native = SessionInfo.fromJson(v2SessionFixture);
final root = models.mapSessionMetadata(session: native, projectId: directory);
final child = root.copyWith(id: "child", parentID: root.id);
final session = models.mapSession(session: native, projectId: directory);
final form = FormInfo.fromJson(const <String, dynamic>{
  "id": "form",
  "sessionID": "child",
  "fields": <Object>[
    <String, dynamic>{"type": "integer", "key": "count", "minimum": 1, "maximum": 3},
  ],
});
final permission = PermissionRequest.fromJson(const <String, dynamic>{
  "id": "permission",
  "sessionID": "child",
  "action": "shell",
  "resources": <String>["pwd"],
});
const parts = <PluginPromptPart>[
  PluginPromptPart.text(text: "Fixture"),
  PluginPromptPart.fileData(mime: "image/png", base64: "AQID", filename: "fixture.png"),
];

void main() {
  late WritableRepository repository;
  late OpenCodeV2ActivityTracker tracker;
  late OpenCodeV2Service service;
  setUp(() {
    repository = WritableRepository();
    tracker = OpenCodeV2ActivityTracker();
    tracker.seed(sessions: [root, child], activeSessionIds: {}, permissions: [], forms: []);
    service = OpenCodeV2Service(
      repository: repository,
      tracker: tracker,
      mapper: const V2EventMapper(modelMapper: models, messageMapper: V2MessageMapper()),
      modelMapper: models,
      formAnswerMapper: const V2FormAnswerMapper(),
      formAnswerValidator: const V2FormAnswerValidator(),
    );
  });

  test("explicit child creation fails before mutation; an empty standalone session is allowed", () async {
    await expectLater(
      service.createSession(
        directory: directory,
        parentSessionId: root.id,
        parts: [],
        agent: null,
        model: null,
        variant: null,
      ),
      throwsA(isA<PluginOperationException>().having((e) => e.statusCode, "status", 501)),
    );
    expect(repository.calls, isEmpty);
    expect(
      await service.createSession(
        directory: directory,
        parentSessionId: null,
        parts: [],
        agent: null,
        model: null,
        variant: null,
      ),
      session,
    );
    expect(repository.calls, ["create"]);
  });

  test("creation sends exact first-prompt parts and finishes on acceptance without fabricating busy", () async {
    repository.promptAccepted = Completer<void>();
    var completed = false;
    final result = service
        .createSession(
          directory: directory,
          parentSessionId: null,
          parts: parts,
          agent: null,
          model: null,
          variant: null,
        )
        .then((value) {
          completed = true;
          return value;
        });
    await repository.promptEntered.future;
    expect(completed, isFalse);
    tracker.apply(event: V2SessionExecutionStarted(sessionID: root.id));
    tracker.apply(event: V2SessionExecutionSucceeded(sessionID: root.id));
    repository.promptAccepted!.complete();
    expect(await result, session);
    expect(repository.calls, ["create", "prompt"]);
    expect(repository.parts, parts);
    expect(service.workState, PluginWorkState.idle);
  });

  test("explicit selections are checked and switched before prompt acceptance", () async {
    await service.sendPrompt(
      sessionId: root.id,
      parts: parts,
      agent: "Build",
      model: (providerID: "p", modelID: "m"),
      variant: const PluginSessionVariant(id: "high"),
    );
    expect(repository.calls, ["providers", "agent:Build", "model", "prompt"]);
    expect(repository.selectedModel, const PluginAgentModel(providerID: "p", modelID: "m", variant: "high"));
    repository.calls.clear();
    await expectLater(
      service.sendPrompt(
        sessionId: root.id,
        parts: parts,
        agent: "Build",
        model: (providerID: "p", modelID: "gone"),
        variant: null,
      ),
      throwsA(isA<PluginStaleOptionsException>()),
    );
    expect(repository.calls, ["providers"]);
  });

  test("variant-only selection uses the effective native model; omission makes no catalog queries", () async {
    await service.sendPrompt(
      sessionId: root.id,
      parts: parts,
      agent: null,
      model: null,
      variant: const PluginSessionVariant(id: "high"),
    );
    expect(repository.calls, ["current-model", "providers", "model", "prompt"]);
    repository.calls.clear();
    await service.sendPrompt(sessionId: root.id, parts: parts, agent: null, model: null, variant: null);
    expect(repository.calls, ["prompt"]);
  });

  test("compaction guides the model first without displaying private guidance", () async {
    expect((await service.getCommands(projectId: null)).single.name, "compact");
    repository.calls.clear();
    await service.sendCommand(
      sessionId: root.id,
      command: "compact",
      arguments: "Internal fixture context",
      userVisibleArguments: null,
      agent: null,
      model: null,
      variant: null,
    );
    expect(repository.calls, ["commands", "synthetic", "compact"]);
    expect(repository.synthetic, (
      text: "Internal fixture context",
      description: "Compaction instructions",
      resume: false,
    ));
    repository.commands = [PluginCommand.compaction(name: "compact")];
    repository.calls.clear();
    await service.sendCommand(
      sessionId: root.id,
      command: "compact",
      arguments: "Custom arguments",
      userVisibleArguments: "Custom arguments",
      agent: null,
      model: null,
      variant: null,
    );
    expect(repository.calls, ["commands", "command:compact"]);
  });

  test("unknown commands fail before native mutation", () async {
    await expectLater(
      service.sendCommand(
        sessionId: root.id,
        command: "gone",
        arguments: "Fixture",
        userVisibleArguments: "Fixture",
        agent: null,
        model: null,
        variant: null,
      ),
      throwsA(isA<PluginStaleOptionsException>()),
    );
    expect(repository.calls, ["commands"]);
  });

  test("pending children retain root attribution; only a successful reply consumes native constraints", () async {
    tracker.seed(sessions: [root, child], activeSessionIds: {}, permissions: [permission], forms: [form]);
    expect((await service.getPendingQuestions(sessionId: root.id)).single.displaySessionId, root.id);
    expect((await service.getPendingPermissions(sessionId: root.id)).single.sessionID, "child");
    await expectLater(
      service.replyToQuestion(
        questionId: "form",
        sessionId: "child",
        answers: [
          ["9"],
        ],
      ),
      throwsA(isA<PluginOperationException>()),
    );
    expect(repository.calls, isEmpty);
    final failure = StateError("Fixture reply failure");
    repository.replyFailure = failure;
    await expectLater(
      service.replyToQuestion(
        questionId: "form",
        sessionId: "child",
        answers: [
          ["2"],
        ],
      ),
      throwsA(same(failure)),
    );
    expect(tracker.forms.single, same(form));
    repository.replyFailure = null;
    await service.replyToQuestion(
      questionId: "form",
      sessionId: root.id,
      answers: [
        ["2"],
      ],
    );
    expect(repository.calls.last, "reply:child/form");
    expect(repository.reply!.answer.toJson(), {"count": 2});
    expect(tracker.forms, isEmpty);
    await service.replyToPermission(requestId: "permission", sessionId: "child", reply: PluginPermissionReply.always);
    expect(tracker.permissions, isEmpty);
    expect(repository.calls.last, "permission:child/permission:always");
  });

  test("form replies can fetch an uncached request; cancellation resolves a known native owner", () async {
    tracker.reset();
    await service.replyToQuestion(
      questionId: "form",
      sessionId: "child",
      answers: [
        ["1"],
      ],
    );
    expect(repository.calls, ["session", "forms", "reply:child/form"]);
    tracker.seed(sessions: [root, child], activeSessionIds: {}, permissions: [], forms: [form]);
    await service.rejectQuestion(questionId: "form", sessionId: null);
    expect(repository.calls.last, "cancel:child/form");
    expect(tracker.forms, isEmpty);
    await expectLater(
      service.rejectQuestion(questionId: "gone", sessionId: null),
      throwsA(isA<PluginOperationException>()),
    );
  });

  test("scoped stop confirms children, preserves keep and dispatches stop without invented settlement", () async {
    tracker.seed(sessions: [root, child], activeSessionIds: {root.id, "child"}, permissions: [], forms: []);
    expect(
      await service.abortSession(sessionId: root.id, subAgents: PluginAbortSubAgentPolicy.confirm),
      isA<PluginAbortRejectedSubAgentsRunning>(),
    );
    expect(
      await service.abortSession(sessionId: root.id, subAgents: PluginAbortSubAgentPolicy.keep),
      isA<PluginAbortRejectedSubAgentsRunning>(),
    );
    expect(repository.calls, isEmpty);
    tracker.apply(event: V2SessionExecutionSucceeded(sessionID: root.id));
    final kept = await service.abortSession(
      sessionId: root.id,
      subAgents: PluginAbortSubAgentPolicy.keep,
    ) as PluginAbortAccepted;
    expect(kept.workKept, isTrue);
    expect(repository.calls, isEmpty);
    await service.abortSession(sessionId: root.id, subAgents: PluginAbortSubAgentPolicy.stop);
    expect(repository.calls, ["interrupt:${root.id}:false", "interrupt:child:false"]);
    expect(service.workState, PluginWorkState.busy);
  });

  test("rename/delete/workspace removal delegate; archival stays bridge-owned", () async {
    await service.renameSession(sessionId: root.id, title: "Renamed");
    await service.deleteSession(sessionId: root.id);
    await service.deleteWorkspace(projectId: directory, worktreePath: "/fixture/worktree");
    await service.archiveSession(sessionId: root.id);
    expect(repository.calls, ["rename:Renamed", "delete", "workspace:/fixture/worktree:false"]);
  });
}

class WritableRepository() implements OpenCodeV2Repository {
  final calls = <String>[];
  final promptEntered = Completer<void>();
  Completer<void>? promptAccepted;
  Object? replyFailure;
  List<PluginCommand> commands = [];
  List<PluginPromptPart>? parts;
  PluginAgentModel? selectedModel;
  FormReply? reply;
  ({String text, String? description, bool resume})? synthetic;

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? title,
    required String? agent,
    required PluginAgentModel? model,
  }) async {
    calls.add("create");
    selectedModel = model;
    return session;
  }

  @override
  Future<void> sendPrompt({required String sessionId, required List<PluginPromptPart> parts}) async {
    calls.add("prompt");
    this.parts = parts;
    if (!promptEntered.isCompleted) promptEntered.complete();
    await promptAccepted?.future;
  }

  @override
  Future<PluginSession> getSession({required String sessionId}) async {
    calls.add("session");
    return session;
  }

  @override
  Future<PluginAgentModel?> getSessionModel({required String sessionId}) async {
    calls.add("current-model");
    return const PluginAgentModel(providerID: "p", modelID: "m", variant: null);
  }

  @override
  Future<PluginProvidersResult> getProviders({required String directory}) async {
    calls.add("providers");
    return const PluginProvidersResult(
      providers: [
        PluginProvider(
          id: "p",
          name: "Provider",
          authType: PluginProviderAuthType.apiKey,
          defaultModelID: "m",
          models: [
            PluginModel(id: "m", name: "Model", variants: ["high"], fastMode: null),
          ],
        ),
      ],
    );
  }

  @override
  Future<void> switchAgent({required String sessionId, required String directory, required String agent}) async {
    calls.add("agent:$agent");
  }

  @override
  Future<void> switchModel({required String sessionId, required PluginAgentModel model}) async {
    calls.add("model");
    selectedModel = model;
  }

  @override
  Future<List<PluginCommand>> getCommands({required String? directory}) async {
    calls.add("commands");
    return commands;
  }

  @override
  Future<void> sendCommand({required String sessionId, required String command, required String arguments}) async {
    calls.add("command:$command");
  }

  @override
  Future<void> compact({required String sessionId}) async {
    calls.add("compact");
  }

  @override
  Future<void> addSyntheticMessage({
    required String sessionId,
    required String text,
    required String? description,
    required bool resume,
  }) async {
    calls.add("synthetic");
    synthetic = (text: text, description: description, resume: resume);
  }

  @override
  Future<List<FormInfo>> getPendingForms({required String directory}) async {
    calls.add("forms");
    return [form];
  }

  @override
  Future<void> replyToForm({required String sessionId, required String formId, required FormReply body}) async {
    calls.add("reply:$sessionId/$formId");
    if (replyFailure case final failure?) throw failure;
    reply = body;
  }

  @override
  Future<void> cancelForm({required String sessionId, required String formId}) async {
    calls.add("cancel:$sessionId/$formId");
  }

  @override
  Future<void> replyToPermission({
    required String sessionId,
    required String requestId,
    required PluginPermissionReply reply,
  }) async {
    calls.add("permission:$sessionId/$requestId:${reply.name}");
  }

  @override
  Future<bool> interrupt({required String sessionId, required bool resume}) async {
    calls.add("interrupt:$sessionId:$resume");
    return true;
  }

  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) async {
    calls.add("rename:$title");
    return session.copyWith(title: title);
  }

  @override
  Future<void> deleteSession({required String sessionId}) async {
    calls.add("delete");
  }

  @override
  Future<void> deleteWorktree({required String directory, required String worktreePath, required bool force}) async {
    calls.add("workspace:$worktreePath:$force");
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
