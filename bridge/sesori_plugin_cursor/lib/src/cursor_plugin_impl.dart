import "dart:io" show Directory;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "cursor_approval_registry.dart";
import "cursor_binary.dart";
import "cursor_event_mapper.dart";
import "cursor_model_probe.dart";

/// Cursor backend: drives `cursor-agent acp` over the generic ACP machinery,
/// layering on Cursor's `cursor/*` extensions and its `configOptions` model
/// picker.
class CursorPlugin extends AcpPlugin {
  factory CursorPlugin({
    String binaryPath = CursorBinary.defaultBinary,
    String? projectCwd,
    String? apiEndpoint,
    AcpProcessFactory? processFactory,
  }) {
    final cwd = projectCwd ?? Directory.current.path;
    return CursorPlugin._(
      launchSpec: CursorBinary.launchSpec(
        binary: binaryPath,
        cwd: cwd,
        apiEndpoint: apiEndpoint,
      ),
      projectCwd: cwd,
      mapper: CursorEventMapper(projectCwd: cwd),
      processFactory: processFactory,
    );
  }

  CursorPlugin._({
    required super.launchSpec,
    required super.projectCwd,
    required CursorEventMapper mapper,
    super.processFactory,
  }) : super(id: "cursor", agentDisplayName: "Cursor", eventMapper: mapper);

  /// Cached `{value, name}` model entries from the most recent `session/new`.
  List<Map<String, dynamic>> _models = const [];
  String? _modelConfigId;

  @override
  String? get authMethodId => "cursor_login";

  @override
  Map<String, dynamic>? get initializeCapabilityMeta =>
      const {"parameterizedModelPicker": true};

  @override
  AcpApprovalRegistry buildApprovalRegistry(AcpStdioClient client) {
    return CursorApprovalRegistry(client: client, emit: emitEvent);
  }

  @override
  Future<void> applyModelSelection(
    AcpStdioClient client,
    AcpNewSessionResult session,
    ({String providerID, String modelID})? model,
  ) async {
    final config = CursorModelProbe.findModelConfig(session);
    if (config == null) return;

    _modelConfigId = config["id"] as String?;
    _models = CursorModelProbe.models(config);
    eventMapper.currentProviderId = "cursor";
    eventMapper.currentModelId = CursorModelProbe.currentValue(config);

    if (model == null || _modelConfigId == null) return;
    if (!CursorModelProbe.hasModel(_models, model.modelID)) return;
    try {
      await client.request(
        method: AcpMethods.sessionSetConfigOption,
        params: {
          "sessionId": session.sessionId,
          "configId": _modelConfigId,
          "value": model.modelID,
        },
      );
      eventMapper.currentModelId = model.modelID;
    } catch (_) {
      // Fail-soft: keep the agent's default model if selection is rejected.
    }
  }

  @override
  Future<List<PluginAgent>> getAgents() async {
    final modelId = eventMapper.currentModelId;
    return [
      PluginAgent(
        name: "cursor",
        description: "Cursor CLI session",
        model: modelId == null
            ? null
            : PluginAgentModel(
                modelID: modelId,
                providerID: "cursor",
                variant: null,
              ),
        mode: PluginAgentMode.primary,
        hidden: false,
      ),
    ];
  }

  @override
  Future<PluginProvidersResult> getProviders({required String projectId}) async {
    if (_models.isEmpty) return super.getProviders(projectId: projectId);
    return PluginProvidersResult(
      providers: [
        PluginProvider.custom(
          id: "cursor",
          name: "Cursor",
          authType: PluginProviderAuthType.unknown,
          models: [
            for (final model in _models)
              PluginModel(
                id: (model["value"] ?? "") as String,
                name: (model["name"] ?? model["value"] ?? "") as String,
                variants: const [],
                family: null,
                isAvailable: true,
                releaseDate: null,
              ),
          ],
          defaultModelID:
              eventMapper.currentModelId ?? (_models.first["value"] as String?),
        ),
      ],
    );
  }
}
