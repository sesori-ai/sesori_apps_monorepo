/// Built-in Sesori harnesses.
///
/// Transport contracts continue to carry plugin IDs as strings so newer
/// bridges can advertise harnesses unknown to an older client. Use [name] when
/// producing or matching a built-in plugin ID and retain a fallback for values
/// not represented by this enum.
enum Harness() {
  opencode,
  codex,
  copilot,
  cursor,
  claude,
  hermes,
  pi,
  omp,
  deepseek,
  grok,
  antigravity,
}

// COMPATIBILITY 2026-07-13 (v1.5.0): Old peers omit pluginId and mean OpenCode. Remove this constant and its export
// with the pluginId defaults once public apps and bridges older than v1.5.1 are unsupported.
const String legacyMissingPluginId = "opencode";
