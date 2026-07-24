import "package:sesori_shared/sesori_shared.dart";

/// Outcome of an add-project action (create or discover/open).
///
/// Distinguishes a permission denial (so the UI can show an actionable macOS
/// Full Disk Access message) from other failures.
enum AddProjectOutcome { success, permissionDenied, otherError }

enum OpenProjectOutcome {
  success,
  gitChoiceRequired,
  gitSetupIncomplete,
  permissionDenied,
  otherError,
}

/// Outcome of fetching filesystem suggestions for the directory browser.
sealed class FilesystemSuggestionsOutcome {
  const FilesystemSuggestionsOutcome();
}

/// Suggestions were fetched successfully.
class FilesystemSuggestionsSuccess extends FilesystemSuggestionsOutcome {
  final FilesystemSuggestions suggestions;

  const FilesystemSuggestionsSuccess({required this.suggestions});
}

/// The bridge denied access to the directory (macOS permission / Full Disk Access).
class FilesystemSuggestionsPermissionDenied extends FilesystemSuggestionsOutcome {
  const FilesystemSuggestionsPermissionDenied();
}

/// Any other failure (directory missing, bridge error, network).
class FilesystemSuggestionsError extends FilesystemSuggestionsOutcome {
  const FilesystemSuggestionsError();
}

/// Outcome of creating a folder from the directory browser.
sealed class CreateDirectoryOutcome {
  const CreateDirectoryOutcome();
}

/// The folder was created; [directory] is the entry the bridge produced, so the
/// browser can navigate straight into the host's own path for it.
class CreateDirectorySuccess extends CreateDirectoryOutcome {
  final FilesystemSuggestion directory;

  const CreateDirectorySuccess({required this.directory});
}

/// A folder of that name is already there.
class CreateDirectoryAlreadyExists extends CreateDirectoryOutcome {
  const CreateDirectoryAlreadyExists();
}

/// The bridge denied access to the parent directory (macOS permission / Full
/// Disk Access).
class CreateDirectoryPermissionDenied extends CreateDirectoryOutcome {
  const CreateDirectoryPermissionDenied();
}

/// The connected bridge predates the create-folder endpoint, so it answered
/// "no such route". Surfaced distinctly: the action is unavailable until that
/// machine's bridge is updated, which retrying will not change.
class CreateDirectoryUnsupported extends CreateDirectoryOutcome {
  const CreateDirectoryUnsupported();
}

/// Any other failure (invalid name, bridge error, network).
class CreateDirectoryError extends CreateDirectoryOutcome {
  const CreateDirectoryError();
}
