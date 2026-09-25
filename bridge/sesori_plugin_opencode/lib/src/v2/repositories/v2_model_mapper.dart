import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:sesori_shared/sesori_shared.dart" as shared;

import "../models/openapi/agent_info.g.dart";
import "../models/openapi/command_info.g.dart";
import "../models/openapi/form_boolean_field.g.dart";
import "../models/openapi/form_field.g.dart";
import "../models/openapi/form_info.g.dart";
import "../models/openapi/form_integer_field.g.dart";
import "../models/openapi/form_multiselect_field.g.dart";
import "../models/openapi/form_number_field.g.dart";
import "../models/openapi/form_option.g.dart";
import "../models/openapi/form_string_field.g.dart";
import "../models/openapi/model_info.g.dart";
import "../models/openapi/permission_request.g.dart";
import "../models/openapi/project.g.dart";
import "../models/openapi/provider_info.g.dart";
import "../models/openapi/session_info.g.dart";

/// Pure v2 catalog and interaction projection. Native project hashes and
/// display-only agent labels never become the bridge's selectable identities.
class const V2ModelMapper({required final String _pluginId}) {
  PluginProject mapProject({required Project project, required PluginProjectActivity? activity}) => PluginProject(
    id: project.canonical,
    directory: project.canonical,
    name: project.name ?? _basename(path: project.canonical),
    activity: activity,
  );

  PluginSession mapSession({required SessionInfo session, required String projectId}) => PluginSession(
    id: session.id,
    projectID: projectId,
    directory: session.location.directory,
    parentID: session.parentID,
    title: session.title,
    time: PluginSessionTime(
      created: session.time.created.toInt(),
      updated: session.time.updated.toInt(),
      archived: session.time.archived?.toInt(),
    ),
  );

  shared.Session mapSessionDetails({required SessionInfo session, required String projectId}) => shared.Session(
    id: session.id,
    pluginId: _pluginId,
    projectID: projectId,
    directory: session.location.directory,
    parentID: session.parentID,
    title: session.title,
    time: shared.SessionTime(
      created: session.time.created.toInt(),
      updated: session.time.updated.toInt(),
      archived: session.time.archived?.toInt(),
    ),
    promptDefaults: shared.SessionPromptDefaults(
      agent: session.agent,
      model: switch (session.model) {
        final model? => shared.AgentModel(providerID: model.providerID, modelID: model.id, variant: model.variant),
        null => null,
      },
    ),
    pullRequest: null,
    branchName: null,
    lastUserActivityAt: null,
    autoContinuation: null,
    approvalOverride: null,
  );

  PluginAgent mapAgent({required AgentInfo agent}) => PluginAgent(
    // PluginAgent.name is the selectable key. In v2, id=build has name=Build;
    // sending the display label back would address a different native agent.
    name: agent.id,
    description: agent.description,
    model: switch (agent.model) {
      final model? => PluginAgentModel(providerID: model.providerID, modelID: model.id, variant: model.variant),
      null => null,
    },
    mode: switch (agent.mode) {
      AgentInfoMode.primary => PluginAgentMode.primary,
      AgentInfoMode.subagent => PluginAgentMode.subagent,
      AgentInfoMode.all => PluginAgentMode.all,
      AgentInfoMode.unknown => PluginAgentMode.unknown,
    },
    hidden: agent.hidden,
  );

  PluginProvidersResult mapProviders({
    required List<ProviderInfo> providers,
    required List<ModelInfo> models,
    required ModelInfo? defaultModel,
  }) => PluginProvidersResult(
    providers: [
      for (final provider in providers)
        if (provider.activation != ProviderInfoActivation.disabled)
          PluginProvider(
            id: provider.id,
            name: provider.name,
            authType: PluginProviderAuthType.unknown,
            models: _providerModels(models: models.where((model) => model.providerID == provider.id)),
            defaultModelID: defaultModel?.providerID == provider.id ? defaultModel?.id : null,
          ),
    ],
  );

