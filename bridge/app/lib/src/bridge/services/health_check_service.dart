import 'package:sesori_shared/sesori_shared.dart';

import '../../repositories/server_health_repository.dart';
import '../models/bridge_config.dart';

class HealthCheckService {
  final ServerHealthRepository _repository;
  final ServerStateKind Function() _readServerState;
  final BridgeConfig _config;

  HealthCheckService({
    required ServerHealthRepository repository,
    required ServerStateKind Function() readServerState,
    required BridgeConfig config,
  }) : _repository = repository,
       _readServerState = readServerState,
       _config = config;

  Future<HealthResponse> check() async {
    final healthy = await _repository.healthCheck();
    return HealthResponse(
      healthy: healthy,
      version: _config.version,
      serverManaged: _config.serverManaged,
      serverState: _readServerState(),
    );
  }
}
