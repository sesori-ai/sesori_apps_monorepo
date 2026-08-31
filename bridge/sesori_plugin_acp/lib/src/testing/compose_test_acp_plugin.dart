import "../acp_command_tracker.dart";
import "../acp_event_mapper.dart";
import "../acp_process_factory.dart";
import "../acp_session_configuration_tracker.dart";
import "../acp_session_options_service.dart";
import "test_acp_plugin.dart";

TestAcpPlugin composeTestAcpPlugin({
  required AcpProcessFactory processFactory,
  String id = "acp",
  String agentDisplayName = "ACP",
  AcpLaunchSpec launchSpec = const AcpLaunchSpec(command: "agent", args: ["acp"]),
  String launchDirectory = "/repo",
  bool permitsDeviceCanvasHttpMcp = false,
}) {
  final configurationTracker = AcpSessionConfigurationTracker();
  final commandTracker = AcpCommandTracker();
  return TestAcpPlugin(
    id: id,
    agentDisplayName: agentDisplayName,
    launchSpec: launchSpec,
    launchDirectory: launchDirectory,
    permitsDeviceCanvasHttpMcp: permitsDeviceCanvasHttpMcp,
    eventMapper: AcpEventMapper(
      launchDirectory: launchDirectory,
      pluginId: id,
      configurationTracker: configurationTracker,
    ),
    commandTracker: commandTracker,
    sessionOptionsService: AcpSessionOptionsService(
      configurationTracker: configurationTracker,
      commandTracker: commandTracker,
      pluginId: id,
      agentDisplayName: agentDisplayName,
    ),
    processFactory: processFactory,
  );
}
