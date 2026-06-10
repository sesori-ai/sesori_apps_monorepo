// Generates release notes with an App/Bridge split for GitHub releases.
//
// Lists the PRs merged between a previous stable release tag and a target
// ref, classifies each PR by the paths it touched (mobile/** -> App,
// bridge/** -> Bridge, shared/** -> both), buckets entries into
// Added/Fixed/Changed from the conventional-commit PR title prefix, and
// appends the flat "All PRs merged" list plus a Full Changelog compare link.
//
// Used by both the per-merge rolling internal pre-release and the production
// release created by submit-release.yml, so it must stay deterministic and
// dependency-free (run it with plain `dart tool/generate_release_notes.dart`,
// no pub get required).
//
// Usage:
//   GITHUB_TOKEN=... dart tool/generate_release_notes.dart \
//     --repo owner/name \
//     --to <sha-or-tag> \
//     --version <X.Y.Z or X.Y.Z-internal.N> \
//     [--from <tag>] \
//     [--output <file>]
//
// When --from is omitted, the previous stable tag is auto-resolved: the
// highest-semver published (non-draft, non-prerelease) release whose tag is a
// plain vX.Y.Z, excluding the version being released; if no such release
// exists yet (first release on the unified v* scheme), it falls back to the
// highest plain vX.Y.Z git tag strictly below the version being released.

import 'dart:convert';
import 'dart:io';

const String _ignoreLabel = 'ignore-for-release';
const Set<String> _excludedAuthors = {'dependabot', 'dependabot[bot]'};

void main(final List<String> args) async {
  final options = _parseArgs(args: args);
  final token = Platform.environment['GITHUB_TOKEN'] ?? Platform.environment['GH_TOKEN'];
  if (token == null || token.isEmpty) {
    stderr.writeln('Error: GITHUB_TOKEN (or GH_TOKEN) must be set.');
    exit(1);
  }

  final api = _GitHubApi(repo: options.repo, token: token);

  try {
    final fromTag = options.from ?? await _resolvePreviousStableTag(api: api, version: options.version);
    stderr.writeln('Comparing $fromTag...${options.to}');

    final prNumbers = await _listMergedPrNumbers(api: api, from: fromTag, to: options.to);
    final entries = <_PrEntry>[];
    for (final number in prNumbers) {
      final entry = await _loadPr(api: api, number: number);
      if (entry != null) {
        entries.add(entry);
      }
    }

    final notes = _render(
      repo: options.repo,
      from: fromTag,
      to: options.to,
      entries: entries,
    );

    if (options.output != null) {
      await File(options.output!).writeAsString(notes);
      stderr.writeln('Wrote release notes to ${options.output}');
    } else {
      stdout.write(notes);
    }
  } finally {
    api.close();
  }
}

class _Options {
  const _Options({
    required this.repo,
    required this.to,
    required this.version,
    required this.from,
    required this.output,
  });

  final String repo;
  final String to;
  final String version;
  final String? from;
  final String? output;
}

_Options _parseArgs({required List<String> args}) {
  final values = <String, String>{};
  for (var i = 0; i < args.length; i += 2) {
    final flag = args[i];
    if (!flag.startsWith('--') || i + 1 >= args.length) {
      stderr.writeln('Error: malformed arguments near "$flag".');
      exit(1);
    }
    values[flag.substring(2)] = args[i + 1];
  }

  final repo = values['repo'];
  final to = values['to'];
  final version = values['version'];
  if (repo == null || to == null || version == null) {
    stderr.writeln('Usage: dart tool/generate_release_notes.dart '
        '--repo owner/name --to <ref> --version <X.Y.Z[-pre]> [--from <tag>] [--output <file>]');
    exit(1);
  }

  return _Options(
    repo: repo,
    to: to,
    version: version,
    from: values['from'],
    output: values['output'],
  );
}

class _GitHubApi {
  _GitHubApi({required this.repo, required String token})
    : _client = HttpClient(),
      _token = token;

  final String repo;
  final HttpClient _client;
  final String _token;

  Future<dynamic> getJson({required String path}) async {
    final uri = Uri.parse('https://api.github.com$path');
    final request = await _client.getUrl(uri);
    request.headers.set('Authorization', 'Bearer $_token');
    request.headers.set('Accept', 'application/vnd.github+json');
    request.headers.set('X-GitHub-Api-Version', '2022-11-28');
    request.headers.set('User-Agent', 'sesori-release-notes');
    final response = await request.close();
    final body = await response.transform(utf8.decoder).join();
    if (response.statusCode != 200) {
      throw StateError('GET $path returned ${response.statusCode}: $body');
    }
    return jsonDecode(body);
  }

