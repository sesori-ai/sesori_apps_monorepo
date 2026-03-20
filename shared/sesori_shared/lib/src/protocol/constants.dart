/// Wire protocol constants shared with relay and bridge.
abstract final class RelayProtocol {
  // Message types for bridge status control messages from relay
  static const typeBridgeConnected = "bridge_connected";
  static const typeBridgeDisconnected = "bridge_disconnected";

  // Auth message fields
  static const typeAuth = "auth";
  static const rolePhone = "phone";

  // Payload type detection
  static const int versionByte = 0x01;
  static const int jsonStartByte = 0x7B;
}
