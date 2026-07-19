import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  group("SessionPromptDefaults", () {
    test("round-trips JSON", () {
      const defaults = SessionPromptDefaults(
        agent: "agent-1",
        model: AgentModel(
          providerID: "provider-1",
          modelID: "model-1",
          variant: "variant-1",
        ),
      );

      final json = defaults.toJson();
      final parsed = SessionPromptDefaults.fromJson(json);

      expect(parsed, defaults);
      expect(json["agent"], "agent-1");
      expect((json["model"] as Map<String, dynamic>)["providerID"], "provider-1");
      expect((json["model"] as Map<String, dynamic>)["modelID"], "model-1");
      expect((json["model"] as Map<String, dynamic>)["variant"], "variant-1");
    });
  });

  group("Session.promptDefaults", () {
    test("defaults to null when missing from JSON", () {
      final session = Session.fromJson({
        "id": "ses_1",
        "projectID": "proj_1",
        "directory": "/tmp",
        "parentID": null,
        "title": null,
        "time": null,
        "summary": null,
        "pullRequest": null,
      });

      expect(session.promptDefaults, isNull);
    });

    test("round-trips non-null JSON", () {
      const session = Session(
        branchName: null,
        id: "ses_1",
        pluginId: legacyMissingPluginId,
        projectID: "proj_1",
        directory: "/tmp",
        parentID: null,
        title: null,
        time: null,
        pullRequest: null,
        promptDefaults: SessionPromptDefaults(
          agent: "agent-1",
          model: AgentModel(
            providerID: "provider-1",
            modelID: "model-1",
            variant: "variant-1",
          ),
        ),
      );

      final json = session.toJson();
      final parsed = Session.fromJson(json);

      expect(parsed.promptDefaults, session.promptDefaults);
      expect((json["promptDefaults"] as Map<String, dynamic>)["agent"], "agent-1");
      expect(((json["promptDefaults"] as Map<String, dynamic>)["model"] as Map<String, dynamic>)["providerID"], "provider-1");
      expect(((json["promptDefaults"] as Map<String, dynamic>)["model"] as Map<String, dynamic>)["modelID"], "model-1");
      expect(((json["promptDefaults"] as Map<String, dynamic>)["model"] as Map<String, dynamic>)["variant"], "variant-1");
    });
  });
}
