import "package:sesori_shared/sesori_shared.dart";

/// Outcome of an add-project action (create or discover/open).
///
/// Distinguishes a permission denial (so the UI can show an actionable macOS
/// Full Disk Access message) from other failures.
enum AddProjectOutcome() { success, permissionDenied, otherError }

enum OpenProjectOutcome() {
  success,
  gitChoiceRequired,
  gitSetupIncomplete,
  permissionDenied,
  otherError,
}

/// Outcome of fetching filesystem suggestions for the directory browser.
sealed class const FilesystemSuggestionsOutcome();

/// Suggestions were fetched successfully.
class const FilesystemSuggestionsSuccess({required final FilesystemSuggestions suggestions}) extends FilesystemSuggestionsOutcome;

/// The bridge denied access to the directory (macOS permission / Full Disk Access).
class const FilesystemSuggestionsPermissionDenied() extends FilesystemSuggestionsOutcome;

/// Any other failure (directory missing, bridge error, network).
class const FilesystemSuggestionsError() extends FilesystemSuggestionsOutcome;

/// Outcome of creating a folder from the directory browser.
sealed class const CreateDirectoryOutcome();

/// The folder was created; [directory] is the entry the bridge produced, so the
/// browser can navigate straight into the host's own path for it.
class const CreateDirectorySuccess({required final FilesystemSuggestion directory}) extends CreateDirectoryOutcome;

/// A folder of that name is already there.
class const CreateDirectoryAlreadyExists() extends CreateDirectoryOutcome;

/// The bridge denied access to the parent directory (macOS permission / Full
/// Disk Access).
class const CreateDirectoryPermissionDenied() extends CreateDirectoryOutcome;

/// The connected bridge predates the create-folder endpoint, so it answered
/// "no such route". Surfaced distinctly: the action is unavailable until that
/// machine's bridge is updated, which retrying will not change.
class const CreateDirectoryUnsupported() extends CreateDirectoryOutcome;

/// Any other failure (invalid name, bridge error, network).
class const CreateDirectoryError() extends CreateDirectoryOutcome;
