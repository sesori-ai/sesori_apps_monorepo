import "sesori_tool_argument_parser.dart" show InvalidToolArguments;
import "sesori_tool_caller.dart";
import "sesori_tool_definition.dart";
import "sesori_tool_result.dart";

/// A set of tools with one purpose, served on Sesori's MCP server.
///
/// The bridge lists [tools] and routes each call of one of them to [call].
/// Dependencies arrive through the group's constructor.
abstract interface class SesoriToolGroup() {
  /// What the group is for and when to reach for it, in a sentence or two.
  /// The server's MCP `instructions` join every group's.
  String get instructions;

  List<SesoriToolDefinition> get tools;

  /// Runs [tool], one of [tools] by name.
  ///
  /// Throws [InvalidToolArguments] for arguments that do not fit the tool's
  /// schema; the bridge answers the agent with its reason. Any other throw is
  /// logged and answered as a failure on the bridge.
  Future<SesoriToolResult> call({
    required String tool,
    required SesoriToolCaller caller,
    required Map<String, Object?> arguments,
  });
}
