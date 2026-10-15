import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/services/session_external_action_service.dart";
import "package:sesori_dart_core/testing.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

const action = PendingExternalAction(
  id: "request",
  sessionID: "owner",
  displaySessionId: "display",
  title: "Fixture MCP",
  message: "Continue in the browser",
  authorizationUrl: "https://fixture.example/authorize?private=fixture-only",
  purpose: ExternalActionPurpose.authorization,
  choices: [ExternalActionChoice.accept, ExternalActionChoice.decline, ExternalActionChoice.cancel],
);

void main() {
  setUpAll(
    () => registerFallbackValue(
      const ReplyToExternalActionRequest(
        requestId: "request",
        sessionId: "owner",
        choice: ExternalActionChoice.cancel,
      ),
    ),
  );
  late MockSessionRepository repository;
  late SessionExternalActionService service;
  setUp(() {
    repository = MockSessionRepository();
    service = SessionExternalActionService(repository: repository);
    when(() => repository.getPendingExternalActions(sessionId: any(named: "sessionId")))
        .thenAnswer((_) async => ApiResponse.success(const PendingExternalActionsResponse(data: [action])));
  });
  test("request reads retain the original owner and exclude a display parent", () async {
    expect(await service.read(requestId: "request", sessionId: "owner"), action);
    expect(await service.read(requestId: "request", sessionId: "display"), isNull);
    expect(await service.read(requestId: "missing", sessionId: "owner"), isNull);
  });
  test("safe browser destination retains request-scoped query without displaying it", () {
    expect(service.browserDestination(action: action)?.query, "private=fixture-only");
  });
  for (final url in [
    "http://fixture.example",
    "javascript:alert(1)",
    "/relative",
    "https://user@fixture.example",
    "https:///missing-host",
  ]) {
    test("unsafe destination $url cannot be opened or accepted", () async {
      final unsafe = PendingExternalAction(
        id: action.id,
        sessionID: action.sessionID,
        displaySessionId: action.displaySessionId,
        title: action.title,
        message: action.message,
        authorizationUrl: url,
        purpose: action.purpose,
        choices: action.choices,
      );
      expect(service.browserDestination(action: unsafe), isNull);
      expect(
        await service.reply(action: unsafe, choice: ExternalActionChoice.accept),
        isA<ExternalActionUnsupportedChoice>(),
      );
      verifyNever(() => repository.replyToExternalAction(request: any(named: "request")));
    });
  }
  test("native reply preserves original owner, request and exact declared choice", () async {
    when(() => repository.replyToExternalAction(request: any(named: "request")))
        .thenAnswer((_) async => ApiResponse.success(const ExternalActionReplyAccepted()));
    expect(
      await service.reply(action: action, choice: ExternalActionChoice.cancel),
      isA<ExternalActionReplyAccepted>(),
    );
    final request =
        verify(() => repository.replyToExternalAction(request: captureAny(named: "request"))).captured.single
            as ReplyToExternalActionRequest;
    expect(request.requestId, "request");
    expect(request.sessionId, "owner");
    expect(request.choice, ExternalActionChoice.cancel);
  });
  test("API failure retains its typed cause", () async {
    final error = NonSuccessCodeError(errorCode: 503, rawErrorString: null);
    when(() => repository.getPendingExternalActions(sessionId: "owner"))
        .thenAnswer((_) async => ApiResponse.error(error));
    await expectLater(service.read(requestId: "request", sessionId: "owner"), throwsA(same(error)));
  });
}
