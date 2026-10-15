enum PluginMcpConnectorSetupUnavailableReason() {
  unsupportedScope,
  liveSessionRequired,
  targetNotFound,
  nativeConfigurationRequired,
  notSupported,
}

sealed class const PluginMcpConnectorSetupResult();

/// A browser destination, not a pending native request or completion signal.
final class const PluginMcpConnectorExternalSetup({required final Uri destination})
    extends PluginMcpConnectorSetupResult;

final class const PluginMcpConnectorSetupUnavailable({required final PluginMcpConnectorSetupUnavailableReason reason})
    extends PluginMcpConnectorSetupResult;

final class const PluginMcpConnectorSetupFailed({
  required final Exception cause,
  required final StackTrace causeStackTrace,
}) extends PluginMcpConnectorSetupResult;
