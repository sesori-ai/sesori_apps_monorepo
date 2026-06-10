/// Maps the raw process arguments onto CommandRunner arguments, inserting the
/// implicit default `run` command when the bridge is invoked with bare flags.
List<String> effectiveCliArgs(List<String> args) {
  if (args.isEmpty) {
    return ['run'];
  }

  final first = args.first;

  // A bare leading --help/-h shows the global command overview.
  if (first == '--help' || first == '-h') {
    return args;
  }

  // Any other leading flag belongs to the implicit 'run' command (including
  // --help after run flags, which then shows the run usage).
  if (first.startsWith('-')) {
    return ['run', ...args];
  }

  // Explicit command, or an unknown token that CommandRunner will report.
  return args;
}
