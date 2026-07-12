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

    test("normalizes missing and null keys to the legacy sentinel", () {
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

      expect(session.pluginId, legacyMissingPluginId);
      expect(Session.fromJson({...session.toJson(), "pluginId": null}).pluginId, legacyMissingPluginId);
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

    test("normalizes missing and null keys to the legacy sentinel", () {
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

      expect(value.pluginId, legacyMissingPluginId);
      expect(CreateSessionRequest.fromJson({...value.toJson(), "pluginId": null}).pluginId, legacyMissingPluginId);
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

    test("normalizes missing and null keys to the legacy sentinel", () {
      final request = PluginProjectIdRequest.fromJson({"projectId": "project-1"});

      expect(request.pluginId, legacyMissingPluginId);
      expect(
        PluginProjectIdRequest.fromJson({"projectId": "project-1", "pluginId": null}).pluginId,
        legacyMissingPluginId,
      );
    });

    test("serializes the sentinel explicitly", () {
      const request = PluginProjectIdRequest(projectId: "project-1");

      expect(request.toJson(), {"projectId": "project-1", "pluginId": legacyMissingPluginId});
    });
  });
}
