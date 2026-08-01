import "../api/gh_cli_api.dart";
import "../api/gh_pull_request.dart";
import "../api/git_cli_api.dart";
import "mappers/git_remote_identity_parser.dart";
import "models/verified_github_login.dart";

class PrSourceRepository {
  static const GitRemoteIdentityParser _remoteIdentityParser = GitRemoteIdentityParser();

  final GhCliApi _ghCli;
  final GitCliApi _gitCli;

  PrSourceRepository({required GhCliApi ghCli, required GitCliApi gitCli}) : _ghCli = ghCli, _gitCli = gitCli;

  Future<bool> isGithubCliAvailable() => _ghCli.isAvailable();

  Future<bool> isGithubCliAuthenticated() => _ghCli.isAuthenticated();

  Future<VerifiedGithubLogin?> getAuthenticatedIdentity() async {
    final identity = await _ghCli.getAuthenticatedIdentity();
    if (identity == null) {
      return null;
    }
    return VerifiedGithubLogin.tryParse(rawLogin: identity.rawLogin);
  }

  Future<String?> getGithubRepositoryIdentity({required String projectPath}) async {
    final remoteUrl = await _gitCli.getRemoteUrl(projectPath: projectPath);
    if (remoteUrl == null) {
      return null;
    }
    final identity = _remoteIdentityParser.parse(remoteUrl: remoteUrl);
    if (identity == null || identity.host != "github.com") {
      return null;
    }
    final segments = identity.slug.split("/");
    if (segments.length != 2 || segments.any((segment) => segment.isEmpty)) {
      return null;
    }
    return identity.slug.toLowerCase();
  }

  Future<List<GhPullRequest>> listOpenPrs({
    required String workingDirectory,
    required String githubRepositoryIdentity,
  }) => _ghCli.listOpenPrs(
    workingDirectory: workingDirectory,
    githubRepositoryIdentity: githubRepositoryIdentity,
  );

  Future<GhPullRequest> getPrByNumber({
    required int number,
    required String workingDirectory,
    required String githubRepositoryIdentity,
  }) => _ghCli.getPrByNumber(
    number: number,
    workingDirectory: workingDirectory,
    githubRepositoryIdentity: githubRepositoryIdentity,
  );
}
