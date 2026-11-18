import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show SesoriMcpAccess;

import "../acp_command_tracker.dart";
import "../acp_event_mapper.dart";
import "../acp_process_factory.dart";
import "../acp_session_configuration_tracker.dart";
import "../repositories/trackers/acp_child_session_tracker.dart";
import "test_acp_plugin.dart";

TestAcpPlugin composeTestAcpPlugin({
  required AcpProcessFactory processFactory,
  String id = "acp",
  String agentDisplayName = "ACP",
  AcpLaunchSpec launchSpec = const AcpLaunchSpec(includeParentEnvironment: true, command: "agent", args: ["acp"]),
  String launchDirectory = "/repo",
  SesoriMcpAccess? sesoriMcp,
}) {
  final configurationTracker = AcpSessionConfigurationTracker();
  final commandTracker = AcpCommandTracker(selectionCommands: const {});
  final childSessionTracker = AcpChildSessionTracker();
  return TestAcpPlugin(
    id: id,
    agentDisplayName: agentDisplayName,
    launchSpec: launchSpec,
    launchDirectory: launchDirectory,
    childSessionTracker: childSessionTracker,
    eventMapper: AcpEventMapper(
      launchDirectory: launchDirectory,
      pluginId: id,
      configurationTracker: configurationTracker,
      childSessions: childSessionTracker,
    ),
    commandTracker: commandTracker,
    processFactory: processFactory,
    sesoriMcp: sesoriMcp,
  );
}
