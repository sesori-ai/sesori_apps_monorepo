import "dart:convert";
import "dart:io";

import "../../bridge/foundation/process_runner.dart";
import "process_id_lookup_api.dart";

class PgrepApi implements ProcessIdLookupApi {
  PgrepApi({required ProcessRunner processRunner}) : _processRunner = processRunner;

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
