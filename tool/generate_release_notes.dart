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
// plain vX.Y.Z strictly below the version being released; if no such release
// exists yet (first release on the unified v* scheme), it falls back to the
// highest plain vX.Y.Z git tag strictly below the version being released.
// "Strictly below" (not merely "excluding the target") keeps backfilled or
// out-of-order regenerations from picking a newer release as the base.

import 'dart:convert';
import 'dart:io';

import 'release_notes_resolver.dart';

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

Future<String> _resolvePreviousStableTag({
  required _GitHubApi api,
  required String version,
}) async {
  // Preferred source: published stable releases (what the bridge updater and
  // end users actually received last). Drafts and prereleases are filtered out
  // here so an unpromoted vX.Y.Z tag never becomes the comparison base.
  final releaseTags = <String>[];
  for (var page = 1; page <= 3; page++) {
    final releases = await api.getJson(path: '/repos/${api.repo}/releases?per_page=100&page=$page') as List<dynamic>;
    for (final release in releases.cast<Map<String, dynamic>>()) {
      if (release['draft'] == true || release['prerelease'] == true) {
        continue;
      }
      releaseTags.add(release['tag_name'] as String);
    }
    if (releases.length < 100) {
      break;
    }
  }
  final fromRelease = selectPreviousStableTag(candidateTags: releaseTags, version: version);
  if (fromRelease != null) {
    return fromRelease;
  }

  // Fallback for the first release on the unified v* scheme: plain stable
  // tags (beta submits tag without creating a release).
  final tagNames = <String>[];
  for (var page = 1; page <= 5; page++) {
    final tags = await api.getJson(path: '/repos/${api.repo}/tags?per_page=100&page=$page') as List<dynamic>;
    for (final tag in tags.cast<Map<String, dynamic>>()) {
      tagNames.add(tag['name'] as String);
    }
    if (tags.length < 100) {
      break;
    }
  }
  final fromTag = selectPreviousStableTag(candidateTags: tagNames, version: version);
  if (fromTag != null) {
    return fromTag;
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
  var scannedCommits = 0;
  var totalCommits = 0;

  var page = 1;
  while (true) {
    final comparison =
        await api.getJson(path: '/repos/${api.repo}/compare/$from...$to?per_page=100&page=$page')
            as Map<String, dynamic>;
    totalCommits = comparison['total_commits'] as int? ?? totalCommits;
    final commits = (comparison['commits'] as List<dynamic>).cast<Map<String, dynamic>>();
    scannedCommits += commits.length;
    for (final commit in commits) {
      final message = (commit['commit'] as Map<String, dynamic>)['message'] as String;
      final subject = message.split('\n').first;
      final match = _mergePrPattern.firstMatch(subject) ?? _squashPrPattern.firstMatch(subject);
      if (match != null) {
        final number = int.parse(match.group(1)!);
        if (seen.add(number)) {
          numbers.add(number);
        }
        continue;
      }
      // Commits without a (#N) / merge-commit subject (rebase merges, edited
      // squash titles, direct pushes): resolve through GitHub's commit -> PR
      // association instead of silently dropping them.
      final sha = commit['sha'] as String;
      final associated =
          await api.getJson(path: '/repos/${api.repo}/commits/$sha/pulls?per_page=10') as List<dynamic>;
      for (final pull in associated.cast<Map<String, dynamic>>()) {
        if (pull['merged_at'] == null) {
          continue;
        }
        final number = pull['number'] as int;
        if (seen.add(number)) {
          numbers.add(number);
        }
      }
    }
    if (commits.length < 100) {
      break;
    }
    page++;
  }

  // Never truncate silently: incomplete notes on a release are worse than a
  // failed workflow run (pass --from for a shorter range if this ever trips).
  if (scannedCommits < totalCommits) {
    throw StateError('Compare $from...$to reports $totalCommits commits but only '
        '$scannedCommits were returned; refusing to publish truncated release notes.');
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
  final changedFiles = pr['changed_files'] as int? ?? 0;
  var listedFiles = 0;
  var page = 1;
  while (true) {
    final files = await api.getJson(path: '/repos/${api.repo}/pulls/$number/files?per_page=100&page=$page')
        as List<dynamic>;
    listedFiles += files.length;
    for (final file in files.cast<Map<String, dynamic>>()) {
      final path = file['filename'] as String;
      touchesApp = touchesApp || path.startsWith('mobile/');
      touchesBridge = touchesBridge || path.startsWith('bridge/');
      touchesShared = touchesShared || path.startsWith('shared/');
    }
    if (files.length < 100 || (touchesApp && touchesBridge && touchesShared)) {
      break;
    }
    page++;
  }
  // The files API stops listing at 3000 files. If a PR is so large we could
  // not see every file, degrade conservatively: list it under both sections
  // rather than silently misclassifying it.
  if (listedFiles < changedFiles && !(touchesApp && touchesBridge)) {
    stderr.writeln('PR #$number lists only $listedFiles of $changedFiles changed files; '
        'classifying it under both App and Bridge.');
    touchesApp = true;
    touchesBridge = true;
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
