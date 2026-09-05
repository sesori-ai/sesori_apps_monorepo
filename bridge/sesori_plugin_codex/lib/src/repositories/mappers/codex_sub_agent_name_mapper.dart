/// Display names for Codex's machine-oriented task paths. Raw paths stay on
/// the records so presentation never changes child identity or matching.
class const CodexSubAgentNameMapper() {
  String? map({required String? name, required String? nickname, required String? agentPath}) {
    final preferred = _usefulText(value: nickname) ?? _usefulText(value: name);
    if (preferred != null && !preferred.startsWith("/root/")) return preferred;
    final path = preferred ?? _usefulText(value: agentPath);
    if (path == null) return null;
    final leaf = path.split("/").last;
    final suffix = RegExp(r"^(.+)_([0-9]+)$").firstMatch(leaf);
    final words = (suffix?.group(1) ?? leaf).replaceAll("_", " ");
    if (words.isEmpty) return path;
    final label = "${words[0].toUpperCase()}${words.substring(1)}";
    return suffix == null ? label : "$label · ${suffix.group(2)}";
  }
}

String? _usefulText({required String? value}) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}
