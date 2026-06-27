import "package:sesori_shared/sesori_shared.dart";

/// Outcome of an add-project action (create or discover/open).
///
/// Distinguishes a permission denial (so the UI can show an actionable macOS
/// Full Disk Access message) from other failures.
enum AddProjectOutcome { success, permissionDenied, otherError }

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
