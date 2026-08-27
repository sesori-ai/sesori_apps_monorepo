import "package:sesori_shared/sesori_shared.dart" show DeviceCanvasTurnConfiguration;

abstract interface class DeviceCanvasTurnCredentialIssuer() {
  Future<DeviceCanvasTurnConfiguration> issue({
    required String operationId,
    required int leaseExpiresAt,
    required DateTime now,
  });
}
