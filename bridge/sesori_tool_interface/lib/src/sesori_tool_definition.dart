/// One tool as agents see it in `tools/list`.
final class const SesoriToolDefinition({
  /// Unique across every group on the server.
  required final String name,
  required final String description,

  /// Advertised as MCP's `readOnlyHint`.
  required final bool readOnly,

  /// The JSON Schema of the tool's arguments, as MCP's `inputSchema`.
  required final Map<String, Object?> inputSchema,
});
