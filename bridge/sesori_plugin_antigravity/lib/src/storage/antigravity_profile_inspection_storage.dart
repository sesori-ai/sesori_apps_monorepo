import "dart:io";

import "package:path/path.dart" as p;

/// Read-only token-presence boundary for setup inspection. The token contents
/// are never opened or decoded.
class const AntigravityProfileInspectionStorage() {
  bool tokenExists({required String geminiHome}) =>
      File(p.join(geminiHome, "antigravity-acp", "acp_token.json")).existsSync();
}
