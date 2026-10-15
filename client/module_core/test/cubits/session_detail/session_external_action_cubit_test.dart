import "dart:async";

import "package:mocktail/mocktail.dart";
import "package:rxdart/rxdart.dart";
import "package:sesori_dart_core/sesori_dart_core.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../../services/session_external_action_service_test.dart" show action;

const connected = ConnectionStatus.connected(
  config: ServerConnectionConfig(relayHost: "fixture", authToken: "fixture", bridgeId: "first"),
  health: HealthResponse(healthy: true, version: "1.9.2", filesystemAccessDegraded: false),
);
const replaced = ConnectionStatus.connected(
  config: ServerConnectionConfig(relayHost: "fixture", authToken: "fixture", bridgeId: "second"),
  health: HealthResponse(healthy: true, version: "1.9.2", filesystemAccessDegraded: false),
);

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse("https://fixture.example"));
    registerFallbackValue(
      const ReplyToExternalActionRequest(requestId: "request", sessionId: "owner", choice: ExternalActionChoice.cancel),
    );
  });
  late MockSessionRepository repository;
  late MockConnectionService connection;
  late MockUrlLauncher launcher;
  late BehaviorSubject<ConnectionStatus> statuses;
  setUp(() {
    repository = MockSessionRepository();
    connection = MockConnectionService();
    launcher = MockUrlLauncher();
    statuses = BehaviorSubject.seeded(connected);
    when(() => connection.currentStatus).thenAnswer((_) => statuses.value);
    when(() => connection.status).thenAnswer((_) => statuses);
    when(() => repository.getPendingExternalActions(sessionId: "owner"))
        .thenAnswer((_) async => ApiResponse.success(const PendingExternalActionsResponse(data: [action])));
    when(() => repository.replyToExternalAction(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.success(const ExternalActionReplyAccepted()));
    when(() => launcher.launch(any(), mode: UrlLaunchMode.externalApp)).thenAnswer((_) async => true);
    addTearDown(statuses.close);
  });
  SessionExternalActionCubit create() {
    final cubit = SessionExternalActionCubit(
      service: SessionExternalActionService(repository: repository),
      connectionService: connection,
      urlLauncher: launcher,
      requestId: "request",
      sessionId: "owner",
    );
    addTearDown(cubit.close);
    return cubit;
  }

  Future<void> ready(SessionExternalActionCubit cubit) async {
    if (cubit.state is ExternalActionReady) return;
    await cubit.stream.firstWhere((s) => s is ExternalActionReady).timeout(const Duration(seconds: 5));
  }

  Future<void> disconnected(SessionExternalActionCubit cubit) async {
    if (cubit.state is ExternalActionDisconnected) return;
    await cubit.stream.firstWhere((s) => s is ExternalActionDisconnected).timeout(const Duration(seconds: 5));
  }

  test("opening reads without browser intent; explicit launch is separate from native reply", () async {
    final cubit = create();
    await ready(cubit);
    verifyNever(() => launcher.launch(any(), mode: UrlLaunchMode.externalApp));
    await cubit.openBrowser();
    expect((cubit.state as ExternalActionReady).browser, isA<ExternalActionBrowserOpened>());
    verifyNever(() => repository.replyToExternalAction(request: any(named: "request")));
    await cubit.reply(choice: ExternalActionChoice.accept);
    expect(cubit.state, isA<ExternalActionReplySent>());
    final request =
        verify(() => repository.replyToExternalAction(request: captureAny(named: "request"))).captured.single
            as ReplyToExternalActionRequest;
    expect(request.sessionId, "owner");
    expect(request.choice, ExternalActionChoice.accept);
  });
  test("failed launch keeps the same request and can be retried", () async {
    final cubit = create();
    await ready(cubit);
    when(() => launcher.launch(any(), mode: UrlLaunchMode.externalApp)).thenAnswer((_) async => false);
    await cubit.openBrowser();
    expect((cubit.state as ExternalActionReady).browser, isA<ExternalActionBrowserFailed>());
    when(() => launcher.launch(any(), mode: UrlLaunchMode.externalApp)).thenAnswer((_) async => true);
    await cubit.openBrowser();
    expect((cubit.state as ExternalActionReady).browser, isA<ExternalActionBrowserOpened>());
  });
  test("thrown browser failures retain their original cause and stack", () async {
    final error = StateError("Cannot open ${action.authorizationUrl}");
    final stack = StackTrace.current;
    when(() => launcher.launch(any(), mode: UrlLaunchMode.externalApp)).thenAnswer((_) => Future.error(error, stack));
    final cubit = create();
    await ready(cubit);
    await cubit.openBrowser();
    final browser = (cubit.state as ExternalActionReady).browser as ExternalActionBrowserFailed;
    expect(browser.cause.innerError, same(error));
    expect(browser.stackTrace.toString(), stack.toString());
    expect(browser.cause.toString(), isNot(contains("private=fixture-only")));
  });

  test("pending native reply blocks duplicate intent and preserves exact choice", () async {
    final response = Completer<ApiResponse<ExternalActionReplyResult>>();
    when(() => repository.replyToExternalAction(request: any(named: "request"))).thenAnswer((_) => response.future);
    final cubit = create();
    await ready(cubit);
    final first = cubit.reply(choice: ExternalActionChoice.decline);
    await cubit.reply(choice: ExternalActionChoice.accept);
    response.complete(ApiResponse.success(const ExternalActionReplyAccepted()));
    await first;
    expect((cubit.state as ExternalActionReplySent).choice, ExternalActionChoice.decline);
    verify(() => repository.replyToExternalAction(request: any(named: "request"))).called(1);
  });
  test("lost native response retains typed cause and never claims settlement", () async {
    final error = NonSuccessCodeError(errorCode: 503, rawErrorString: null);
    when(() => repository.replyToExternalAction(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.error(error));
    final cubit = create();
    await ready(cubit);
    await cubit.reply(choice: ExternalActionChoice.cancel);
    expect(((cubit.state as ExternalActionReady).submission as ExternalActionSubmissionFailed).cause, same(error));
  });
  test("disconnect during read retires the observer even after reconnect", () async {
    final response = Completer<ApiResponse<PendingExternalActionsResponse>>();
    when(() => repository.getPendingExternalActions(sessionId: "owner")).thenAnswer((_) => response.future);
    final cubit = create();
    statuses.add(const ConnectionStatus.disconnected());
    await disconnected(cubit);
    statuses.add(connected);
    response.complete(ApiResponse.success(const PendingExternalActionsResponse(data: [action])));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state, isA<ExternalActionDisconnected>());
    await cubit.reply(choice: ExternalActionChoice.accept);
    verifyNever(() => repository.replyToExternalAction(request: any(named: "request")));
  });
  test("bridge replacement during consent ignores a late acceptance", () async {
    final response = Completer<ApiResponse<ExternalActionReplyResult>>();
    when(() => repository.replyToExternalAction(request: any(named: "request"))).thenAnswer((_) => response.future);
    final cubit = create();
    await ready(cubit);
    final submitted = cubit.reply(choice: ExternalActionChoice.accept);
    statuses.add(replaced);
    await disconnected(cubit);
    response.complete(ApiResponse.success(const ExternalActionReplyAccepted()));
    await submitted;
    expect(cubit.state, isA<ExternalActionDisconnected>());
  });
  test("bridge replacement during browser launch cannot restore controls", () async {
    final launched = Completer<bool>();
    when(() => launcher.launch(any(), mode: UrlLaunchMode.externalApp)).thenAnswer((_) => launched.future);
    final cubit = create();
    await ready(cubit);
    final opening = cubit.openBrowser();
    await cubit.openBrowser();
    statuses.add(replaced);
    await disconnected(cubit);
    launched.complete(true);
    await opening;
    expect(cubit.state, isA<ExternalActionDisconnected>());
    verify(() => launcher.launch(any(), mode: UrlLaunchMode.externalApp)).called(1);
  });
  test("closing during a read ignores late data and sends no native cancellation", () async {
    final response = Completer<ApiResponse<PendingExternalActionsResponse>>();
    when(() => repository.getPendingExternalActions(sessionId: "owner")).thenAnswer((_) => response.future);
    final cubit = create();
    await cubit.close();
    response.complete(ApiResponse.success(const PendingExternalActionsResponse(data: [action])));
    await Future<void>.delayed(Duration.zero);
    expect(cubit.isClosed, isTrue);
    verifyNever(() => repository.replyToExternalAction(request: any(named: "request")));
  });
}
