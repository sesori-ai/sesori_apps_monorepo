/// A Pi RPC command used by the Sesori integration.
enum PiRpcCommand(final String wireValue) {
  prompt("prompt"),
  abort("abort"),
  compact("compact"),
  getState("get_state"),
  setModel("set_model"),
  getAvailableModels("get_available_models"),
  setThinkingLevel("set_thinking_level"),
  getAvailableThinkingLevels("get_available_thinking_levels"),
  getCommands("get_commands"),
  getEntries("get_entries"),
  getTree("get_tree"),
  setSessionName("set_session_name");

  static PiRpcCommand? tryParse({required String? value}) {
    for (final command in values) {
      if (command.wireValue == value) return command;
    }
    return null;
  }
}
