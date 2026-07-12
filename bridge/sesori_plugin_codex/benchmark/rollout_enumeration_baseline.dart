import "dart:async";
import "dart:convert";
import "dart:ffi" show Abi;
import "dart:io";

import "package:codex_plugin/codex_plugin.dart";
import "package:path/path.dart" as p;

typedef _BenchmarkOptions = ({
  int sessions,
  int projects,
  int samples,
  int warmup,
});

typedef _FixtureSummary = ({
  int bytes,
  int files,
  int indexEntries,
  int rolloutFiles,
});

const _defaultOptions = (
  sessions: 1000,
  projects: 50,
  samples: 10,
  warmup: 2,
);

Future<void> main(List<String> arguments) async {
  Directory? codexHome;
  try {
    final options = _parseOptions(arguments: arguments);
    stderr.writeln(
      "Generating deterministic CODEX_HOME fixture: "
      "${options.sessions} sessions across ${options.projects} projects.",
    );

    codexHome = Directory.systemTemp.createTempSync(
      "sesori-codex-rollout-benchmark-",
    );
    final fixture = _writeFixture(
      codexHome: codexHome,
      sessions: options.sessions,
      projects: options.projects,
    );
    final reader = SessionRolloutReader(
      environment: {"CODEX_HOME": codexHome.path},
    );

    stderr.writeln("Running ${options.warmup} warmup iteration(s).");
    for (var i = 0; i < options.warmup; i++) {
      _validateCount(
        operation: "listRolloutFiles",
        actual: reader.listRolloutFiles().length,
        expected: options.sessions,
      );
      _validateCount(
        operation: "readIndex",
        actual: reader.readIndex().length,
        expected: options.sessions,
      );
      _validateCount(
        operation: "listSessions",
        actual: reader.listSessions().length,
        expected: options.sessions,
      );
    }

    final rssBefore = ProcessInfo.currentRss;
    final listRolloutFilesMicros = <int>[];
    final readIndexMicros = <int>[];
    final listSessionsMicros = <int>[];
    final schedulingLagMicros = <int>[];
    var sessionsReturned = 0;

    stderr.writeln("Collecting ${options.samples} measured sample(s).");
    for (var i = 0; i < options.samples; i++) {
      var watch = Stopwatch()..start();
      final rolloutFiles = reader.listRolloutFiles();
      watch.stop();
      listRolloutFilesMicros.add(watch.elapsedMicroseconds);
      _validateCount(
        operation: "listRolloutFiles",
        actual: rolloutFiles.length,
        expected: options.sessions,
      );

      watch = Stopwatch()..start();
      final indexEntries = reader.readIndex();
      watch.stop();
      readIndexMicros.add(watch.elapsedMicroseconds);
      _validateCount(
        operation: "readIndex",
        actual: indexEntries.length,
        expected: options.sessions,
      );

      final lagCompleter = Completer<int>();
      final lagWatch = Stopwatch()..start();
      Timer.run(() {
        lagWatch.stop();
        lagCompleter.complete(lagWatch.elapsedMicroseconds);
      });

      watch = Stopwatch()..start();
      final sessions = reader.listSessions();
      watch.stop();
      listSessionsMicros.add(watch.elapsedMicroseconds);
      sessionsReturned = sessions.length;
      _validateCount(
        operation: "listSessions",
        actual: sessionsReturned,
        expected: options.sessions,
      );
      schedulingLagMicros.add(await lagCompleter.future);
    }
    final rssAfter = ProcessInfo.currentRss;

    final result = <String, Object?>{
      "schemaVersion": 1,
      "benchmark": "codex_rollout_enumeration_baseline",
      "generatedAt": DateTime.now().toUtc().toIso8601String(),
      "commit": _gitCommit(),
      "host": {
        "operatingSystem": Platform.operatingSystem,
        "operatingSystemVersion": Platform.operatingSystemVersion,
        "architecture": Abi.current().toString(),
        "cpuModel": _cpuModel(),
        "logicalProcessors": Platform.numberOfProcessors,
      },
      "runtime": {
        "dartVersion": Platform.version,
        "productMode": const bool.fromEnvironment("dart.vm.product"),
      },
      "parameters": {
        "sessions": options.sessions,
        "projects": options.projects,
        "samples": options.samples,
        "warmup": options.warmup,
      },
      "fixture": {
        "bytes": fixture.bytes,
        "files": fixture.files,
        "indexEntries": fixture.indexEntries,
        "rolloutFiles": fixture.rolloutFiles,
        "sessions": options.sessions,
        "projects": options.projects,
      },
      "measurements": {
        "percentileMethod": "nearest-rank",
        "durationMicros": {
          "listRolloutFiles": _statistics(values: listRolloutFilesMicros),
          "readIndex": _statistics(values: readIndexMicros),
          "listSessions": _statistics(values: listSessionsMicros),
        },
        "eventLoopSchedulingLagMicros": {
          "blockedBy": "listSessions",
          ..._statistics(values: schedulingLagMicros),
        },
        "sessionsReturned": sessionsReturned,
        "rssBytes": {
          "before": rssBefore,
          "after": rssAfter,
          "delta": rssAfter - rssBefore,
        },
      },
    };

    stdout.writeln(jsonEncode(result));
  } on Object catch (error, stackTrace) {
    stderr.writeln("Benchmark failed: $error");
    stderr.writeln(stackTrace);
    exitCode = 1;
  } finally {
    if (codexHome != null) {
      try {
        codexHome.deleteSync(recursive: true);
      } on Object catch (error) {
        stderr.writeln(
          "Failed to remove temporary fixture ${codexHome.path}: $error",
        );
      }
    }
  }
}

