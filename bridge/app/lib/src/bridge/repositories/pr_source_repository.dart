import "../api/gh_pull_request.dart";
import "../api/git_cli_api.dart";

class PrSourceRepository {
  final GitCliApi _gitCli;

  PrSourceRepository({required GitCliApi gitCli}) : _gitCli = gitCli;

  Future<bool> isGithubCliAvailable() => _gitCli.isGithubCliAvailable();

  Future<bool> isGithubCliAuthenticated() => _gitCli.isGithubCliAuthenticated();

  Future<bool> hasGitHubRemote({required String projectPath}) => _gitCli.hasGitHubRemote(projectPath: projectPath);

  Future<List<GhPullRequest>> listOpenPrs({required String workingDirectory}) =>
      _gitCli.listOpenPrs(workingDirectory: workingDirectory);

  Future<GhPullRequest> getPrByNumber({required int number, required String workingDirectory}) =>
      _gitCli.getPrByNumber(number: number, workingDirectory: workingDirectory);
}
