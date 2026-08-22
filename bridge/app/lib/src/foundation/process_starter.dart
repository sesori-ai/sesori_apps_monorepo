import 'dart:io';

typedef ProcessStarter =
    Future<Process> Function(
      String executable,
      List<String> arguments,
    );
