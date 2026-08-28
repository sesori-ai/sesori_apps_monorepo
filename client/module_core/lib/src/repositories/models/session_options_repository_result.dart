import "package:sesori_auth/sesori_auth.dart";
import "package:sesori_shared/sesori_shared.dart";

final class SessionOptionsCatalog({
    required List<AgentInfo> agents,
    required List<ProviderInfo> providers,
    required final bool providersConnectedOnly,
    required List<CommandInfo> commands,
    required final SessionPromptDefaults? lastUsedPromptDefaults,
  }) {

  final List<AgentInfo> agents = List.unmodifiable(agents);
  final List<ProviderInfo> providers = List.unmodifiable(providers);
  final List<CommandInfo> commands = List.unmodifiable(commands);
}

sealed class const LegacySessionOptionsRepositoryResult();

enum LegacySessionOptionSource() { agents, providers, commands }

final class const LegacySessionOptionError({required final LegacySessionOptionSource source, required final ApiError error});

final class const LegacySessionOptionsRepositoryAvailable({required final SessionOptionsCatalog catalog}) extends LegacySessionOptionsRepositoryResult;

final class LegacySessionOptionsRepositoryFailure({required List<LegacySessionOptionError> errors}) extends LegacySessionOptionsRepositoryResult {

  final List<LegacySessionOptionError> errors = List.unmodifiable(errors);
}

final class LegacySessionOptionsRepositoryPartial({required final SessionOptionsCatalog catalog, required List<LegacySessionOptionError> errors}) extends LegacySessionOptionsRepositoryResult {

  final List<LegacySessionOptionError> errors = List.unmodifiable(errors);
}

sealed class const SessionOptionsRepositoryResult();

final class const SessionOptionsRepositoryAvailable({required final SessionOptionsCatalog catalog, required final bool isStale}) extends SessionOptionsRepositoryResult;

final class const SessionOptionsRepositoryCacheUnavailable() extends SessionOptionsRepositoryResult;

final class const SessionOptionsRepositoryUnsupported() extends SessionOptionsRepositoryResult;

final class const SessionOptionsRepositoryProjectNotFound({required final ApiError error}) extends SessionOptionsRepositoryResult;

final class const SessionOptionsRepositoryRefreshFailedRetained() extends SessionOptionsRepositoryResult;

final class const SessionOptionsRepositoryRefreshFailedUnavailable() extends SessionOptionsRepositoryResult;

final class const SessionOptionsRepositoryFailure({required final ApiError error}) extends SessionOptionsRepositoryResult;
