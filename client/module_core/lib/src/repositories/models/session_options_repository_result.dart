import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

final class SessionOptionsCatalog({
    required List<AgentInfo> agents,
    required List<ProviderInfo> providers,
    required this.providersConnectedOnly,
    required List<CommandInfo> commands,
  }) {
  this : agents = List.unmodifiable(agents),
       providers = List.unmodifiable(providers),
       commands = List.unmodifiable(commands);

  final List<AgentInfo> agents;
  final List<ProviderInfo> providers;
  final bool providersConnectedOnly;
  final List<CommandInfo> commands;
}

sealed class const LegacySessionOptionsRepositoryResult();

enum LegacySessionOptionSource() { agents, providers, commands }

final class const LegacySessionOptionError({required this.source, required this.error}) {
  final LegacySessionOptionSource source;
  final ApiError error;
}

final class const LegacySessionOptionsRepositoryAvailable({required this.catalog}) extends LegacySessionOptionsRepositoryResult {
  final SessionOptionsCatalog catalog;
}

final class LegacySessionOptionsRepositoryFailure({required List<LegacySessionOptionError> errors}) extends LegacySessionOptionsRepositoryResult {
  this
    : errors = List.unmodifiable(errors);

  final List<LegacySessionOptionError> errors;
}

final class LegacySessionOptionsRepositoryPartial({required this.catalog, required List<LegacySessionOptionError> errors}) extends LegacySessionOptionsRepositoryResult {
  this
    : errors = List.unmodifiable(errors);

  final SessionOptionsCatalog catalog;
  final List<LegacySessionOptionError> errors;
}

sealed class const SessionOptionsRepositoryResult();

final class const SessionOptionsRepositoryAvailable({required this.catalog}) extends SessionOptionsRepositoryResult {
  final SessionOptionsCatalog catalog;
}

final class const SessionOptionsRepositoryCacheUnavailable() extends SessionOptionsRepositoryResult;

final class const SessionOptionsRepositoryUnsupported() extends SessionOptionsRepositoryResult;

final class const SessionOptionsRepositoryProjectNotFound({required this.error}) extends SessionOptionsRepositoryResult {
  final ApiError error;
}

final class const SessionOptionsRepositoryRefreshFailedRetained() extends SessionOptionsRepositoryResult;

final class const SessionOptionsRepositoryRefreshFailedUnavailable() extends SessionOptionsRepositoryResult;

final class const SessionOptionsRepositoryFailure({required this.error}) extends SessionOptionsRepositoryResult {
  final ApiError error;
}
