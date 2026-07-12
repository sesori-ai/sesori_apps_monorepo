import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("Session.pluginId", () {
    test("round-trips a non-null value", () {
      const session = Session(
        id: "session-1",
        pluginId: "opencode",
        projectID: "project-1",
        directory: "/tmp/project-1",
        parentID: null,
        title: null,
        time: null,
        summary: null,
        pullRequest: null,
        promptDefaults: null,
      );

      expect(Session.fromJson(session.toJson()).pluginId, "opencode");
    });

    test("decodes a missing key as null", () {
      final session = Session.fromJson({
        "id": "session-1",
        "projectID": "project-1",
        "directory": "/tmp/project-1",
        "parentID": null,
        "title": null,
        "time": null,
        "summary": null,
        "pullRequest": null,
      });

      expect(session.pluginId, isNull);
    });

    test("omits a null value", () {
      const session = Session(
        id: "session-1",
        pluginId: null,
        projectID: "project-1",
        directory: "/tmp/project-1",
        parentID: null,
        title: null,
        time: null,
        summary: null,
        pullRequest: null,
        promptDefaults: null,
      );

      expect(session.toJson(), isNot(contains("pluginId")));
    });
  });

  group("CreateSessionRequest.pluginId", () {
    CreateSessionRequest request({required String? pluginId}) => CreateSessionRequest(
      projectId: "project-1",
      pluginId: pluginId,
      parts: const [PromptPart.text(text: "hello")],
      agent: null,
      model: null,
      command: null,
      variant: null,
      dedicatedWorktree: false,
    );

    test("round-trips a non-null value", () {
      final value = request(pluginId: "opencode");

      expect(CreateSessionRequest.fromJson(value.toJson()).pluginId, "opencode");
    });

    test("decodes a missing key as null", () {
      final value = CreateSessionRequest.fromJson({
        "projectId": "project-1",
        "parts": const [
          {"type": "text", "text": "hello"},
        ],
        "agent": null,
        "model": null,
        "command": null,
        "variant": null,
        "dedicatedWorktree": false,
      });

      expect(value.pluginId, isNull);
    });

    test("omits a null value", () {
      expect(request(pluginId: null).toJson(), isNot(contains("pluginId")));
    });
  });

  group("ProjectIdRequest.pluginId", () {
    test("round-trips a non-null value", () {
      const request = ProjectIdRequest(projectId: "project-1", pluginId: "opencode");

      expect(ProjectIdRequest.fromJson(request.toJson()).pluginId, "opencode");
    });

    test("decodes a missing key as null", () {
      final request = ProjectIdRequest.fromJson({"projectId": "project-1"});

      expect(request.pluginId, isNull);
    });

    test("omits a null value", () {
      const request = ProjectIdRequest(projectId: "project-1", pluginId: null);

      expect(request.toJson(), isNot(contains("pluginId")));
    });
  });
}
