import "package:sesori_bridge_foundation/sesori_bridge_foundation.dart";

/// Parsed response from the Antigravity server's inert `--version` command.
final class const AntigravityVersionDto({
  required final CommandResult command,
  required final String? buildLabel,
});
