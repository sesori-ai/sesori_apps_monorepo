class const CodexThreadRecord({
  required final String id,
  required final String? name,
  required final String? directory,
  required final int? createdAt,
  required final int? updatedAt,
  required final String? model,
  required final String? modelProvider,

  /// The direct parent thread for a sub-agent thread; `null` for a root.
  required final String? parentId,

  /// Codex's generated nickname for a sub-agent thread; `null` for a root.
  required final String? agentNickname,
});
