/// Instructions the bridge gives every agent session through its harness's own
/// system-prompt or developer-instructions input.
///
/// They are never written into the user's prompt, transcript or instruction
/// files. A new Sesori instruction is another paragraph here.
const String sesoriAgentInstructions =
    "The user reads this session in the Sesori app, which resolves relative file paths in your replies "
    "against this session's working directory. Refer to a file outside that directory by its absolute path.";
