import "dart:io";

typedef ProcessRunner =
    Future<ProcessResult> Function(
      String executable,
      List<String> arguments, {
      String? workingDirectory,
    });
