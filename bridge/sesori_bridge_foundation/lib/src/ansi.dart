final RegExp _ansiEscapePattern = RegExp(r"\x1B(?:\[[0-?]*[ -/]*[@-~]|\][^\x07\x1B]*(?:\x07|\x1B\\))");

/// Removes CSI and OSC terminal escape sequences from [value].
String stripAnsi({required String value}) => value.replaceAll(_ansiEscapePattern, "");
