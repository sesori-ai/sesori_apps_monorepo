import "../api/gh_cli_api.dart";
import "../api/gh_pull_request.dart";
import "../api/git_remote_api.dart";

abstract interface class PrSourceRepositoryLike {
  Future<bool> isGitHubAvailable();
  Future<bool> isGitHubAuthenticated();
  Future<bool> hasGitHubRemote({required String projectPath});
  Future<List<GhPullRequest>> listOpenPrs({required String workingDirectory});
  Future<GhPullRequest> getPrByNumber({required int number, required String workingDirectory});
}

class PrSourceRepository implements PrSourceRepositoryLike {
  final GhCliApi _ghCli;
  final GitRemoteApi _gitRemoteApi;

  PrSourceRepository({
    required GhCliApi ghCli,
    required GitRemoteApi gitRemoteApi,
  }) : _ghCli = ghCli,
       _gitRemoteApi = gitRemoteApi;

  @override
  Future<bool> isGitHubAvailable() => _ghCli.isAvailable();

  @override
  Future<bool> isGitHubAuthenticated() => _ghCli.isAuthenticated();

  @override
  Future<bool> hasGitHubRemote({required String projectPath}) =>
      _gitRemoteApi.hasGitHubRemote(projectPath: projectPath);

  @override
  Future<List<GhPullRequest>> listOpenPrs({required String workingDirectory}) =>
      _ghCli.listOpenPrs(workingDirectory: workingDirectory);

  @override
  Future<GhPullRequest> getPrByNumber({required int number, required String workingDirectory}) =>
      _ghCli.getPrByNumber(number: number, workingDirectory: workingDirectory);
}
