import "dart:async";
import "dart:io" as io;

import "package:http/io_client.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show Harness;

import "../open_code_raw_http_client.dart";
import "../runtime/open_code_managed_api.dart";
import "../sse/sse_connection.dart";
import "api/opencode_v2_api.dart";
import "mappers/v2_form_answer_mapper.dart";
import "mappers/v2_form_answer_validator.dart";
import "repositories/opencode_v2_activity_tracker.dart";
import "repositories/opencode_v2_repository.dart";
import "repositories/v2_message_mapper.dart";
import "repositories/v2_model_mapper.dart";
import "services/opencode_v2_service.dart";
import "sse/v2_event_mapper.dart";
import "sse/v2_event_parser.dart";

/// V2 composition and transport lifetime. Domain behavior stays in the service.
class OpenCodeV2Plugin._({
  required final OpenCodeV2Service _service,
  required final io.HttpClient _httpClient,
  required String serverUrl,
  required String? password,
  required void Function() onConnected,
  required void Function() onDisconnected,
}) implements OpenCodeManagedApi {
  static final _id = Harness.opencode.name;
  static const _parser = V2EventParser();
  final _eventBuffer = BufferedUntilFirstListener<BridgeSseEvent>();
  final _workState = PluginWorkStateController(initial: PluginWorkState.unknown);
  late final SseConnection _sseConnection;
  Future<void>? _initializeFuture;
  bool _disposed = false;

  factory({
    required String serverUrl,
    required String? password,
    required void Function() onConnected,
    required void Function() onDisconnected,
  }) {
    final httpClient = io.HttpClient();
    final modelMapper = V2ModelMapper(pluginId: _id);
    const messageMapper = V2MessageMapper();
    final repository = OpenCodeV2Repository(
      api: OpenCodeV2Api(
        client: OpenCodeRawHttpClient(serverURL: serverUrl, password: password, client: IOClient(httpClient)),
      ),
      modelMapper: modelMapper,
      messageMapper: messageMapper,
    );
    return OpenCodeV2Plugin._(
      service: OpenCodeV2Service(
        repository: repository,
        tracker: OpenCodeV2ActivityTracker(),
        mapper: V2EventMapper(modelMapper: modelMapper, messageMapper: messageMapper),
        modelMapper: modelMapper,
        formAnswerMapper: const V2FormAnswerMapper(),
        formAnswerValidator: const V2FormAnswerValidator(),
      ),
      httpClient: httpClient,
      serverUrl: serverUrl,
      password: password,
      onConnected: onConnected,
      onDisconnected: onDisconnected,
    );
  }

  this {
    _sseConnection = SseConnection(
      targetUrl: serverUrl,
      eventPath: "/api/event",
      password: password,
      onEvent: _handleEvent,
      onReconnect: _refresh,
      onConnected: onConnected,
      onDisconnected: () {
        _service.invalidateBaseline();
        _syncWorkState();
        onDisconnected();
      },
    );
  }

  @override
  String get id => _id;
  @override
  Stream<BridgeSseEvent> get events => _eventBuffer.stream;
  @override
  Stream<PluginWorkState> get workState => _workState.stream;
  @override
  PluginWorkState get currentWorkState => _workState.current;

  @override
  Future<void> initialize() => _initializeFuture ??= _initialize();

  Future<void> _initialize() async {
    ({Object error, StackTrace stackTrace})? failure;
    try {
      await _refresh();
    } on Object catch (error, stackTrace) {
      failure = (error: error, stackTrace: stackTrace);
    }
    if (!_disposed) {
      _sseConnection.start(recoverOnFirstConnect: failure != null);
      if (failure == null) await _sseConnection.firstConnected;
    }
    if (failure case (:final error, :final stackTrace)?) Error.throwWithStackTrace(error, stackTrace);
  }

  Future<void> _refresh() async {
    try {
      await _service.coldStart();
      if (!_disposed) _eventBuffer.add(const BridgeSseProjectUpdated());
    } finally {
      if (!_disposed) _syncWorkState();
    }
  }

  Future<void> _handleEvent(String rawData) async {
    if (_disposed) return;
    final envelope = _parser.parse(rawData: rawData);
    if (envelope == null) return;
    final events = await _service.handleEvent(envelope: envelope);
    if (_disposed) return;
    _syncWorkState();
    events.forEach(_eventBuffer.add);
  }

  void _syncWorkState() => _workState.set(_service.workState);

  Future<void> _reply({required Future<void> request}) async {
    await request;
    if (_disposed) return;
    _syncWorkState();
    _eventBuffer.add(const BridgeSseProjectUpdated());
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _sseConnection.stop();
    _httpClient.close(force: true);
    _service.reset();
    await Future.wait([_eventBuffer.close(), _workState.close()]);
  }

  @override
  Future<Set<String>> interruptActiveWork({required Duration budget}) => () async {
    final ids = await _service.interruptActiveWork();
    if (ids.isNotEmpty && currentWorkState != PluginWorkState.idle) {
      await workState.firstWhere((state) => state == PluginWorkState.idle);
    }
    return ids;
  }().timeout(budget);

  @override
  Future<void> warmUpCommandCatalog() async {
    if (!_disposed) await _service.getCommands(projectId: null);
  }

  @override
  Future<bool> healthCheck() => _service.healthCheck();
  @override
  Future<List<PluginProject>> getProjects() => _service.getProjects();
  @override
  Future<PluginProject> getProject(String projectId) => _service.getProject(projectId: projectId);
  @override
  Future<PluginProject> renameProject({required String projectId, required String name}) =>
      _service.renameProject(projectId: projectId, name: name);
  @override
  Future<List<PluginSession>> getSessions({required String projectId, required int? start, required int? limit}) =>
      _service.getSessions(projectId: projectId, start: start, limit: limit);
  @override
  Future<List<PluginSession>> getChildSessions(String sessionId) => _service.getChildSessions(sessionId: sessionId);
  @override
  Future<Map<String, PluginSessionStatus>> getSessionStatuses() => _service.getSessionStatuses();
  @override
  Future<List<PluginMessageWithParts>> getSessionMessages(String sessionId) =>
      _service.getMessages(sessionId: sessionId);
  @override
  Future<List<PluginAgent>> getAgents({required String projectId}) => _service.getAgents(projectId: projectId);
  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) =>
      _service.getProviders(projectId: projectId);
  @override
  Future<List<PluginCommand>> getCommands({required String? projectId}) => _service.getCommands(projectId: projectId);
  @override
  Future<PluginSessionOptionsDiscoveryResult> getSessionOptions({
    required String projectId,
    required PluginSessionOptionsDiscoveryMode discoveryMode,
  }) => _service.getSessionOptions(projectId: projectId);

  @override
  Future<PluginSession> createSession({
    required String directory,
    required String? parentSessionId,
    required List<PluginPromptPart> parts,
    required String? userVisibleText,
    required PluginSessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) => _service.createSession(
    directory: directory,
    parentSessionId: parentSessionId,
    parts: parts,
    agent: agent,
    model: model,
    variant: variant,
  );
  @override
  Future<PluginSession> renameSession({required String sessionId, required String title}) =>
      _service.renameSession(sessionId: sessionId, title: title);
  @override
  Future<void> deleteSession(String sessionId) => _service.deleteSession(sessionId: sessionId);
  @override
  Future<void> archiveSession({required String sessionId}) => _service.archiveSession(sessionId: sessionId);
  @override
  Future<void> deleteWorkspace({required String projectId, required String worktreePath}) =>
      _service.deleteWorkspace(projectId: projectId, worktreePath: worktreePath);

  @override
  Future<void> sendPrompt({
    required String sessionId,
    required String promptId,
    required List<PluginPromptPart> parts,
    required PluginSessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) => _service.sendPrompt(
    sessionId: sessionId,
    promptId: promptId,
    parts: parts,
    agent: agent,
    model: model,
    variant: variant,
  );
  @override
  Future<void> sendCommand({
    required String sessionId,
    required String promptId,
    required String command,
    required String arguments,
    required String? userVisibleArguments,
    required PluginSessionVariant? variant,
    required bool fastMode,
    required String? agent,
    required ({String providerID, String modelID})? model,
  }) => _service.sendCommand(
    sessionId: sessionId,
    promptId: promptId,
    command: command,
    arguments: arguments,
    userVisibleArguments: userVisibleArguments,
    agent: agent,
    model: model,
    variant: variant,
  );
  @override
  Future<PluginAbortResult> abortSession({
    required String sessionId,
    required PluginAbortSubAgentPolicy subAgents,
    required bool useAtomicStop,
    required Set<String> knownSubAgentSessionIds,
  }) => _service.abortSession(sessionId: sessionId, subAgents: subAgents);
  @override
  Future<List<PluginPendingQuestion>> getPendingQuestions({required String sessionId}) =>
      _service.getPendingQuestions(sessionId: sessionId);
  @override
  Future<List<PluginPendingPermission>> getPendingPermissions({required String sessionId}) =>
      _service.getPendingPermissions(sessionId: sessionId);
  @override
  Future<List<PluginPendingQuestion>> getProjectQuestions({required String projectId}) =>
      _service.getProjectQuestions(projectId: projectId);
  @override
  Future<void> replyToQuestion({
    required String questionId,
    required String sessionId,
    required List<List<String>> answers,
  }) => _reply(
    request: _service.replyToQuestion(questionId: questionId, sessionId: sessionId, answers: answers),
  );
  @override
  Future<void> rejectQuestion({required String questionId, required String? sessionId}) => _reply(
    request: _service.rejectQuestion(questionId: questionId, sessionId: sessionId),
  );
  @override
  Future<void> replyToPermission({
    required String requestId,
    required String sessionId,
    required PluginPermissionReply reply,
  }) => _reply(
    request: _service.replyToPermission(requestId: requestId, sessionId: sessionId, reply: reply),
  );
  @override
  List<PluginProjectActivitySummary> getActiveSessionsSummary() => _service.buildSummary();
  @override
  Future<List<PluginQueuedPrompt>> getQueuedPrompts({required String sessionId}) async => const [];
  @override
  Future<bool> cancelQueuedPrompt({required String sessionId, required String promptId}) async => false;
  @override
  Future<PluginQuotaContinuationReadiness> getQuotaContinuationReadiness({required String sessionId}) async =>
      PluginQuotaContinuationReadiness.unavailable;
}
