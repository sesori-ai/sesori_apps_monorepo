import "acp_process_factory.dart";
import "acp_stdio_client.dart";

class AcpStdioClientBuilder {
  const AcpStdioClientBuilder({
    required this.launchSpec,
    required this.processFactory,
  });

  final AcpLaunchSpec launchSpec;
  final AcpProcessFactory? processFactory;

  AcpStdioClient build({required String logTag}) => AcpStdioClient(
    launchSpec: launchSpec,
    processFactory: processFactory,
    logTag: logTag,
  );
}
