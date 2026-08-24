import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

/// Outcome of asking the bridge to start or cancel one plugin's catalog import.
///
/// `404` and `503` are separated rather than folded into one "cannot import"
/// case, because they mean different things to a caller fanning out: `503` is a
/// harness the bridge knows but cannot start right now, while `404` from every
/// harness at once is how a bridge with no `/plugin/import` route at all
/// presents itself.
sealed class const CatalogImportMutationResult() {
  const factory accepted() = CatalogImportMutationAccepted;

  const factory notFound() = CatalogImportMutationNotFound;

  const factory unavailable() = CatalogImportMutationUnavailable;

  const factory failure({required ApiError error}) = CatalogImportMutationFailure;
}

final class const CatalogImportMutationAccepted() extends CatalogImportMutationResult;

/// The bridge answered `404`: it does not know this plugin, or it has no
/// catalog import route.
final class const CatalogImportMutationNotFound() extends CatalogImportMutationResult;

/// The bridge answered `503`: it knows the plugin but cannot import from it.
final class const CatalogImportMutationUnavailable() extends CatalogImportMutationResult;

/// Anything else, including a request that may never have reached the bridge.
/// [error] is retained so the caller can log it; a transport or decoding
/// failure cannot be explained by the bridge's own log.
final class const CatalogImportMutationFailure({required final ApiError error})
    extends CatalogImportMutationResult;

/// Outcome of reading the bridge's latest per-plugin import statuses.
sealed class const CatalogImportStatusesResult() {
  const factory supported({required List<CatalogImportProgress> statuses}) =
      CatalogImportStatusesSupported;

  const factory unsupported() = CatalogImportStatusesUnsupported;

  const factory failure({required ApiError error}) = CatalogImportStatusesFailure;
}

final class const CatalogImportStatusesSupported({
  required final List<CatalogImportProgress> statuses,
}) extends CatalogImportStatusesResult;

/// The bridge has no catalog import route.
final class const CatalogImportStatusesUnsupported() extends CatalogImportStatusesResult;

final class const CatalogImportStatusesFailure({required final ApiError error})
    extends CatalogImportStatusesResult;