  void close() {
    _client.close(force: true);
  }
}

final RegExp _stableTagPattern = RegExp(r'^v(\d+)\.(\d+)\.(\d+)$');

List<int>? _parseStableTag({required String tag}) {
  final match = _stableTagPattern.firstMatch(tag);
  if (match == null) {
    return null;
  }
  return [
    int.parse(match.group(1)!),
    int.parse(match.group(2)!),
    int.parse(match.group(3)!),
  ];
}

int _compareSemver(final List<int> a, final List<int> b) {
  for (var i = 0; i < 3; i++) {
    final diff = a[i].compareTo(b[i]);
    if (diff != 0) {
      return diff;
    }
  }
  return 0;
}

Future<String> _resolvePreviousStableTag({
  required _GitHubApi api,
  required String version,
}) async {
  // Base version being released (strip any pre-release suffix) so the
  // previous-stable lookup never picks the release we are creating notes for.
  final baseVersion = version.split('-').first;
  final excludedTag = 'v$baseVersion';

  String? best;
  List<int>? bestParts;

  void consider({required String tag}) {
    if (tag == excludedTag) {
      return;
    }
    final parts = _parseStableTag(tag: tag);
    if (parts == null) {
      return;
    }
    if (bestParts == null || _compareSemver(parts, bestParts!) > 0) {
      best = tag;
      bestParts = parts;
    }
  }

  // Preferred source: published stable releases (what the bridge updater and
  // end users actually received last).
  for (var page = 1; page <= 3; page++) {
    final releases = await api.getJson(path: '/repos/${api.repo}/releases?per_page=100&page=$page') as List<dynamic>;
    for (final release in releases.cast<Map<String, dynamic>>()) {
      if (release['draft'] == true || release['prerelease'] == true) {
        continue;
      }
      consider(tag: release['tag_name'] as String);
    }
    if (releases.length < 100) {
      break;
    }
  }
  if (best != null) {
    return best!;
  }

  // Fallback for the first release on the unified v* scheme: plain stable
  // tags (beta submits tag without creating a release).
  final currentParts = _parseStableTag(tag: excludedTag);
  for (var page = 1; page <= 5; page++) {
    final tags = await api.getJson(path: '/repos/${api.repo}/tags?per_page=100&page=$page') as List<dynamic>;
    for (final tag in tags.cast<Map<String, dynamic>>()) {
      final name = tag['name'] as String;
      final parts = _parseStableTag(tag: name);
      if (parts == null) {
        continue;
      }
      if (currentParts != null && _compareSemver(parts, currentParts) >= 0) {
        continue;
      }
      consider(tag: name);
    }
    if (tags.length < 100) {
      break;
    }
  }
  if (best != null) {
    return best!;
  }

  throw StateError('Could not resolve a previous stable v* release or tag to diff against. '
      'Pass --from explicitly.');
}

final RegExp _squashPrPattern = RegExp(r'\(#(\d+)\)');
final RegExp _mergePrPattern = RegExp(r'^Merge pull request #(\d+)');

Future<List<int>> _listMergedPrNumbers({
  required _GitHubApi api,
  required String from,
  required String to,
}) async {
  final numbers = <int>[];
  final seen = <int>{};

  for (var page = 1; page <= 10; page++) {
    final comparison =
        await api.getJson(path: '/repos/${api.repo}/compare/$from...$to?per_page=100&page=$page')
            as Map<String, dynamic>;
    final commits = (comparison['commits'] as List<dynamic>).cast<Map<String, dynamic>>();
    for (final commit in commits) {
      final message = (commit['commit'] as Map<String, dynamic>)['message'] as String;
      final subject = message.split('\n').first;
      final match = _mergePrPattern.firstMatch(subject) ?? _squashPrPattern.firstMatch(subject);
      if (match == null) {
        continue;
      }
      final number = int.parse(match.group(1)!);
      if (seen.add(number)) {
        numbers.add(number);
      }
    }
    if (commits.length < 100) {
      break;
    }
  }

  return numbers;
}

