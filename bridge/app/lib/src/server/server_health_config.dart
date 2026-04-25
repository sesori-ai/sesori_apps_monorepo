class ServerHealthConfig {
  final String serverURL;
  final String password;
  final String binaryPath;
  final bool isManaged;

  const ServerHealthConfig({
    required this.serverURL,
    required this.password,
    required this.binaryPath,
    required this.isManaged,
  });
}