  List<PluginModel> _providerModels({required Iterable<ModelInfo> models}) {
    final mapped =
        models.map((model) {
          final variants = model.variants.map((variant) => variant.id).toList();
          return PluginModel(
            id: model.id,
            name: model.name,
            family: model.family,
            variants: CatalogStrengthOrder.variants(variants),
            defaultVariant: CatalogStrengthOrder.backendDefault(variants),
            isAvailable: model.enabled && model.status != ModelInfoStatus.deprecated,
            releaseDate: model.time.released > 0
                ? DateTime.fromMillisecondsSinceEpoch(model.time.released.toInt(), isUtc: true)
                : null,
            fastMode: null,
          );
        }).toList()..sort((a, b) {
          final left = a.releaseDate;
          final right = b.releaseDate;
          if (left == null && right != null) return 1;
          if (right == null && left != null) return -1;
          final byDate = left == null || right == null ? 0 : right.compareTo(left);
          return byDate == 0 ? a.name.compareTo(b.name) : byDate;
        });
    return CatalogStrengthOrder.models(mapped, idOf: (model) => model.id);
  }

  PluginCommand mapCommand({required CommandInfo command}) => PluginCommand(
    name: command.name,
    description: command.description,
    provider: null,
    source: PluginCommandSource.unknown,
  );

  PluginPendingPermission mapPermission({required PermissionRequest permission, required String? displaySessionId}) =>
      PluginPendingPermission(
        id: permission.id,
        sessionID: permission.sessionID,
        displaySessionId: displaySessionId,
        tool: permission.action,
        description:
            permission.message ?? (permission.resources.isEmpty ? permission.action : permission.resources.join(", ")),
        allowAlways: true,
      );

  /// Shared field ordering for display and the future answer mapper. Conditions
  /// remain a native-only capability; hidden/external fields are not rendered.
  static List<FormField> visibleFormFields({required FormInfo form}) => form.fields.items
      .where(
        (field) => switch (field) {
          FormStringField(:final hidden) ||
          FormMultiselectField(:final hidden) ||
          FormBooleanField(:final hidden) ||
          FormNumberField(:final hidden) ||
          FormIntegerField(:final hidden) => hidden != true,
          _ => false,
        },
      )
      .toList();

  PluginPendingQuestion? mapForm({required FormInfo form, required String? displaySessionId}) {
    final fields = visibleFormFields(form: form);
    if (fields.isEmpty) {
      Log.w("OpenCode v2 form ${form.id} has no supported visible fields; answer it in the native OpenCode interface");
      return null;
    }
    return PluginPendingQuestion(
      id: form.id,
      sessionID: form.sessionID,
      displaySessionId: displaySessionId,
      questions: [for (final field in fields) _mapField(field: field)],
    );
  }

  PluginQuestionInfo _mapField({required FormField field}) => switch (field) {
    FormStringField() => _question(
      key: field.key,
      title: field.title,
      description: field.description,
      options: _options(options: field.options ?? const []),
      multiple: false,
      custom: field.options == null || (field.custom ?? false),
    ),
    FormMultiselectField() => _question(
      key: field.key,
      title: field.title,
      description: field.description,
      options: _options(options: field.options),
      multiple: true,
      custom: field.custom ?? false,
    ),
    FormBooleanField() => _question(
      key: field.key,
      title: field.title,
      description: field.description,
      options: const [
        PluginQuestionOption(label: "true", description: "Yes"),
        PluginQuestionOption(label: "false", description: "No"),
      ],
      multiple: false,
      custom: false,
    ),
    FormNumberField(:final key, :final title, :final description) ||
    FormIntegerField(
      :final key,
      :final title,
      :final description,
    ) => _question(key: key, title: title, description: description, options: const [], multiple: false, custom: true),
    _ => throw StateError("Only supported visible fields reach question projection"),
  };

  List<PluginQuestionOption> _options({required List<FormOption> options}) => [
    for (final option in options)
      PluginQuestionOption(label: option.label, description: option.description ?? option.label),
  ];

  PluginQuestionInfo _question({
    required String key,
    required String? title,
    required String? description,
    required List<PluginQuestionOption> options,
    required bool multiple,
    required bool custom,
  }) => PluginQuestionInfo(
    header: title ?? key,
    question: description ?? title ?? key,
    options: options,
    multiple: multiple,
    custom: custom,
  );

  String? _basename({required String path}) {
    final segments = path.replaceAll(r"\", "/").split("/").where((segment) => segment.isNotEmpty);
    return segments.isEmpty ? null : segments.last;
  }
}