class _PrEntry {
  const _PrEntry({
    required this.number,
    required this.title,
    required this.author,
    required this.url,
    required this.touchesApp,
    required this.touchesBridge,
    required this.touchesShared,
  });

  final int number;
  final String title;
  final String author;
  final String url;
  final bool touchesApp;
  final bool touchesBridge;
  final bool touchesShared;
}

Future<_PrEntry?> _loadPr({required _GitHubApi api, required int number}) async {
  final pr = await api.getJson(path: '/repos/${api.repo}/pulls/$number') as Map<String, dynamic>;

  final author = ((pr['user'] as Map<String, dynamic>?)?['login'] as String?) ?? 'unknown';
  if (_excludedAuthors.contains(author)) {
    return null;
  }
  final labels = (pr['labels'] as List<dynamic>? ?? [])
      .cast<Map<String, dynamic>>()
      .map((label) => label['name'] as String);
  if (labels.contains(_ignoreLabel)) {
    return null;
  }

  var touchesApp = false;
  var touchesBridge = false;
  var touchesShared = false;
  for (var page = 1; page <= 10; page++) {
    final files = await api.getJson(path: '/repos/${api.repo}/pulls/$number/files?per_page=100&page=$page')
        as List<dynamic>;
    for (final file in files.cast<Map<String, dynamic>>()) {
      final path = file['filename'] as String;
      touchesApp = touchesApp || path.startsWith('mobile/');
      touchesBridge = touchesBridge || path.startsWith('bridge/');
      touchesShared = touchesShared || path.startsWith('shared/');
    }
    if (files.length < 100 || (touchesApp && touchesBridge && touchesShared)) {
      break;
    }
  }

  return _PrEntry(
    number: number,
    title: (pr['title'] as String).trim(),
    author: author,
    url: pr['html_url'] as String,
    touchesApp: touchesApp,
    touchesBridge: touchesBridge,
    touchesShared: touchesShared,
  );
}

final RegExp _conventionalPrefixPattern = RegExp(r'^(\w+)(\([^)]*\))?!?:\s*');

String _bucketFor({required String title}) {
  final match = _conventionalPrefixPattern.firstMatch(title);
  final type = match?.group(1)?.toLowerCase();
  switch (type) {
    case 'feat':
      return 'Added';
    case 'fix':
    case 'bug':
      return 'Fixed';
    default:
      return 'Changed';
  }
}

String _displayTitle({required _PrEntry entry}) {
  var title = entry.title.replaceFirst(_conventionalPrefixPattern, '');
  if (title.isNotEmpty) {
    title = title[0].toUpperCase() + title.substring(1);
  }
  final sharedMarker = entry.touchesShared ? ' *(shared)*' : '';
  return '$title (#${entry.number})$sharedMarker';
}

String _render({
  required String repo,
  required String from,
  required String to,
  required List<_PrEntry> entries,
}) {
  final buffer = StringBuffer('## What\'s Changed\n');

  void writeSection({
    required String section,
    required bool Function(_PrEntry entry) selector,
  }) {
    final selected = entries.where(selector).toList();
    if (selected.isEmpty) {
      return;
    }
    buffer.write('\n### $section\n');
    for (final bucket in const ['Added', 'Fixed', 'Changed']) {
      final bucketEntries = selected.where((entry) => _bucketFor(title: entry.title) == bucket).toList();
      if (bucketEntries.isEmpty) {
        continue;
      }
      buffer.write('\n#### $bucket\n');
      for (final entry in bucketEntries) {
        buffer.writeln('- ${_displayTitle(entry: entry)}');
      }
    }
  }

  // shared/** is consumed by both sides, so shared-touching PRs are listed
  // under both App and Bridge (marked "(shared)").
  writeSection(section: 'App', selector: (entry) => entry.touchesApp || entry.touchesShared);
  writeSection(section: 'Bridge', selector: (entry) => entry.touchesBridge || entry.touchesShared);

  if (entries.isNotEmpty) {
    buffer.write('\n### All PRs merged\n');
    for (final entry in entries) {
      buffer.writeln('* ${entry.title} by @${entry.author} in ${entry.url}');
    }
  } else {
    buffer.write('\nNo pull requests merged in this range.\n');
  }

  buffer.write('\n**Full Changelog**: https://github.com/$repo/compare/$from...$to\n');
  return buffer.toString();
}
