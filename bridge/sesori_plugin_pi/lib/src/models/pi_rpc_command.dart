/// A Pi RPC command used by the Sesori integration.
enum PiRpcCommand {
  prompt("prompt"),
  abort("abort"),
  getState("get_state"),
  setModel("set_model"),
  getAvailableModels("get_available_models"),
  setThinkingLevel("set_thinking_level"),
  getAvailableThinkingLevels("get_available_thinking_levels"),
  getCommands("get_commands"),
  getEntries("get_entries"),
  getTree("get_tree"),
  setSessionName("set_session_name");

  const PiRpcCommand(this.wireValue);

  final String wireValue;

  static PiRpcCommand? tryParse({required String? value}) {
    for (final command in values) {
      if (command.wireValue == value) return command;
    }
    return null;
  }
}
