/// A malformed native MCP response, retaining its original decoding failure.
class const OpenCodeMcpDecodeException({required final String operation, required final Object innerError})
    implements Exception {
  @override
  String toString() => "OpenCode $operation payload could not be decoded (${innerError.runtimeType}).";
}
