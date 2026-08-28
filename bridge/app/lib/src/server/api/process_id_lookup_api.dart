import "dart:convert";
import "dart:io";

import "../../foundation/csv_parser.dart";
import "../../foundation/process_runner.dart";

sealed class ProcessIdLookupApi._() {
  factory forPlatform({
    required bool isWindows,
    required ProcessRunner processRunner,
  }) {
    return isWindows
        ? _WindowsProcessIdLookupApi(processRunner: processRunner)
        : _PosixProcessIdLookupApi(processRunner: processRunner);
  }

  /// Finds processes whose platform executable name exactly matches
  /// [executableName]. The name excludes platform-specific extensions.
  Future<List<int>> listProcessIdsByExecutableName({required String executableName});
}

final class _PosixProcessIdLookupApi({required final ProcessRunner _processRunner}) extends ProcessIdLookupApi {
  this : super._();

  @override
  Future<List<int>> listProcessIdsByExecutableName({required String executableName}) async {
    const command = "pgrep";
    final arguments = <String>["-x", executableName];
    final result = await _processRunner.run(
      command,
      arguments,
      environment: const <String, String>{"LC_ALL": "C"},
    );
    if (result.exitCode == 1) {
      return const <int>[];
    }
    if (result.exitCode != 0) {
      throw ProcessException(command, arguments, result.stderr.toString(), result.exitCode);
    }

    final processIds = <int>[];
    for (final line in const LineSplitter().convert(result.stdout.toString())) {
      final value = line.trim();
      if (value.isEmpty) {
        continue;
      }
      final processId = int.tryParse(value);
      if (processId == null || processId <= 0) {
        throw FormatException("Invalid process id from pgrep: $value");
      }
      processIds.add(processId);
    }
    return processIds;
  }
}

final class _WindowsProcessIdLookupApi({required final ProcessRunner _processRunner}) extends ProcessIdLookupApi {
  this : super._();

  @override
  Future<List<int>> listProcessIdsByExecutableName({required String executableName}) async {
    const command = "tasklist";
    final arguments = <String>[
      "/FO",
      "CSV",
      "/NH",
      "/FI",
      "IMAGENAME eq $executableName.exe",
    ];
    final result = await _processRunner.run(command, arguments);
    if (result.exitCode != 0) {
      throw ProcessException(command, arguments, result.stderr.toString(), result.exitCode);
    }

    final processIds = <int>[];
    for (final line in const LineSplitter().convert(result.stdout.toString())) {
      final values = CsvParser.parseLine(line: line.trim());
      if (values.length < 2) {
        continue;
      }
      final processId = int.tryParse(values[1]);
      if (processId != null && processId > 0) {
        processIds.add(processId);
      }
    }
    return processIds;
  }
}
