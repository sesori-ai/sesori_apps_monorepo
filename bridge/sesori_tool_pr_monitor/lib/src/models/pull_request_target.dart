import "package:meta/meta.dart";

/// A GitHub pull request named explicitly by an agent: `owner/repo#N` or its
/// full URL. Nothing is inferred from a working directory.
@immutable
class const PullRequestTarget({
  required final String owner,
  required final String repo,
  required final int number,
}) {
  static final RegExp _shortForm = RegExp(r"^([A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)/([A-Za-z0-9._-]+)#(\d+)$");
  static final RegExp _urlForm = RegExp(
    r"^https://github\.com/([A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)/([A-Za-z0-9._-]+)/pull/(\d+)(?:[/?#].*)?$",
  );

  /// Parses an agent-supplied identifier, or throws [FormatException] whose
  /// message is the text to show the agent.
  factory parse({required String input}) {
    final trimmed = input.trim();
    final match = _shortForm.firstMatch(trimmed) ?? _urlForm.firstMatch(trimmed);
    final owner = match?.group(1);
    final repo = match?.group(2);
    final digits = match?.group(3);
    final number = digits == null ? null : int.tryParse(digits);
    if (owner == null || repo == null || number == null) {
      throw FormatException(
        'Invalid PR identifier: "$input". Use "owner/repo#123" or a full PR URL '
        "(https://github.com/owner/repo/pull/123). The repo must always be explicit.",
      );
    }
    return PullRequestTarget(owner: owner, repo: repo, number: number);
  }

  static final RegExp _repositoryForm = RegExp(r"^([A-Za-z0-9](?:[A-Za-z0-9-]*[A-Za-z0-9])?)/([A-Za-z0-9._-]+)$");

  /// Parses an agent-supplied `owner/repo` into its lowercased key, or
  /// throws [FormatException] whose message is the text to show the agent.
  static String parseRepositoryKey({required String input}) {
    if (_repositoryForm.firstMatch(input.trim()) case RegExpMatch(:final input)) return input.toLowerCase();
    throw FormatException('Invalid repository: "$input". Use "owner/repo".');
  }

  /// `owner/repo#N` as the agent wrote it, for messages.
  String get displayKey => "$owner/$repo#$number";

  /// The case-insensitive identity of the PR, for storage and fan-out.
  String get registryKey => "$repositoryKey#$number";

  /// The case-insensitive identity of the PR's repository, for settings.
  String get repositoryKey => "${owner.toLowerCase()}/${repo.toLowerCase()}";

  String get url => "https://github.com/$owner/$repo/pull/$number";

  @override
  bool operator ==(Object other) =>
      other is PullRequestTarget && other.owner == owner && other.repo == repo && other.number == number;

  @override
  int get hashCode => Object.hash(owner, repo, number);

  @override
  String toString() => "PullRequestTarget($displayKey)";
}
