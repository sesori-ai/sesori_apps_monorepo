import "dart:async";
import "dart:convert";
import "dart:io";

import "../worktree_service.dart";
import "gh_pull_request.dart";

const _ghCommandTimeout = Duration(seconds: 15);

class GhCliService {
  final ProcessRunner _processRunner;

  GhCliService({ProcessRunner processRunner = Process.run}) : _processRunner = processRunner;

  Future<bool> isAvailable() async {
    try {
      final result = await _runGh(arguments: const ["--version"]);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  Future<bool> isAuthenticated() async {
    try {
      final result = await _runGh(arguments: const ["auth", "status"]);
      return result.exitCode == 0;
    } on ProcessException {
      return false;
    } on TimeoutException {
      return false;
    }
  }

  Future<List<GhPullRequest>> listOpenPrs({required String workingDirectory}) async {
    try {
      final result = await _runGh(
        arguments: const <String>[
          "pr",
          "list",
          "--state",
          "open",
          "--json",
          "number,url,title,state,headRefName,mergeable,reviewDecision,statusCheckRollup",
          "--limit",
          "100",
        ],
        workingDirectory: workingDirectory,
      );
      if (result.exitCode != 0) {
        return const <GhPullRequest>[];
      }

      final decoded = jsonDecode(result.stdout.toString());
      final entries = switch (decoded) {
        final List<dynamic> list => list,
        _ => throw const FormatException("Expected PR list JSON array"),
      };

      return entries.map(_parsePullRequest).toList(growable: false);
    } on ProcessException {
      return const <GhPullRequest>[];
    } on TimeoutException {
      return const <GhPullRequest>[];
    } on FormatException {
      return const <GhPullRequest>[];
    }
  }

  Future<GhPullRequest?> getPrByNumber({
    required int number,
    required String workingDirectory,
  }) async {
    try {
      final result = await _runGh(
        arguments: <String>[
          "pr",
          "view",
          number.toString(),
          "--json",
          "number,url,title,state,headRefName,mergeable,reviewDecision,statusCheckRollup",
        ],
        workingDirectory: workingDirectory,
      );
      if (result.exitCode != 0) {
        return null;
      }

      final decoded = jsonDecode(result.stdout.toString());
      return _parsePullRequest(decoded);
    } on ProcessException {
      return null;
    } on TimeoutException {
      return null;
    } on FormatException {
      return null;
    }
  }

  Future<ProcessResult> _runGh({
    required List<String> arguments,
    String? workingDirectory,
  }) {
    return _processRunner("gh", arguments, workingDirectory: workingDirectory).timeout(
      _ghCommandTimeout,
    );
  }

  GhPullRequest _parsePullRequest(Object? jsonObject) {
    final map = switch (jsonObject) {
      final Map<String, dynamic> value => value,
      _ => throw const FormatException("Expected PR JSON object"),
    };

    return GhPullRequest(
      number: _requiredInt(map: map, key: "number"),
      url: _requiredString(map: map, key: "url"),
      title: _requiredString(map: map, key: "title"),
      state: _requiredString(map: map, key: "state"),
      headRefName: _requiredString(map: map, key: "headRefName"),
      mergeable: _nullableString(map: map, key: "mergeable"),
      reviewDecision: _nullableString(map: map, key: "reviewDecision"),
      statusCheckRollup: _nullableString(map: map, key: "statusCheckRollup"),
    );
  }

  int _requiredInt({required Map<String, dynamic> map, required String key}) {
    final value = map[key];
    return switch (value) {
      final int intValue => intValue,
      _ => throw FormatException("Expected int field: $key"),
    };
  }

  String _requiredString({required Map<String, dynamic> map, required String key}) {
    final value = map[key];
    return switch (value) {
      final String stringValue => stringValue,
      _ => throw FormatException("Expected string field: $key"),
    };
  }

  String? _nullableString({required Map<String, dynamic> map, required String key}) {
    final value = map[key];
    return switch (value) {
      null => null,
      final String stringValue => stringValue,
      _ => jsonEncode(value),
    };
  }
}
