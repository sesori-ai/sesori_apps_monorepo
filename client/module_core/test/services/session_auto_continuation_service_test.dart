import "package:mocktail/mocktail.dart";
import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_dart_core/src/api/session_api.dart";
import "package:sesori_dart_core/src/repositories/session_repository.dart";
import "package:sesori_dart_core/src/services/session_auto_continuation_service.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "../helpers/test_helpers.dart";

void main() {
  late MockRelayHttpApiClient client;
  late SessionAutoContinuationService service;
  setUp(() {
    client = MockRelayHttpApiClient();
    service = SessionAutoContinuationService(
      repository: SessionRepository(api: SessionApi(client: client)),
    );
  });

  void reply({required ApiResponse<Session> response}) {
    when(
      () => client.patch<Session>(
        any(),
        fromJson: any(named: "fromJson"),
        body: any(named: "body"),
      ),
    ).thenAnswer((_) async => response);
  }

  test("uses the shared route and returns the acknowledged session", () async {
    final session = testSession(id: "session-1").copyWith(
      autoContinuation: const SessionAutoContinuationView(
        enabled: true,
        availability: AutoContinuationAvailability.conditional,
        status: SessionAutoContinuationStatus.idle(),
      ),
    );
    when(
      () => client.patch<Session>(
        any(),
        fromJson: any(named: "fromJson"),
        body: any(named: "body"),
      ),
    ).thenAnswer((invocation) async {
      final parse = invocation.namedArguments[#fromJson]! as Session Function(Map<String, dynamic>);
      return ApiResponse.success(parse(session.toJson()));
    });
    expect(await service.setEnabled(sessionId: "session-1", enabled: true), session);
    verify(
      () => client.patch<Session>(
        "/session/auto-continuation",
        fromJson: any(named: "fromJson"),
        body: const SetSessionAutoContinuationRequest(sessionId: "session-1", enabled: true),
      ),
    ).called(1);
  });

  for (final code in [405, 501]) {
    test("maps HTTP $code to unavailable without losing the original error", () async {
      final error = ApiError.nonSuccessCode(errorCode: code, rawErrorString: null);
      reply(response: ApiResponse.error(error));
      await expectLater(
        service.setEnabled(sessionId: "session-1", enabled: true),
        throwsA(isA<SessionAutoContinuationUnavailableException>().having((e) => e.innerError, "cause", same(error))),
      );
    });
  }

  test("recognizes a legacy route-not-found response", () async {
    final error = ApiError.nonSuccessCode(
      errorCode: 404,
      rawErrorString: "no handler found for PATCH /session/auto-continuation",
    );
    reply(response: ApiResponse.error(error));
    await expectLater(
      service.setEnabled(sessionId: "session-1", enabled: true),
      throwsA(isA<SessionAutoContinuationUnavailableException>().having((e) => e.innerError, "cause", same(error))),
    );
  });

  test("retains a missing-session failure from a supported route", () async {
    final error = ApiError.nonSuccessCode(errorCode: 404, rawErrorString: "session session-1 was not found");
    reply(response: ApiResponse.error(error));
    await expectLater(service.setEnabled(sessionId: "session-1", enabled: true), throwsA(same(error)));
  });

  test("retains transport failures", () async {
    final error = ApiError.generic();
    reply(response: ApiResponse.error(error));
    await expectLater(service.setEnabled(sessionId: "session-1", enabled: false), throwsA(same(error)));
  });
}