_BenchmarkOptions _parseOptions({required List<String> arguments}) {
  final values = <String, int>{
    "sessions": _defaultOptions.sessions,
    "projects": _defaultOptions.projects,
    "samples": _defaultOptions.samples,
    "warmup": _defaultOptions.warmup,
  };

  for (var i = 0; i < arguments.length; i++) {
    final argument = arguments[i];
    if (!argument.startsWith("--")) {
      throw FormatException("Unexpected argument: $argument");
    }

    final separator = argument.indexOf("=");
    final name = separator == -1 ? argument.substring(2) : argument.substring(2, separator);
    if (!values.containsKey(name)) {
      throw FormatException("Unknown option: --$name");
    }

    final String rawValue;
    if (separator != -1) {
      rawValue = argument.substring(separator + 1);
    } else {
      if (i + 1 >= arguments.length) {
        throw FormatException("Missing value for --$name");
      }
      i += 1;
      rawValue = arguments[i];
    }

    final parsed = int.tryParse(rawValue);
    if (parsed == null) {
      throw FormatException("--$name must be an integer, got: $rawValue");
    }
    values[name] = parsed;
  }

  final options = (
    sessions: values["sessions"]!,
    projects: values["projects"]!,
    samples: values["samples"]!,
    warmup: values["warmup"]!,
  );
  if (options.sessions <= 0) {
    throw const FormatException("--sessions must be greater than zero");
  }
  if (options.projects <= 0) {
    throw const FormatException("--projects must be greater than zero");
  }
  if (options.projects > options.sessions) {
    throw const FormatException("--projects must not exceed --sessions");
  }
  if (options.samples <= 0) {
    throw const FormatException("--samples must be greater than zero");
  }
  if (options.warmup < 0) {
    throw const FormatException("--warmup must not be negative");
  }
  return options;
}

