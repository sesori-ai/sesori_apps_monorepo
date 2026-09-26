import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "../mappers/v2_form_answer_mapper.dart";
import "../mappers/v2_form_answer_validator.dart";
import "../models/openapi/form_reply.g.dart";
import "../models/v2_agent_names.dart";
import "../models/v2_event.g.dart";
import "../models/v2_message_filter.dart";
import "../repositories/opencode_v2_activity_tracker.dart";
import "../repositories/opencode_v2_repository.dart";
import "../repositories/v2_model_mapper.dart";
import "../sse/v2_event_mapper.dart";

/// The transport consumer serializes refresh and event handling. This service
/// owns their orchestration, not a stream, queue, transcript cache or lifecycle.
class OpenCodeV2Service({
  required final OpenCodeV2Repository _repository,
  required final OpenCodeV2ActivityTracker _tracker,
  required final V2EventMapper _mapper,
  required final V2ModelMapper _modelMapper,
  required final V2FormAnswerMapper _formAnswerMapper,
  required final V2FormAnswerValidator _formAnswerValidator,
}) {
  static const compactionCommandName = "compact";

  PluginWorkState get workState => _tracker.workState;

  Future<void> coldStart() async {
    _tracker.invalidateBaseline();
    final sessions = await _repository.getSessionMetadata();
    final directories = sessions.map((session) => session.directory).toSet();
    final (active, (permissionLists, formLists)) = await shared.wait2(
      _repository.getActiveSessionIds(),
      shared.wait2(
        Future.wait(directories.map((directory) => _repository.getPendingPermissions(directory: directory))),
        Future.wait(directories.map((directory) => _repository.getPendingForms(directory: directory))),
      ),
    );
    _tracker.seed(
      sessions: sessions,
      activeSessionIds: active,
      permissions: permissionLists.expand((requests) => requests).toList(),
      forms: formLists.expand((forms) => forms).toList(),
    );
  }

  void reset() => _tracker.reset();
  void invalidateBaseline() => _tracker.invalidateBaseline();

  Future<bool> healthCheck() => _repository.healthCheck();
  Future<List<PluginProject>> getProjects() => _repository.getProjects();
  Future<PluginProject> getProject({required String projectId}) => _repository.getProject(directory: projectId);
  Future<PluginProject> renameProject({required String projectId, required String name}) =>
      _repository.renameProject(directory: projectId, name: name);
  Future<List<PluginAgent>> getAgents({required String projectId}) => _repository.getAgents(directory: projectId);
  Future<PluginProvidersResult> getProviders({required String projectId}) =>
      _repository.getProviders(directory: projectId);
  Future<List<PluginSession>> getChildSessions({required String sessionId}) =>
      _repository.getChildSessions(sessionId: sessionId);
  Future<List<PluginMessageWithParts>> getMessages({required String sessionId}) =>
      _repository.getMessages(sessionId: sessionId);

  Future<List<PluginSession>> getSessions({required String projectId, required int? start, required int? limit}) async {
    final sessions = await _repository.getSessions(directory: projectId);
    return sessions.skip(start ?? 0).take(limit ?? sessions.length).toList();
  }

  Future<Map<String, PluginSessionStatus>> getSessionStatuses() async => {
    for (final id in await _repository.getActiveSessionIds())
      id: _tracker.status(sessionId: id) ?? const PluginSessionStatus.busy(),
  };

  Future<Set<String>> interruptActiveWork() async {
    final ids = _tracker.workingSessionIds;
    await Future.wait([for (final id in ids) _repository.interrupt(sessionId: id, resume: false)]);
    return ids;
  }

  Future<List<PluginCommand>> getCommands({required String? projectId}) async {
    final commands = await _repository.getCommands(directory: projectId);
    return commands.any((command) => command.name == compactionCommandName)
        ? commands
        : [...commands, PluginCommand.compaction(name: compactionCommandName)];
  }

  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({required String projectId}) async {
    final (agents, (providers, commands)) = await shared.wait2(
      _repository.getAgents(directory: projectId),
      shared.wait2(_repository.getProviders(directory: projectId), getCommands(projectId: projectId)),
    );
    return PluginSessionOptionsDiscoveryResult.observed(
      options: PluginSessionOptions(
        agents: agents,
        providers: providers,
        commands: commands,
        completeness: PluginSessionOptionsCompleteness.complete,
      ),
    );
  }

  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
  }) async {
    if (parentSessionId != null) {
      throw const PluginOperationException(
        "createSession",
        statusCode: 501,
        message: "OpenCode v2 does not expose child-session creation. Create a standalone session instead.",
      );
    }
    final selection = model == null
        ? null
        : PluginAgentModel(providerID: model.providerID, modelID: model.modelID, variant: variant?.id);
    if (selection != null) await _validateModel(directory: directory, model: selection);
    final session = await _repository.createSession(directory: directory, title: null, agent: agent, model: selection);
    if (parts.isNotEmpty) {
      await sendPrompt(
        sessionId: session.id,
        promptId: null,
        parts: parts,
        agent: null,
        model: null,
        variant: model == null ? variant : null,
      );
    }
    return session;
  }

  Future<void> sendPrompt({
    required String sessionId,
    required String? promptId,
    required List<PluginPromptPart> parts,
    required String? agent,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
  }) async {
    await _select(sessionId: sessionId, agent: agent, model: model, variant: variant);
    await _repository.sendPrompt(sessionId: sessionId, promptId: promptId, parts: parts);
    // Native events own activity; acceptance can arrive after a fast terminal event.
  }

  Future<void> sendCommand({
    required String sessionId,
    required String? promptId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required String? agent,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
  }) async {
    final directory = await _directory(sessionId: sessionId);
    final nativeCommands = await _repository.getCommands(directory: directory);
    final native = nativeCommands.any((candidate) => candidate.name == command);
    if (!native && command != compactionCommandName) {
      throw const PluginStaleOptionsException(
        "sendCommand",
        message: "OpenCode no longer offers the selected command.",
      );
    }
    await _select(sessionId: sessionId, agent: agent, model: model, variant: variant);
    if (!native) {
      if (arguments.trim().isNotEmpty) {
        await _repository.addSyntheticMessage(
          sessionId: sessionId,
          text: arguments,
          description: userVisibleArguments ?? "Compaction instructions",
          resume: false,
        );
      }
      await _repository.compact(sessionId: sessionId, promptId: promptId);
    } else {
      await _repository.sendCommand(sessionId: sessionId, command: command, arguments: arguments);
    }
  }

  Future<void> _select({
    required String sessionId,
    required String? agent,
    required ({String providerID, String modelID})? model,
    required PluginSessionVariant? variant,
  }) async {
    if (agent == null && model == null && variant == null) return;
    final directory = await _directory(sessionId: sessionId);
    final selection = model != null
        ? PluginAgentModel(providerID: model.providerID, modelID: model.modelID, variant: variant?.id)
        : variant == null
        ? null
        : (await _repository.getSessionModel(sessionId: sessionId))?.copyWith(variant: variant.id);
    if (model == null && variant != null && selection == null) {
      throw const PluginStaleOptionsException(
        "selectModel",
        message: "OpenCode has no current model for the selected variant.",
      );
    }
    if (selection != null) await _validateModel(directory: directory, model: selection);
    if (agent != null) await _repository.switchAgent(sessionId: sessionId, directory: directory, agent: agent);
    if (selection != null) await _repository.switchModel(sessionId: sessionId, model: selection);
  }

  Future<void> _validateModel({required String directory, required PluginAgentModel model}) async {
    final providers = await _repository.getProviders(directory: directory);
    final candidate = providers.providers
        .where((provider) => provider.id == model.providerID)
        .firstOrNull
        ?.models
        .where((candidate) => candidate.id == model.modelID && candidate.isAvailable)
        .firstOrNull;
    if (candidate == null || (model.variant != null && !candidate.variants.contains(model.variant))) {
      throw const PluginStaleOptionsException(
        "selectModel",
        message: "OpenCode no longer offers the selected model or variant.",
      );
    }
  }

  Future<PluginSession> renameSession({required String sessionId, required String title}) =>
      _repository.renameSession(sessionId: sessionId, title: title);
  Future<void> deleteSession({required String sessionId}) => _repository.deleteSession(sessionId: sessionId);
  Future<void> deleteWorkspace({required String projectId, required String worktreePath}) =>
      _repository.deleteWorktree(directory: projectId, worktreePath: worktreePath, force: false);
  // The bridge database owns archival; OpenCode v2 has no archive operation.
  Future<void> archiveSession({required String sessionId}) async {}

  Future<PluginAbortResult> abortSession({
    required String sessionId,
    required PluginAbortSubAgentPolicy subAgents,
  }) async {
    final children = _tracker.workingSessionIds
        .where((id) => _tracker.session(sessionId: id)?.parentID == sessionId)
        .toList();
    final mainRunning = _tracker.status(sessionId: sessionId) != null;
    if (children.isNotEmpty) {
      if (subAgents == PluginAbortSubAgentPolicy.confirm ||
          (subAgents == PluginAbortSubAgentPolicy.keep && mainRunning)) {
        return PluginAbortRejectedSubAgentsRunning(
          runningSubAgentCount: children.length,
          mainAgentRunning: mainRunning,
          mainAgentOnlySupported: false,
        );
      }
      if (subAgents == PluginAbortSubAgentPolicy.keep) {
        return const PluginAbortAccepted(workKept: true, subAgentsHandled: false);
      }
    }
    await Future.wait([
      for (final id in [sessionId, ...children]) _repository.interrupt(sessionId: id, resume: false),
    ]);
    return const PluginAbortAccepted(workKept: false, subAgentsHandled: false);
  }

  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) async => [
    for (final form in _tracker.forms)
      if (form.sessionID == sessionId || _tracker.rootSessionId(sessionId: form.sessionID) == sessionId)
        ?_modelMapper.mapForm(
          form: form,
          displaySessionId: _tracker.rootSessionId(sessionId: form.sessionID),
        ),
  ];

  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) async => [
    for (final form in await _repository.getPendingForms(directory: projectId))
      ?_modelMapper.mapForm(
        form: form,
        displaySessionId: _tracker.rootSessionId(sessionId: form.sessionID),
      ),
  ];

  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) async => [
    for (final permission in _tracker.permissions)
      if (permission.sessionID == sessionId || _tracker.rootSessionId(sessionId: permission.sessionID) == sessionId)
        _modelMapper.mapPermission(
          permission: permission,
          displaySessionId: _tracker.rootSessionId(sessionId: permission.sessionID),
        ),
  ];

  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) async {
    final known = _tracker.forms.where((form) => form.id == questionId).firstOrNull;
    final form =
        known ??
        (await _repository.getPendingForms(directory: await _directory(sessionId: sessionId)))
            .where((form) => form.id == questionId)
            .firstOrNull;
    if (form == null) {
      throw const PluginOperationException(
        "replyToQuestion",
        statusCode: 404,
        message: "OpenCode form is no longer pending.",
      );
    }
    final answer = _formAnswerMapper.map(form: form, answers: answers);
    _formAnswerValidator.validate(form: form, answer: answer);
    await _repository.replyToForm(
      sessionId: form.sessionID,
      formId: questionId,
      body: FormReply(answer: answer),
    );
    _tracker.removeForm(formId: questionId);
  }

  Future<void> rejectQuestion({required String questionId, required String? sessionId}) async {
    final owner = sessionId ?? _tracker.forms.where((form) => form.id == questionId).firstOrNull?.sessionID;
    if (owner == null) {
      throw const PluginOperationException(
        "rejectQuestion",
        statusCode: 404,
        message: "OpenCode form is no longer pending.",
      );
    }
    await _repository.cancelForm(sessionId: owner, formId: questionId);
    _tracker.removeForm(formId: questionId);
  }

  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) async {
    await _repository.replyToPermission(sessionId: sessionId, requestId: requestId, reply: reply);
    _tracker.removePermission(requestId: requestId);
  }

  Future<String> _directory({required String sessionId}) async =>
      _tracker.session(sessionId: sessionId)?.directory ??
      (await _repository.getSession(sessionId: sessionId)).directory;

  Future<List<BridgeSseEvent>> handleEvent({required V2EventEnvelope envelope}) async {
    final event = envelope.data;
    final sessionId = switch (event) {
      final V2SessionEventData scoped => _sessionId(event: scoped),
      _ => null,
    };
    final deleted = event is V2SessionDeleted ? _tracker.session(sessionId: event.sessionID) : null;
    var changed = _tracker.apply(event: event);
    final result = _mapper.map(envelope: envelope);

    if (sessionId != null &&
        event is! V2SessionDeleted &&
        (_tracker.session(sessionId: sessionId) == null || event is V2SessionCreated || event is V2SessionRenamed)) {
      try {
        changed =
            _tracker.rememberSession(session: await _repository.getSessionDetails(sessionId: sessionId)) || changed;
      } catch (error, stack) {
        // A metadata lookup must not suppress a native status or input request.
        Log.w("OpenCode v2 session metadata failed for $sessionId", error, stack);
      }
    }
    if (sessionId != null) {
      final session = deleted ?? _tracker.session(sessionId: sessionId);
      if (session != null) {
        if (_mapper.mapSession(event: event, session: session) case final projected?) result.add(projected);
      }
    }
    result.addAll(
      _mapper.mapInput(
        event: event,
        displaySessionId: sessionId == null ? null : _tracker.rootSessionId(sessionId: sessionId),
      ),
    );
    try {
      result.addAll(
        await _enrich(
          envelope: envelope,
          directory: sessionId == null
              ? null
              : _tracker.session(sessionId: sessionId)?.directory ?? envelope.location?.directory,
        ),
      );
    } catch (error, stack) {
      Log.w(
        "OpenCode v2 event enrichment failed (${event.runtimeType}, session=$sessionId, event=${envelope.id})",
        error,
        stack,
      );
    }
    // Creation is authoritative even when its full session details are unavailable.
    if (changed || event is V2SessionCreated) result.add(const BridgeSseProjectUpdated());
    return result;
  }

  Future<List<BridgeSseEvent>> _enrich({required V2EventEnvelope envelope, required String? directory}) async {
    final event = envelope.data;
    if (event is V2SessionSynthetic) {
      return _mapper.mapNotice(
        envelope: envelope,
        agentNames: const V2AgentNames(namesById: {}),
      );
    }
    if (directory == null) return const [];
    switch (event) {
      case V2SessionStepStarted():
        return _mapper.mapAssistantStarted(
          event: event,
          agentNames: await _repository.getAgentNames(directory: directory),
        );
      case V2SessionAgentSelected():
        return _mapper.mapNotice(
          envelope: envelope,
          agentNames: await _repository.getAgentNames(directory: directory),
        );
      case V2SessionToolCalled(:final sessionID, :final assistantMessageID, :final id) ||
          V2SessionToolProgress(:final sessionID, :final assistantMessageID, :final id) ||
          V2SessionToolSuccess(:final sessionID, :final assistantMessageID, :final id) ||
          V2SessionToolFailed(:final sessionID, :final assistantMessageID, :final id):
        final message = await _repository.getMessage(
          sessionId: sessionID,
          messageId: assistantMessageID,
          directory: directory,
        );
        return message == null ? const [] : _mapper.mapToolSnapshot(toolId: id, message: message);
      case V2SessionStepEnded(:final sessionID, :final assistantMessageID) ||
          V2SessionStepFailed(:final sessionID, :final assistantMessageID):
        final message = await _repository.getMessage(
          sessionId: sessionID,
          messageId: assistantMessageID,
          directory: directory,
        );
        return message == null ? const [] : _mapper.mapAssistantSnapshot(message: message);
      case V2SessionExecutionSucceeded(:final sessionID) ||
          V2SessionExecutionFailed(:final sessionID) ||
          V2SessionExecutionInterrupted(:final sessionID):
        final message = await _repository.getLatestMessage(
          sessionId: sessionID,
          filter: V2MessageFilter.assistant,
          directory: directory,
        );
        return message == null ? const [] : _mapper.mapAssistantSnapshot(message: message);
      case V2SessionCompactionStarted(:final sessionID) ||
          V2SessionCompactionEnded(:final sessionID) ||
          V2SessionCompactionFailed(:final sessionID):
        final message = await _repository.getLatestMessage(
          sessionId: sessionID,
          filter: V2MessageFilter.compaction,
          directory: directory,
        );
        return message == null ? const [] : _mapper.mapMessageSnapshot(message: message);
      case V2SessionInboxDelivered():
        final message = await _repository.getMessage(
          sessionId: event.sessionID,
          messageId: event.inboxID,
          directory: directory,
        );
        return message == null ? const [] : _mapper.mapMessageSnapshot(message: message);
      default:
        return const [];
    }
  }

  // The generated session marker has no common getter; forms nest their ID.
  String _sessionId({required V2SessionEventData event}) => switch (event) {
    V2FormCreated(:final form) => form.sessionID,
    V2SessionCreated(:final sessionID) ||
    V2SessionRenamed(:final sessionID) ||
    V2SessionDeleted(:final sessionID) ||
    V2SessionExecutionStarted(:final sessionID) ||
    V2SessionExecutionSucceeded(:final sessionID) ||
    V2SessionExecutionFailed(:final sessionID) ||
    V2SessionExecutionInterrupted(:final sessionID) ||
    V2SessionInboxEnqueued(:final sessionID) ||
    V2SessionInboxDelivered(:final sessionID) ||
    V2SessionInboxCancelled(:final sessionID) ||
    V2SessionInboxDeliveryChanged(:final sessionID) ||
    V2SessionAgentSelected(:final sessionID) ||
    V2SessionSynthetic(:final sessionID) ||
    V2SessionStepStarted(:final sessionID) ||
    V2SessionStepEnded(:final sessionID) ||
    V2SessionStepFailed(:final sessionID) ||
    V2SessionTextStarted(:final sessionID) ||
    V2SessionTextDelta(:final sessionID) ||
    V2SessionTextEnded(:final sessionID) ||
    V2SessionReasoningStarted(:final sessionID) ||
    V2SessionReasoningDelta(:final sessionID) ||
    V2SessionReasoningEnded(:final sessionID) ||
    V2SessionToolInputStarted(:final sessionID) ||
    V2SessionToolInputDelta(:final sessionID) ||
    V2SessionToolInputEnded(:final sessionID) ||
    V2SessionToolCalled(:final sessionID) ||
    V2SessionToolProgress(:final sessionID) ||
    V2SessionToolSuccess(:final sessionID) ||
    V2SessionToolFailed(:final sessionID) ||
    V2SessionRetryScheduled(:final sessionID) ||
    V2SessionCompactionStarted(:final sessionID) ||
    V2SessionCompactionDelta(:final sessionID) ||
    V2SessionCompactionEnded(:final sessionID) ||
    V2SessionCompactionFailed(:final sessionID) ||
    V2PermissionAsked(:final sessionID) ||
    V2PermissionReplied(:final sessionID) ||
    V2FormReplied(:final sessionID) ||
    V2FormCancelled(:final sessionID) => sessionID,
  };

  List<PluginProjectActivitySummary> buildSummary() {
    // Match the bridge's root + direct-child activity contract, including an
    // input-only child while the root itself is idle.
    final groups = <String, Set<String>>{};
    for (final id in _tracker.workingSessionIds) {
      final session = _tracker.session(sessionId: id);
      if (session == null) continue;
      groups.putIfAbsent(session.parentID ?? id, () => {}).add(id);
    }
    final projects = <String, List<PluginActiveSession>>{};
    for (final root in groups.keys.toList()..sort()) {
      final members = groups[root]!;
      final session = _tracker.session(sessionId: root) ?? _tracker.session(sessionId: members.first)!;
      final children = members.where((id) => id != root).toList()..sort();
      projects
          .putIfAbsent(session.projectID, () => [])
          .add(
            PluginActiveSession(
              id: root,
              mainAgentRunning: _tracker.status(sessionId: root) != null,
              awaitingInput:
                  _tracker.hasPendingInput(sessionId: root) ||
                  children.any((id) => _tracker.hasPendingInput(sessionId: id)),
              isRetrying:
                  _tracker.status(sessionId: root) is PluginSessionStatusRetry ||
                  children.any((id) => _tracker.status(sessionId: id) is PluginSessionStatusRetry),
              childSessionIds: children,
            ),
          );
    }
    return [
      for (final id in projects.keys.toList()..sort())
        PluginProjectActivitySummary(id: id, activeSessions: projects[id]!),
    ];
  }
}
