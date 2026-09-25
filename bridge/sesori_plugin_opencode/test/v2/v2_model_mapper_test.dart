import "dart:io";

import "package:opencode_plugin/src/v2/models/openapi/agent_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/command_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/form_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/model_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/permission_request.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/project.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/provider_info.g.dart";
import "package:opencode_plugin/src/v2/models/openapi/session_info.g.dart";
import "package:opencode_plugin/src/v2/repositories/v2_model_mapper.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" show Session, jsonCastMap, jsonDecodeMap;
import "package:test/test.dart";

void main() {
  const mapper = V2ModelMapper(pluginId: "fixture-plugin");
  final fixture = jsonDecodeMap(File("test/v2/fixtures/native_2_0_16.json").readAsStringSync());
  Map<String, dynamic> native({required String key}) => jsonCastMap(fixture[key]);

  test("maps native project identity without fabricating session activity", () {
    final project = mapper.mapProject(project: Project.fromJson(native(key: "project")), activity: null);
    expect(project.id, "/fixture/project");
    expect(project.name, "project");
    expect(project.directory, project.id);
    expect(project.activity, isNull);
  });

  test("maps session hierarchy, timestamps and neutral detail JSON", () {
    final raw = SessionInfo.fromJson(<String, dynamic>{
      ...native(key: "session"),
      "parentID": "parent",
      "agent": "build",
    });
    final session = mapper.mapSession(session: raw, projectId: "/fixture/project");
    expect(session.parentID, "parent");
    expect(session.time!.created, raw.time.created.toInt());
    final details = mapper.mapSessionDetails(session: raw, projectId: "/fixture/project");
    expect(details.pluginId, "fixture-plugin");
    expect(details.projectID, "/fixture/project");
    expect(details.promptDefaults!.agent, "build");
    expect(details.promptDefaults!.model!.modelID, "model");
    expect(details.approvalOverride, isNull);
    expect(Session.fromJson(details.toJson()), details);
    expect(details.toJson(), isNot(contains("location")));
  });

  test("uses native agent IDs rather than display-only labels", () {
    final raw = AgentInfo.fromJson(native(key: "agent"));
    expect(raw.name, "Build");
    final agent = mapper.mapAgent(agent: raw);
    expect(agent.name, "build");
    expect(agent.mode, PluginAgentMode.primary);
    expect(agent.hidden, isFalse);
  });

  test("maps native catalog dates and preserves backend variant defaults", () {
    final model = ModelInfo.fromJson(<String, dynamic>{
      ...native(key: "model"),
      "variants": const <Object>[
        <String, dynamic>{"id": "low"},
        <String, dynamic>{"id": "high"},
      ],
    });
    final result = mapper.mapProviders(
      providers: [ProviderInfo.fromJson(native(key: "provider"))],
      models: [model],
      defaultModel: model,
    );
    final provider = result.providers.single;
    expect(provider.defaultModelID, model.id);
    expect(provider.models.single.variants, <String>["high", "low"]);
    expect(provider.models.single.defaultVariant, "low");
    expect(provider.models.single.releaseDate!.millisecondsSinceEpoch, model.time.released.toInt());
    expect(provider.models.single.isAvailable, isTrue);
    final unavailable = ModelInfo.fromJson(<String, dynamic>{...native(key: "model"), "status": "deprecated"});
    expect(
      mapper
          .mapProviders(
            providers: [ProviderInfo.fromJson(native(key: "provider"))],
            models: [unavailable],
            defaultModel: null,
          )
          .providers
          .single
          .models
          .single
          .isAvailable,
      isFalse,
    );
  });

  test("keeps permission messages and command metadata honest", () {
    final permission = mapper.mapPermission(
      permission: PermissionRequest.fromJson(const <String, dynamic>{
        "id": "permission",
        "sessionID": "child",
        "action": "bash",
        "resources": <String>["pwd"],
        "message": "Approval needed",
      }),
      displaySessionId: "root",
    );
    expect(permission.description, "Approval needed");
    expect(permission.displaySessionId, "root");
    expect(permission.tool, "bash");
    final command = mapper.mapCommand(command: CommandInfo.fromJson(const <String, dynamic>{"name": "review"}));
    expect(command.source, PluginCommandSource.unknown);
    expect(command.template, isNull);
  });

  test("projects field order, choices and typed free-text inputs", () {
    final form = FormInfo.fromJson(const <String, dynamic>{
      "id": "form",
      "sessionID": "child",
      "fields": <Object>[
        <String, dynamic>{
          "type": "string",
          "key": "env",
          "title": "Environment",
          "options": <Object>[
            <String, dynamic>{"value": "prod", "label": "Production"},
          ],
        },
        <String, dynamic>{"type": "string", "key": "hidden", "hidden": true},
        <String, dynamic>{"type": "external", "key": "web", "url": "https://fixture.invalid"},
        <String, dynamic>{"type": "boolean", "key": "confirm"},
        <String, dynamic>{"type": "integer", "key": "count"},
        <String, dynamic>{"type": "number", "key": "ratio"},
        <String, dynamic>{
          "type": "multiselect",
          "key": "regions",
          "custom": true,
          "options": <Object>[
            <String, dynamic>{"value": "eu", "label": "Europe"},
          ],
        },
      ],
    });
    final question = mapper.mapForm(form: form, displaySessionId: "root")!;
    expect(question.displaySessionId, "root");
    expect(question.questions.map((field) => field.header), <String>[
      "Environment",
      "confirm",
      "count",
      "ratio",
      "regions",
    ]);
    expect(question.questions[0].options.single.label, "Production");
    expect(question.questions[0].custom, isFalse);
    expect(question.questions[1].options.map((option) => option.label), <String>["true", "false"]);
    expect(question.questions[2].custom, isTrue);
    expect(question.questions[3].custom, isTrue);
    expect(question.questions[4].multiple, isTrue);
    expect(question.questions[4].custom, isTrue);
  });

  test("does not invent a replyable question for external-only forms", () {
    final form = FormInfo.fromJson(const <String, dynamic>{
      "id": "form",
      "sessionID": "s",
      "fields": <Object>[
        <String, dynamic>{"type": "external", "key": "web", "url": "https://fixture.invalid"},
      ],
    });
    expect(mapper.mapForm(form: form, displaySessionId: null), isNull);
  });
}
