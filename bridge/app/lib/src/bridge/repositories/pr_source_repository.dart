import "../api/gh_cli_api.dart";
import "../api/gh_pull_request.dart";
import "../api/git_cli_api.dart";

class PrSourceRepository {
  final GhCliApi _ghCli;
  final GitCliApi _gitCli;

  PrSourceRepository({required GhCliApi ghCli, required GitCliApi gitCli}) : _ghCli = ghCli, _gitCli = gitCli;

  Future<bool> isGithubCliAvailable() => _ghCli.isAvailable();

  Future<bool> isGithubCliAuthenticated() => _ghCli.isAuthenticated();

  Future<bool> hasGitHubRemote({required String projectPath}) => _gitCli.hasGitHubRemote(projectPath: projectPath);

  Future<List<GhPullRequest>> listOpenPrs({required String workingDirectory}) =>
      _ghCli.listOpenPrs(workingDirectory: workingDirectory);

  Future<GhPullRequest> getPrByNumber({required int number, required String workingDirectory}) =>
      _ghCli.getPrByNumber(number: number, workingDirectory: workingDirectory);
}
