/// What is known of the project the user was last in on the connected
/// computer: the one last picked in the new-session composer or started a
/// session in.
sealed class const LastNewSessionProject();

/// Not read yet for the connected computer, or no computer is connected yet.
final class const LastNewSessionProjectUnknown() extends LastNewSessionProject;

/// Read for the connected computer: [projectId] is the project, or null when
/// the user never picked or started in one there.
final class const LastNewSessionProjectKnown({required final String? projectId}) extends LastNewSessionProject;
