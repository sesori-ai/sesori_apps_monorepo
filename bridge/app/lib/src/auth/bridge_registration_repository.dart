import "dart:convert";

import "package:crypto/crypto.dart";
import "package:meta/meta.dart";
import "package:sesori_plugin_interface/sesori_plugin_interface.dart" show Log;
import "package:sesori_shared/sesori_shared.dart";

import "auth_api.dart";
import "machine_id_api.dart";

/// Repository over the auth server's `/auth/bridges` endpoints.
class BridgeRegistrationRepository({
  required final AuthApi _api,
  required final MachineIdApi _machineIdApi,
}) {
  /// Read once per process: the machine identifier does not change while the
  /// bridge runs.
  late final Future<String?> _hostKey = _readHostKey();

  /// Registers (or re-registers) this bridge and returns its [BridgeSummary].
  Future<BridgeSummary> register({
    required String name,
    required String platform,
    required String? bridgeId,
    required String accessToken,
  }) async {
    return await _api.registerBridge(
      name: name,
      platform: platform,
      bridgeId: bridgeId,
      hostKey: await _hostKey,
      accessToken: accessToken,
    );
  }

  /// Removes the registration identified by [bridgeId].
  Future<void> unregister({
    required String bridgeId,
    required String accessToken,
  }) {
    return _api.deleteBridge(bridgeId: bridgeId, accessToken: accessToken);
  }

  /// The salted SHA-256 of [machineId] as lowercase hex. Only this hash is
  /// sent; the raw identifier never leaves the computer.
  @visibleForTesting
  static String hostKeyFor({required String machineId}) {
    return sha256.convert(utf8.encode("sesori-bridge-host-key-v1$machineId")).toString();
  }

  Future<String?> _readHostKey() async {
    final machineId = await _machineIdApi.readMachineId();
    if (machineId == null) {
      Log.w("[registration] no machine identifier; registering without a host key");
      return null;
    }
    return hostKeyFor(machineId: machineId);
  }
}
