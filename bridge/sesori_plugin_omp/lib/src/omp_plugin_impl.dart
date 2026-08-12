import "dart:io" show Directory;

import "package:acp_plugin/acp_plugin.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart";

import "omp_binary.dart";
import "omp_identity.dart";

class OmpPlugin extends AcpPlugin {
  factory OmpPlugin({
    String binaryPath = OmpBinary.defaultBinary,
    String? launchDirectory,
    AcpProcessFactory? processFactory,
  }) {
    final cwd = launchDirectory ?? Directory.current.path;
    final configurationTracker = AcpSessionConfigurationTracker();
    final commandTracker = AcpCommandTracker();
    const contentMapper = AcpContentMapper();
    return OmpPlugin._(
      launchSpec: OmpBinary.launchSpec(binary: binaryPath, cwd: cwd),
      launchDirectory: cwd,
      contentMapper: contentMapper,
      eventMapper: AcpEventMapper(
        launchDirectory: cwd,
        agentId: OmpPluginIdentity.id,
        pluginId: OmpPluginIdentity.id,
        configurationTracker: configurationTracker,
        contentMapper: contentMapper,
      ),
      commandTracker: commandTracker,
      sessionOptionsService: AcpSessionOptionsService(
        configurationTracker: configurationTracker,
        commandTracker: commandTracker,
        pluginId: OmpPluginIdentity.id,
        agentDisplayName: OmpPluginIdentity.displayName,
      ),
      processFactory: processFactory,
    );
  }

  OmpPlugin._({
    required super.launchSpec,
    required super.launchDirectory,
    required super.contentMapper,
    required super.eventMapper,
    required super.commandTracker,
    required super.sessionOptionsService,
    super.processFactory,
  }) : super(
         id: OmpPluginIdentity.id,
         agentDisplayName: OmpPluginIdentity.displayName,
       );

  @override
  String? get authMethodId => "agent";

  @override
  bool get supportsFormElicitation => true;

  @override
  bool get serializesPromptsProcessWide => true;

  @override
  bool get failsTurnOnSelectionError => true;

  @override
  Iterable<BridgeSseEvent> mapPromptFailure({
    required String sessionId,
    required Object error,
  }) {
    if (!_isMissingModel(error)) return const [];
    return const [
      BridgeSseTuiToastShow(
        title: "Oh My Pi needs a model",
        message: "Open OMP locally, run /login, then retry this turn.",
        variant: "warning",
      ),
    ];
  }

  static bool _isMissingModel(Object error) {
    if (error is! AcpRpcException || error.code != -32603) return false;
    final data = error.data;
    if (data is! Map) return false;
    final details = data["details"];
    return details is String && details.startsWith("No model selected.");
  }
}
