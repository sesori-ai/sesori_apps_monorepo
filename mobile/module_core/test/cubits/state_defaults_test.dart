import "package:sesori_dart_core/src/cubits/project_list/project_list_state.dart";
import "package:sesori_dart_core/src/cubits/session_detail/session_detail_state.dart";
import "package:sesori_dart_core/src/cubits/session_list/session_list_state.dart";
import "package:sesori_shared/sesori_shared.dart";
import "package:test/test.dart";

void main() {
  test("SessionDetailLoaded.isRefreshing defaults to false", () {
    const state = SessionDetailState.loaded(
      messages: [],
      streamingText: {},
      sessionStatus: SessionStatus.idle(),
      pendingQuestions: [],
      sessionTitle: null,
      agent: null,
      modelID: null,
      providerID: null,
      children: [],
      childStatuses: {},
      queuedMessages: [],
      availableAgents: [],
      availableProviders: [],
      selectedAgent: "build",
      selectedProviderID: "p",
      selectedModelID: "m",
      isRefreshing: false,
    );
    expect((state as SessionDetailLoaded).isRefreshing, isFalse);
  });

  test("SessionListLoaded.isRefreshing defaults to false", () {
    const state = SessionListState.loaded(sessions: [], baseBranch: null);
    expect((state as SessionListLoaded).isRefreshing, isFalse);
  });

  test("ProjectListLoaded.isRefreshing defaults to false", () {
    const state = ProjectListState.loaded(projects: [], activityById: {});
    expect((state as ProjectListLoaded).isRefreshing, isFalse);
  });
}
