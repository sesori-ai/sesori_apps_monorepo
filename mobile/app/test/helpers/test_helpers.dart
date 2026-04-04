import "dart:async";

import "package:firebase_crashlytics/firebase_crashlytics.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:http/http.dart" as http;
import "package:mocktail/mocktail.dart";
import "package:record/record.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/sesori_dart_core.dart" show AppRouteDef, RouteSource;
import "package:sesori_dart_core/src/api/client/relay_http_client.dart";
import "package:sesori_dart_core/src/capabilities/project/project_service.dart";
import "package:sesori_dart_core/src/capabilities/relay/relay_client.dart";
import "package:sesori_dart_core/src/capabilities/relay/room_key_storage.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/connection_service.dart";
import "package:sesori_dart_core/src/capabilities/server_connection/server_connection_config.dart";
import "package:sesori_dart_core/src/capabilities/session/session_service.dart";
import "package:sesori_dart_core/src/capabilities/sse/session_activity_info.dart";
import "package:sesori_dart_core/src/capabilities/sse/sse_event_repository.dart";
import "package:sesori_dart_core/src/capabilities/voice/voice_api.dart";
import "package:sesori_dart_core/src/platform/deep_link_source.dart";
import "package:sesori_dart_core/src/platform/lifecycle_source.dart";
import "package:sesori_dart_core/src/platform/notification_canceller.dart";
import "package:sesori_dart_core/src/routing/auth_redirect_service.dart";
import "package:sesori_mobile/capabilities/voice/audio_format_config.dart";
import "package:sesori_mobile/capabilities/voice/recording_file_provider.dart";
import "package:sesori_mobile/capabilities/voice/wake_lock_service.dart";
import "package:sesori_shared/sesori_shared.dart";

// ---------------------------------------------------------------------------
// Mock classes
// ---------------------------------------------------------------------------

class MockProjectService extends Mock implements ProjectService {}

class MockSessionService extends Mock implements SessionService {}

class MockConnectionService extends Mock implements ConnectionService {
  final StreamController<void> _dataMayBeStale = StreamController<void>.broadcast();

  @override
  Stream<void> get dataMayBeStale => _dataMayBeStale.stream;

  void emitDataMayBeStale() => _dataMayBeStale.add(null);
}

class MockOAuthFlowProvider extends Mock implements OAuthFlowProvider {}

class MockAuthSession extends Mock implements AuthSession {}

class MockAuthTokenProvider extends Mock implements AuthTokenProvider {}

class MockAuthenticatedHttpApiClient extends Mock implements AuthenticatedHttpApiClient {}

class MockRelayHttpApiClient extends Mock implements RelayHttpApiClient {}

class MockHttpApiClient extends Mock implements HttpApiClient {}

class MockRelayCryptoService extends Mock implements RelayCryptoService {}

class MockRoomKeyStorage extends Mock implements RoomKeyStorage {}

class MockRelayClient extends Mock implements RelayClient {}

class MockVoiceApi extends Mock implements VoiceApi {}

class MockAudioRecorder extends Mock implements AudioRecorder {}

class MockRecordingFileProvider extends Mock implements RecordingFileProvider {}

class MockWakeLockService extends Mock implements WakeLockService {}

class MockAudioFormatConfig extends Mock implements AudioFormatConfig {}

class MockAuthRedirectService extends Mock implements AuthRedirectService {}

class MockDeepLinkSource extends Mock implements DeepLinkSource {}

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

class MockSecureStorage extends Mock implements SecureStorage {}

class MockLifecycleSource extends Mock implements LifecycleSource {
  final BehaviorSubject<LifecycleState> _state = BehaviorSubject.seeded(LifecycleState.resumed);

  @override
  ValueStream<LifecycleState> get lifecycleStateStream => _state.stream;

  void emitState(LifecycleState state) => _state.add(state);
}

class MockNotificationCanceller extends Mock implements NotificationCanceller {}

class MockRouteSource extends Mock implements RouteSource {
  final BehaviorSubject<AppRouteDef?> _currentRoute;

  MockRouteSource({AppRouteDef? initialRoute}) : _currentRoute = BehaviorSubject.seeded(initialRoute);

  @override
  ValueStream<AppRouteDef?> get currentRouteStream => _currentRoute.stream;

  AppRouteDef? get currentRoute => _currentRoute.value;

  void emitRoute(AppRouteDef? route) => _currentRoute.add(route);
}

class MockSseEventRepository extends Mock implements SseEventRepository {
  final BehaviorSubject<Map<String, int>> _projectActivity = BehaviorSubject.seeded(const {});
  final BehaviorSubject<Map<String, Map<String, SessionActivityInfo>>> _sessionActivity = BehaviorSubject.seeded(
    const {},
  );

  @override
  ValueStream<Map<String, int>> get projectActivity => _projectActivity.stream;

  @override
  Map<String, int> get currentProjectActivity => _projectActivity.value;

  @override
  ValueStream<Map<String, Map<String, SessionActivityInfo>>> get sessionActivity => _sessionActivity.stream;

  @override
  Map<String, Map<String, SessionActivityInfo>> get currentSessionActivity => _sessionActivity.value;

  void emitProjectActivity(Map<String, int> activity) => _projectActivity.add(activity);

  void emitSessionActivity(Map<String, Map<String, SessionActivityInfo>> activity) => _sessionActivity.add(activity);
}

class MockFailureReporter extends Mock implements FailureReporter {}

class MockFirebaseCrashlytics extends Mock implements FirebaseCrashlytics {}

// ---------------------------------------------------------------------------
// Fake classes — for registerFallbackValue
// ---------------------------------------------------------------------------

class FakeUri extends Fake implements Uri {}

