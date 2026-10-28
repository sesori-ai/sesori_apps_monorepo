import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

/// The outcome of asking the bridge for a file preview.
sealed class const FilePreviewResult();

/// The bridge answered with one of its domain outcomes.
final class const FilePreviewLoaded({required final FilePreviewResponse response}) extends FilePreviewResult;

/// The bridge predates `POST /filesystem/file`.
final class const FilePreviewBridgeTooOld() extends FilePreviewResult;

/// The request failed in transport or on the bridge.
final class const FilePreviewFailed({required final ApiError innerError}) extends FilePreviewResult;
