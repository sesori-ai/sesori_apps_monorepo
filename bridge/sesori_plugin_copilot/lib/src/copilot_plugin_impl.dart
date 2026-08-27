import "package:acp_plugin/acp_plugin.dart";

import "copilot_binary.dart";
import "copilot_identity.dart";

/// GitHub Copilot CLI backend over standard ACP v1.
///
/// Copilot uses the shared ACP transport, session persistence/replay, command,
/// config-option, and permission surfaces without a private protocol dialect.
/// It supports standard cancellation but does not currently forward its
/// `ask_user` interaction over ACP, so form elicitation remains unadvertised.
class CopilotPlugin._({
  required super.launchSpec,
  required super.launchDirectory,
  required super.eventMapper,
  required super.commandTracker,
  required super.sessionOptionsService,
  required super.processFactory,
}) extends AcpPlugin {
  factory({
    required String binaryPath,
    required String launchDirectory,
    required Map<String, String> environment,
    required AcpProcessFactory processFactory,
  }) {
    final configurationTracker = AcpSessionConfigurationTracker();
    final commandTracker = AcpCommandTracker();
    return CopilotPlugin._(
      launchSpec: CopilotBinary.launchSpec(
        binary: binaryPath,
        cwd: launchDirectory,
        environment: environment,
      ),
      launchDirectory: launchDirectory,
      eventMapper: AcpEventMapper(
        launchDirectory: launchDirectory,
        pluginId: CopilotPluginIdentity.id,
        configurationTracker: configurationTracker,
      ),
      commandTracker: commandTracker,
      sessionOptionsService: AcpSessionOptionsService(
        configurationTracker: configurationTracker,
        commandTracker: commandTracker,
        pluginId: CopilotPluginIdentity.id,
        agentDisplayName: CopilotPluginIdentity.displayName,
      ),
      processFactory: processFactory,
    );
  }

  this
    : super(
        id: CopilotPluginIdentity.id,
        agentDisplayName: CopilotPluginIdentity.displayName,
      );

  @override
  String? get authMethodId => CopilotBinary.acpAuthMethodId;

  @override
  bool get cancelsActiveTurnForQueuedInput => true;
}