// ---------------------------------------------------------------------------
// registerAllFallbackValues
// ---------------------------------------------------------------------------

/// Registers all fallback values required by mocktail argument matchers.
///
/// Call once in [setUpAll] before any test group that uses [any()] or
/// [captureAny()] for [ServerConnectionConfig] or [Uri] parameters.
void registerAllFallbackValues() {
  registerFallbackValue(const ServerConnectionConfig(relayHost: "fake.example.com"));
  registerFallbackValue(FakeUri());
  registerFallbackValue(Duration.zero);
  registerFallbackValue(const RecordConfig());
  registerFallbackValue(http.MultipartFile.fromString("audio", ""));
  registerFallbackValue(OAuthProvider.github);
  registerFallbackValue(StackTrace.empty);
}

// ---------------------------------------------------------------------------
// Test data factories
// ---------------------------------------------------------------------------

/// Returns a realistic [Project] instance.
Project testProject({String? path, String? name}) {
  const projectPathField =
      "work"
      "tree";
  return Project.fromJson({
    "id": "project-1",
    projectPathField: path ?? "/home/user/my-project",
    "name": name,
    "time": {
      "created": 1700000000000,
      "updated": 1700000000000,
    },
  });
}

/// Returns a realistic [Session] instance.
Session testSession({
  String? id,
  String? title,
  String? parentID,
  int? createdAt,
  int? updatedAt,
  DateTime? archivedAt,
}) {
  return Session(
    id: id ?? "session-1",
    projectID: "project-1",
    directory: "/home/user/my-project",
    parentID: parentID,
    title: title,
    summary: null,
    pullRequest: null,
    time: SessionTime(
      created: createdAt ?? 1700000000000,
      updated: updatedAt ?? 1700000000000,
      archived: archivedAt?.millisecondsSinceEpoch,
    ),
  );
}

/// Returns a realistic [HealthResponse] with [healthy] = true.
HealthResponse testHealthResponse() {
  return const HealthResponse(healthy: true, version: "0.1.200");
}

/// Returns a realistic [MessageWithParts] instance.
MessageWithParts testMessageWithParts({String? id}) {
  final messageId = id ?? "msg-1";
  return MessageWithParts(
    info: Message(
      id: messageId,
      role: "assistant",
      sessionID: "session-1",
      agent: null,
      modelID: null,
      providerID: null,
    ),
    parts: [
      MessagePart(
        id: "part-1",
        sessionID: "session-1",
        messageID: messageId,
        type: MessagePartType.text,
        text: "Hello, world!",
        tool: null,
        state: null,
        prompt: null,
        description: null,
        agent: null,
        agentName: null,
        attempt: null,
        retryError: null,
      ),
    ],
  );
}

/// Returns a realistic [SesoriQuestionAsked] event with a single question.
SesoriQuestionAsked testSseQuestionAsked() {
  return const SesoriQuestionAsked(
    id: "question-1",
    sessionID: "session-1",
    questions: [
      QuestionInfo(
        question: "Which option would you like?",
        header: "Please choose",
        options: [
          QuestionOption(label: "Yes", description: "Proceed"),
          QuestionOption(label: "No", description: "Cancel"),
        ],
      ),
    ],
  );
}

/// Returns a realistic [PendingQuestion] payload from `GET /question`.
PendingQuestion testPendingQuestion() {
  return const PendingQuestion(
    id: "question-1",
    sessionID: "session-1",
    questions: [
      QuestionInfo(
        question: "Which option would you like?",
        header: "Please choose",
        options: [
          QuestionOption(label: "Yes", description: "Proceed"),
          QuestionOption(label: "No", description: "Cancel"),
        ],
      ),
    ],
  );
}

/// Returns a realistic [SesoriQuestionAsked] event with multiple questions,
/// useful for testing the multi-question stepping flow.
SesoriQuestionAsked testMultiSseQuestionAsked({
  String id = "question-multi",
  String sessionID = "session-1",
}) {
  return SesoriQuestionAsked(
    id: id,
    sessionID: sessionID,
    questions: const [
      QuestionInfo(
        question: "Which language do you prefer?",
        header: "Language",
        options: [
          QuestionOption(label: "Dart", description: "Flutter language"),
          QuestionOption(label: "Kotlin", description: "Android language"),
        ],
      ),
      QuestionInfo(
        question: "Which IDE do you use?",
        header: "IDE",
        options: [
          QuestionOption(label: "VS Code", description: "Microsoft editor"),
          QuestionOption(label: "IntelliJ", description: "JetBrains IDE"),
        ],
      ),
      QuestionInfo(
        question: "Any additional notes?",
        header: "Notes",
        options: [],
        custom: true,
      ),
    ],
  );
}

/// Returns a realistic [AgentInfo] instance.
AgentInfo testAgentInfo() {
  return const AgentInfo(
    name: "coder",
    description: "A coding assistant",
    model: null,
    variant: null,
    mode: AgentMode.primary,
  );
}

/// Returns a realistic [ProviderListResponse] with one provider and one model.
ProviderListResponse testProviderListResponse() {
  return const ProviderListResponse(
    connectedOnly: false,
    items: [
      ProviderInfo(
        id: "anthropic",
        name: "Anthropic",
        defaultModelID: "claude-3-5-sonnet",
        models: {
          "claude-3-5-sonnet": ProviderModel(
            id: "claude-3-5-sonnet",
            providerID: "anthropic",
            name: "Claude 3.5 Sonnet",
            family: null,
            releaseDate: null,
          ),
        },
      ),
    ],
  );
}

/// Returns a realistic [AuthUser] instance.
AuthUser testAuthUser() {
  return const AuthUser(
    id: "user-1",
    provider: "github",
    providerUserId: "12345678",
    providerUsername: "testuser",
  );
}
