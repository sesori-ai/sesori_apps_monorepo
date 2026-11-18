import "dart:convert";
import "dart:io";

import "package:path/path.dart" as p;
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show SesoriMcpLaunch;

import "models/claude_sesori_mcp_config_file.dart";

/// Writes and removes the `--mcp-config` files that give Claude launches
/// Sesori's server.
///
/// The token goes in a file rather than the child's environment because
/// Claude's Bash tool inherits that environment, so `env` would show it to the
/// agent and its transcript. Verified live on 2026-11-17 with Claude Code
/// 2.1.325: Claude reads the file before it answers the stdin `initialize`
/// handshake and keeps the header in memory, so a tool call and an
/// `mcp_reconnect` after the file was deleted still sent it, and `env` in the
/// session showed no token.
final class ClaudeSesoriMcpConfigApi({
  /// Sesori's state directory for this plugin.
  required final String _directory,
}) {
  /// Writes [launch] into a new folder only the user can open (`mkdtemp`
  /// creates it with mode 0700 on macOS and Linux).
  Future<ClaudeSesoriMcpConfigFile> write({required SesoriMcpLaunch launch}) async {
    await Directory(_directory).create(recursive: true);
    final folder = await Directory(_directory).createTemp("sesori-mcp-");
    final file = File(p.join(folder.path, "mcp.json"));
    await file.writeAsString(
      jsonEncode({
        "mcpServers": {
          launch.serverName: {
            "type": "http",
            "url": launch.url,
            "headers": {"Authorization": "Bearer ${launch.token}"},
          },
        },
      }),
      flush: true,
    );
    return ClaudeSesoriMcpConfigFile(serverName: launch.serverName, path: file.path);
  }

  /// Removes [config] and its folder.
  Future<void> delete({required ClaudeSesoriMcpConfigFile config}) =>
      File(config.path).parent.delete(recursive: true);
}
