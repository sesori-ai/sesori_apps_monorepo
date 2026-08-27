import "package:sesori_bridge/src/routing/populate_project_glossary_handler.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

import "routing_test_helpers.dart";

void main() {
  late FakeProjectGlossaryService service;
  late PopulateProjectGlossaryHandler handler;

  setUp(() {
    service = FakeProjectGlossaryService();
    handler = PopulateProjectGlossaryHandler(projectGlossaryService: service);
  });

  test("handles the explicit project voice-glossary route", () {
    expect(handler.canHandle(makeRequest("POST", "/project/voice-glossary/populate")), isTrue);
    expect(handler.canHandle(makeRequest("GET", "/project/voice-glossary/populate")), isFalse);
  });

  test("schedules project work and returns immediately", () async {
    final response = await handler.handle(
      makeRequest("POST", "/project/voice-glossary/populate"),
      body: const ProjectIdRequest(projectId: "project-1"),
    );

    expect(response, const SuccessEmptyResponse());
    expect(service.scheduledProjectIds, ["project-1"]);
  });

  test("rejects an empty project id", () async {
    await expectLater(
      () => handler.handle(
        makeRequest("POST", "/project/voice-glossary/populate"),
        body: const ProjectIdRequest(projectId: ""),
      ),
      throwsA(isA<RelayResponse>().having((response) => response.status, "status", 400)),
    );
    expect(service.scheduledProjectIds, isEmpty);
  });
}
