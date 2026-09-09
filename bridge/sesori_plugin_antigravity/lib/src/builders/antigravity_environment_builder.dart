/// Builds the false-inheritance environment used by Antigravity processes.
///
/// Ambient Google, Gemini, Antigravity, browser and Python configuration is
/// removed before an isolated [geminiHome] and explicit process-specific values
/// are added. This keeps validation and live/authentication preparation on the
/// same credential-isolation policy.
class const AntigravityEnvironmentBuilder() {
  static const _removedPrefixes = ["GOOGLE_", "GEMINI_", "GCLOUD_", "CLOUDSDK_", "AGY_", "ANTIGRAVITY_", "PYTHON"];
  static const _removedKeys = {"BROWSER", "ELECTRON_RUN_AS_NODE", "GCP_PROJECT", "GCP_LOCATION"};

  Map<String, String> build({
    required Map<String, String> hostEnvironment,
    required String geminiHome,
    required Map<String, String> additions,
  }) => Map<String, String>.unmodifiable({
    for (final entry in hostEnvironment.entries)
      if (!_removedKeys.contains(entry.key.toUpperCase()) && !_removedPrefixes.any(entry.key.toUpperCase().startsWith))
        entry.key: entry.value,
    ...additions,
    "GEMINI_HOME": geminiHome,
    "AGY_ACP_FORCE_FILE_STORAGE": "1",
  });
}
