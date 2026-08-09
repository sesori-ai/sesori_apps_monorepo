import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

final class SessionOptionsCatalog {
  SessionOptionsCatalog({
    required List<AgentInfo> agents,
    required List<ProviderInfo> providers,
    required this.providersConnectedOnly,
    required List<CommandInfo> commands,
  }) : agents = List.unmodifiable(agents),
       providers = List.unmodifiable(providers),
       commands = List.unmodifiable(commands);

  final List<AgentInfo> agents;
  final List<ProviderInfo> providers;
  final bool providersConnectedOnly;
  final List<CommandInfo> commands;
}

sealed class LegacySessionOptionsRepositoryResult {
  const LegacySessionOptionsRepositoryResult();
}

enum LegacySessionOptionSource { agents, providers, commands }

final class LegacySessionOptionError {
  const LegacySessionOptionError({required this.source, required this.error});

  final LegacySessionOptionSource source;
  final ApiError error;
}

final class LegacySessionOptionsRepositoryAvailable extends LegacySessionOptionsRepositoryResult {
  const LegacySessionOptionsRepositoryAvailable({required this.catalog});

  final SessionOptionsCatalog catalog;
}

final class LegacySessionOptionsRepositoryFailure extends LegacySessionOptionsRepositoryResult {
  LegacySessionOptionsRepositoryFailure({required List<LegacySessionOptionError> errors})
    : errors = List.unmodifiable(errors);

  final List<LegacySessionOptionError> errors;
}

final class LegacySessionOptionsRepositoryPartial extends LegacySessionOptionsRepositoryResult {
  LegacySessionOptionsRepositoryPartial({required this.catalog, required List<LegacySessionOptionError> errors})
    : errors = List.unmodifiable(errors);

  final SessionOptionsCatalog catalog;
  final List<LegacySessionOptionError> errors;
}

sealed class SessionOptionsRepositoryResult {
  const SessionOptionsRepositoryResult();
}

final class SessionOptionsRepositoryAvailable extends SessionOptionsRepositoryResult {
  const SessionOptionsRepositoryAvailable({required this.catalog});

  final SessionOptionsCatalog catalog;
}

final class SessionOptionsRepositoryCacheUnavailable extends SessionOptionsRepositoryResult {
  const SessionOptionsRepositoryCacheUnavailable();
}

final class SessionOptionsRepositoryUnsupported extends SessionOptionsRepositoryResult {
  const SessionOptionsRepositoryUnsupported();
}

final class SessionOptionsRepositoryProjectNotFound extends SessionOptionsRepositoryResult {
  const SessionOptionsRepositoryProjectNotFound({required this.error});

  final ApiError error;
}

final class SessionOptionsRepositoryRefreshFailedRetained extends SessionOptionsRepositoryResult {
  const SessionOptionsRepositoryRefreshFailedRetained();
}

final class SessionOptionsRepositoryRefreshFailedUnavailable extends SessionOptionsRepositoryResult {
  const SessionOptionsRepositoryRefreshFailedUnavailable();
}

final class SessionOptionsRepositoryFailure extends SessionOptionsRepositoryResult {
  const SessionOptionsRepositoryFailure({required this.error});

  final ApiError error;
}