_FixtureSummary _writeFixture({
  required Directory codexHome,
  required int sessions,
  required int projects,
}) {
  final index = StringBuffer();
  final createdDirectories = <String>{};
  var rolloutBytes = 0;

  for (var i = 0; i < sessions; i++) {
    final id = _sessionId(index: i + 1);
    final date = DateTime.utc(2025, 1, 1).add(Duration(days: i % 365));
    final timestamp = DateTime.utc(
      date.year,
      date.month,
      date.day,
      12,
      (i ~/ 365) % 60,
      (i ~/ (365 * 60)) % 60,
    );
    final timestampText = timestamp.toIso8601String();
    final project = (i % projects).toString().padLeft(4, "0");
    final cwd = "/benchmark/projects/project-$project";

    index.writeln(
      jsonEncode({
        "id": id,
        "thread_name": "Benchmark session ${i.toString().padLeft(5, '0')}",
        "updated_at": timestampText,
      }),
    );

    final directoryPath = p.join(
      codexHome.path,
      "sessions",
      date.year.toString().padLeft(4, "0"),
      date.month.toString().padLeft(2, "0"),
      date.day.toString().padLeft(2, "0"),
    );
    if (createdDirectories.add(directoryPath)) {
      Directory(directoryPath).createSync(recursive: true);
    }

    final fileTimestamp = timestampText.replaceAll(":", "-").replaceAll(".000Z", "Z");
    final rollout =
        "${jsonEncode({
          'timestamp': timestampText,
          'type': 'session_meta',
          'payload': {
            'id': id,
            'timestamp': timestampText,
            'cwd': cwd,
            'cli_version': '0.142.0',
            'model_provider': 'openai',
          },
        })}\n${jsonEncode({
          'timestamp': timestampText,
          'type': 'turn_context',
          'payload': {'model': 'gpt-5.4-codex'},
        })}\n";
    final rolloutPath = p.join(
      directoryPath,
      "rollout-$fileTimestamp-$id.jsonl",
    );
    File(rolloutPath).writeAsStringSync(rollout);
    rolloutBytes += utf8.encode(rollout).length;
  }

  final indexContents = index.toString();
  File(
    p.join(codexHome.path, "session_index.jsonl"),
  ).writeAsStringSync(indexContents);
  final indexBytes = utf8.encode(indexContents).length;
  return (
    bytes: indexBytes + rolloutBytes,
    files: sessions + 1,
    indexEntries: sessions,
    rolloutFiles: sessions,
  );
}

String _sessionId({required int index}) {
  final hex = index.toRadixString(16).padLeft(32, "0");
  return "${hex.substring(0, 8)}-"
      "${hex.substring(8, 12)}-"
      "${hex.substring(12, 16)}-"
      "${hex.substring(16, 20)}-"
      "${hex.substring(20)}";
}

Map<String, int> _statistics({required List<int> values}) {
  final sorted = [...values]..sort();
  return {
    "p50": _nearestRank(sortedValues: sorted, percentile: 0.50),
    "p95": _nearestRank(sortedValues: sorted, percentile: 0.95),
    "p99": _nearestRank(sortedValues: sorted, percentile: 0.99),
    "max": sorted.last,
  };
}

int _nearestRank({
  required List<int> sortedValues,
  required double percentile,
}) {
  final rank = (percentile * sortedValues.length).ceil();
  return sortedValues[rank - 1];
}

void _validateCount({
  required String operation,
  required int actual,
  required int expected,
}) {
  if (actual != expected) {
    throw StateError("$operation returned $actual records; expected $expected");
  }
}

String _gitCommit() {
  final result = Process.runSync("git", const ["rev-parse", "HEAD"]);
  if (result.exitCode == 0) {
    final commit = result.stdout.toString().trim();
    if (commit.isNotEmpty) return commit;
  }
  stderr.writeln(
    "Unable to resolve git commit: ${result.stderr.toString().trim()}",
  );
  return "unknown";
}

String _cpuModel() {
  if (Platform.isMacOS) {
    final result = Process.runSync(
      "/usr/sbin/sysctl",
      const ["-n", "machdep.cpu.brand_string"],
    );
    if (result.exitCode == 0) {
      final model = result.stdout.toString().trim();
      if (model.isNotEmpty) return model;
    }
    stderr.writeln(
      "Unable to resolve CPU model: ${result.stderr.toString().trim()}",
    );
  } else if (Platform.isLinux) {
    try {
      for (final line in File("/proc/cpuinfo").readAsLinesSync()) {
        if (!line.startsWith("model name")) continue;
        final separator = line.indexOf(":");
        if (separator != -1) return line.substring(separator + 1).trim();
      }
    } on Object catch (error) {
      stderr.writeln("Unable to resolve CPU model: $error");
    }
  } else if (Platform.isWindows) {
    final model = Platform.environment["PROCESSOR_IDENTIFIER"];
    if (model != null && model.isNotEmpty) return model;
  }
  return "unknown";
}
