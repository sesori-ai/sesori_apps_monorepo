import "../../foundation/platform/file_access_permission.dart";

class const FileAccessState({required final FileAccessStatus status, required final bool dismissed}) {
  bool get showPrompt => status == FileAccessStatus.denied && !dismissed;
}
