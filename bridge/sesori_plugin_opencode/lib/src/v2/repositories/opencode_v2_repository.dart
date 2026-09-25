import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "../api/opencode_v2_api.dart";
import "../models/openapi/form_info.g.dart";
import "../models/openapi/form_reply.g.dart";
import "../models/openapi/location_public_ref.g.dart";
import "../models/openapi/model_ref.g.dart";
import "../models/openapi/permission_reply.g.dart";
import "../models/openapi/permission_request.g.dart";
import "../models/openapi/project.g.dart";
import "../models/openapi/prompt_input_file_attachment.g.dart";
import "../models/openapi/session_info.g.dart";
import "../models/openapi/worktree_remove_input.g.dart";
import "../models/v2_agent_names.dart";
import "../models/v2_request_bodies.dart";
import "v2_message_mapper.dart";
import "v2_model_mapper.dart";

/// V2 I/O and model projection, without runtime state or lifecycle ownership.
class OpenCodeV2Repository({
  required final OpenCodeV2Api _api,
  required final V2ModelMapper _modelMapper,
  required final V2MessageMapper _messageMapper,
}) {
  Future<List<({PluginProject project, List<String> sandboxes})>> getProjects() async {
    final (projects, sessions) = await shared.wait2(
      _api.listProjects(),
      _api.listRootSessions(projectId: null),
    );
    return [
      for (final project in projects)
        (
          project: _modelMapper.mapProject(
            project: project,
            activity: _activity(
              sessions: sessions.where((session) => session.projectID == project.id).toList(),
            ),
          ),
          sandboxes: project.sandboxes,
        ),
    ];
  }

  Future<PluginProject> getProject({required String directory}) async {
    final location = await _api.getLocation(directory: directory);
    final projects = await _api.listProjects();
    final project = projects.firstWhere((project) => project.id == location.project.id);
    return _modelMapper.mapProject(project: project, activity: null).copyWith(directory: location.directory);
  }

  Future<PluginProject> renameProject({required String directory, required String name}) async {
    final location = await _api.getLocation(directory: directory);
    final project = await _api.updateProject(
      projectId: location.project.id,
      body: V2UpdateProjectBody(canonical: null, name: name, icon: null, commands: null),
    );
    return _modelMapper.mapProject(project: project, activity: null).copyWith(directory: location.directory);
  }

  Future<List<PluginSession>> getSessions({required String directory}) async {
    final location = await _api.getLocation(directory: directory);
    final sessions = await _api.listRootSessions(projectId: location.project.id);
    return [
      for (final session in sessions) _modelMapper.mapSession(session: session, projectId: location.project.canonical),
    ];
  }

  Future<List<PluginSession>> getChildSessions({required String sessionId}) async {
    final (sessions, projects) = await shared.wait2(
      _api.listSessions(directory: null, parentId: sessionId),
      _api.listProjects(),
    );
    return [
      for (final session in sessions)
        _modelMapper.mapSession(
          session: session,
          projectId: _projectId(session: session, projects: projects),
        ),
    ];
  }

  Future<PluginSession> getSession({required String sessionId}) async {
    final (session, projects) = await shared.wait2(_api.getSession(sessionId: sessionId), _api.listProjects());
    return _modelMapper.mapSession(
      session: session,
      projectId: _projectId(session: session, projects: projects),
    );
  }

  Future<shared.Session> getSessionDetails({required String sessionId}) async {
    final session = await _api.getSession(sessionId: sessionId);
    final (projects, names) = await shared.wait2(
      _api.listProjects(),
      getAgentNames(directory: session.location.directory),
    );
    return _modelMapper.mapSessionDetails(
      session: session,
      projectId: _projectId(session: session, projects: projects),
      agentNames: names,
    );
  }

  Future<List<PluginMessageWithParts>> getMessages({required String sessionId}) async {
    final session = await _api.getSession(sessionId: sessionId);
    final (messages, names) = await shared.wait2(
      _api.listMessages(sessionId: sessionId),
      getAgentNames(directory: session.location.directory),
    );
    return [
      for (final message in messages)
        ?_messageMapper.mapMessage(sessionId: sessionId, message: message, agentNames: names),
    ];
  }

  Future<List<PluginAgent>> getAgents({required String directory}) async => [
    for (final agent in await _api.listAgents(directory: directory)) _modelMapper.mapAgent(agent: agent),
  ];

  Future<V2AgentNames> getAgentNames({required String directory}) async =>
      V2AgentNames.fromAgents(agents: await _api.listAgents(directory: directory));

  Future<PluginProvidersResult> getProviders({required String directory}) async {
    final providers = await _api.listProviders(directory: directory);
    final models = await _api.listModels(directory: directory);
    final defaultModel = await _api.getDefaultModel(directory: directory);
    return _modelMapper.mapProviders(providers: providers, models: models, defaultModel: defaultModel);
  }

  Future<List<PluginCommand>> getCommands({required String directory}) async => [
    for (final command in await _api.listCommands(directory: directory)) _modelMapper.mapCommand(command: command),
  ];

  /// The native active-session endpoint is global and contains only running IDs.
  Future<Set<String>> getActiveSessionIds() async => (await _api.getActiveSessions()).keys.toSet();

  // Keep native constraints for the activity tracker and form-answer validator.
  Future<List<PermissionRequest>> getPendingPermissions({required String directory}) =>
      _api.listPermissions(directory: directory);

  Future<List<FormInfo>> getPendingForms({required String directory}) => _api.listForms(directory: directory);

  Future<PluginSession> createSession({
    required String directory,
    required String? title,
    required String? agent,
    required PluginAgentModel? model,
  }) async {
    final location = await _api.getLocation(directory: directory);
    final nativeAgent = agent == null ? null : await _nativeAgent(directory: location.directory, selection: agent);
    final session = await _api.createSession(
      body: V2CreateSessionBody(
        location: LocationPublicRef(directory: location.directory),
        title: title,
        agent: nativeAgent,
        model: model == null ? null : _modelRef(model: model),
      ),
    );
    return _modelMapper.mapSession(session: session, projectId: location.project.canonical);
  }

  Future<void> switchAgent({required String sessionId, required String directory, required String agent}) async {
    final nativeAgent = await _nativeAgent(directory: directory, selection: agent);
    await _api.switchAgent(
      sessionId: sessionId,
      body: V2SwitchAgentBody(agent: nativeAgent),
    );
  }

  Future<void> switchModel({required String sessionId, required PluginAgentModel model}) => _api.switchModel(
    sessionId: sessionId,
    body: V2SwitchModelBody(model: _modelRef(model: model)),
  );

  Future<void> sendPrompt({required String sessionId, required List<PluginPromptPart> parts}) async {
    await _api.prompt(
      sessionId: sessionId,
      body: V2PromptBody(
        id: null,
        text: parts.whereType<PluginPromptPartText>().map((part) => part.text).join("\n"),
        files: _files(parts: parts),
        agents: null,
        skills: null,
        delivery: null,
        resume: null,
      ),
    );
  }

  Future<void> sendCommand({required String sessionId, required String command, required String arguments}) =>
      _api.command(
        sessionId: sessionId,
        body: V2CommandBody(name: command, text: arguments, files: null, agents: null, skills: null, delivery: null),
      );

  Future<PluginSession> renameSession({required String sessionId, required String title}) async {
    await _api.renameSession(
      sessionId: sessionId,
      body: V2RenameSessionBody(title: title),
    );
    return await getSession(sessionId: sessionId);
  }

  Future<void> deleteSession({required String sessionId}) => _api.deleteSession(sessionId: sessionId);

  Future<void> deleteWorktree({required String directory, required String worktreePath, required bool force}) async {
    final location = await _api.getLocation(directory: directory);
    await _api.removeWorktree(
      body: WorktreeRemoveInput(projectID: location.project.id, directory: worktreePath, force: force),
    );
  }

  Future<bool> interrupt({required String sessionId, required bool resume}) async =>
      (await _api.interrupt(sessionId: sessionId, resume: resume)).interrupted;

  Future<void> compact({required String sessionId}) async {
    await _api.compact(sessionId: sessionId, body: const V2CompactBody(id: null, delivery: null));
  }

  Future<void> addSyntheticMessage({
    required String sessionId,
    required String text,
    required String? description,
    required bool resume,
  }) async {
    await _api.synthetic(
      sessionId: sessionId,
      body: V2SyntheticBody(id: null, text: text, description: description, delivery: null, resume: resume),
    );
  }

  Future<void> replyToPermission({
    required String sessionId,
    required String requestId,
    required PluginPermissionReply reply,
  }) => _api.replyPermission(
    sessionId: sessionId,
    requestId: requestId,
    body: V2PermissionReplyBody(
      decision: switch (reply) {
        PluginPermissionReply.once => PermissionReply.once,
        PluginPermissionReply.always => PermissionReply.always,
        PluginPermissionReply.reject => PermissionReply.reject,
      },
      message: null,
    ),
  );

  Future<void> replyToForm({required String sessionId, required String formId, required FormReply body}) =>
      _api.replyForm(sessionId: sessionId, formId: formId, body: body);

  Future<void> cancelForm({required String sessionId, required String formId}) =>
      _api.cancelForm(sessionId: sessionId, formId: formId);

  Future<String> _nativeAgent({required String directory, required String selection}) async {
    final names = await getAgentNames(directory: directory);
    final id = names.nativeId(selection: selection);
    if (id == null) {
      throw const PluginStaleOptionsException(
        "resolveAgent",
        message: "The selected OpenCode agent is no longer offered",
      );
    }
    return id;
  }

  ModelRef _modelRef({required PluginAgentModel model}) =>
      ModelRef(providerID: model.providerID, id: model.modelID, variant: model.variant);

  List<PromptInputFileAttachment> _files({required List<PluginPromptPart> parts}) {
    final files = <PromptInputFileAttachment>[];
    for (final part in parts) {
      final file = switch (part) {
        PluginPromptPartText() => null,
        PluginPromptPartFilePath() => (uri: Uri.file(part.path).toString(), name: part.filename),
        PluginPromptPartFileUrl() => (uri: part.url, name: part.filename),
        PluginPromptPartFileData() => (uri: "data:${part.mime};base64,${part.base64}", name: part.filename),
      };
      if (file != null) {
        files.add(PromptInputFileAttachment(uri: file.uri, name: file.name, description: null, mention: null));
      }
    }
    return files;
  }

  String _projectId({required SessionInfo session, required List<Project> projects}) =>
      projects.firstWhere((project) => project.id == session.projectID).canonical;

  PluginProjectActivity? _activity({required List<SessionInfo> sessions}) {
    if (sessions.isEmpty) return null;
    return PluginProjectActivity(
      createdAt: sessions.map((session) => session.time.created.toInt()).reduce((a, b) => a < b ? a : b),
      updatedAt: sessions.map((session) => session.time.updated.toInt()).reduce((a, b) => a > b ? a : b),
    );
  }
}
