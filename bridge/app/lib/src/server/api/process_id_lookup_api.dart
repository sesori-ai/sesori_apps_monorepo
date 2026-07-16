import "dart:convert";
import "dart:io";

import "../../bridge/foundation/process_runner.dart";

sealed class ProcessIdLookupApi {
  ProcessIdLookupApi._();

  factory ProcessIdLookupApi.forPlatform({
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

final class _PosixProcessIdLookupApi extends ProcessIdLookupApi {
  _PosixProcessIdLookupApi({required ProcessRunner processRunner}) : _processRunner = processRunner, super._();

  final ProcessRunner _processRunner;

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

final class _WindowsProcessIdLookupApi extends ProcessIdLookupApi {
  _WindowsProcessIdLookupApi({required ProcessRunner processRunner}) : _processRunner = processRunner, super._();

  final ProcessRunner _processRunner;

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
      final values = _parseCsvLine(line: line.trim());
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

  static List<String> _parseCsvLine({required String line}) {
    final values = <String>[];
    final buffer = StringBuffer();
    var inQuotes = false;

    for (var index = 0; index < line.length; index += 1) {
      final character = line[index];
      if (character == '"') {
        if (inQuotes && index + 1 < line.length && line[index + 1] == '"') {
          buffer.write('"');
          index += 1;
        } else {
          inQuotes = !inQuotes;
        }
        continue;
      }

      if (character == "," && !inQuotes) {
        values.add(buffer.toString());
        buffer.clear();
        continue;
      }

      buffer.write(character);
    }

    values.add(buffer.toString());
    return values;
  }
}
