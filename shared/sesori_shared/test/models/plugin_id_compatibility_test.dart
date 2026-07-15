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
        pullRequest: null,
        promptDefaults: null,
      );

      expect(Session.fromJson(session.toJson()).pluginId, "opencode");
    });

    test("attributes missing plugin id and ignores legacy summary", () {
      final session = Session.fromJson({
        "id": "session-1",
        "projectID": "project-1",
        "directory": "/tmp/project-1",
        "parentID": null,
        "title": null,
        "time": null,
        "summary": {"additions": 4, "deletions": 1, "files": 2},
        "pullRequest": null,
      });

      expect(legacyMissingPluginId, "opencode");
      expect(session.pluginId, "opencode");
      expect(session.toJson(), isNot(contains("summary")));
      expect(Session.fromJson({...session.toJson(), "pluginId": null}).pluginId, "opencode");
    });
  });

  group("CreateSessionRequest.pluginId", () {
    CreateSessionRequest request({required String pluginId}) => CreateSessionRequest(
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

    test("attributes missing and null keys to OpenCode", () {
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

      expect(value.pluginId, "opencode");
      expect(CreateSessionRequest.fromJson({...value.toJson(), "pluginId": null}).pluginId, "opencode");
    });
  });

  group("ProjectIdRequest", () {
    test("contains only project identity", () {
      const request = ProjectIdRequest(projectId: "project-1");

      expect(ProjectIdRequest.fromJson(request.toJson()), request);
      expect(request.toJson(), {"projectId": "project-1"});
    });
  });

  group("PluginProjectIdRequest.pluginId", () {
    test("round-trips a non-legacy value", () {
      const request = PluginProjectIdRequest(projectId: "project-1", pluginId: "opencode");

      expect(PluginProjectIdRequest.fromJson(request.toJson()), request);
    });

    test("attributes missing and null keys to OpenCode", () {
      final request = PluginProjectIdRequest.fromJson({"projectId": "project-1"});

      expect(request.pluginId, "opencode");
      expect(
        PluginProjectIdRequest.fromJson({"projectId": "project-1", "pluginId": null}).pluginId,
        "opencode",
      );
    });

    test("serializes the legacy OpenCode default explicitly", () {
      const request = PluginProjectIdRequest(projectId: "project-1");

      expect(request.toJson(), {"projectId": "project-1", "pluginId": "opencode"});
    });
  });
}
