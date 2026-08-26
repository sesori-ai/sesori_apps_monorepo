import "dart:convert";

import "package:sesori_shared/sesori_shared.dart"
    show
        DeviceCanvasRtcDescriptionType,
        jsonDecodeMap,
        maxDeviceCanvasIceCandidates,
        maxDeviceCanvasStreamLeaseIdLength;

import "protocol.dart";

const int maxDeviceCanvasIpcFrameBytes = 1024 * 1024;
const int maxDeviceCanvasInventoryDevices = 64;
const int maxDeviceCanvasIpcIdentifierLength = 512;
const int maxDeviceCanvasIpcDisplayLength = 512;
const int maxDeviceCanvasDimension = 32768;
const int maxDeviceCanvasStreamRequestIdLength = 128;

class const DeviceCanvasProtocolCodec() {
  DeviceCanvasInboundMessage decodeInbound(String frame) {
    if (frame.length > maxDeviceCanvasIpcFrameBytes || utf8.encode(frame).length > maxDeviceCanvasIpcFrameBytes) {
      throw const FormatException("Device Canvas IPC frame exceeds the size limit");
    }
    final message = DeviceCanvasInboundMessage.fromJson(jsonDecodeMap(frame));
    _validateInbound(message);
    return message;
  }

  String encodeOutbound(DeviceCanvasOutboundMessage message) {
    final frame = jsonEncode(message.toJson());
    if (utf8.encode(frame).length > maxDeviceCanvasIpcFrameBytes) {
      throw const FormatException("Device Canvas IPC frame exceeds the size limit");
    }
    return frame;
  }

  void _validateInbound(DeviceCanvasInboundMessage message) {
    switch (message) {
      case DeviceCanvasHello(:final canvasInstanceId):
        if (!_isBoundedString(canvasInstanceId, maxDeviceCanvasIpcIdentifierLength)) {
          throw const FormatException("invalid canvasInstanceId");
        }
      case DeviceCanvasInventorySnapshot(:final devices):
        if (devices.length > maxDeviceCanvasInventoryDevices) {
          throw const FormatException("Device Canvas inventory exceeds the device limit");
        }
        final seenDeviceKeys = <String>{};
        for (final device in devices) {
          if (!device.isValid) throw const FormatException("invalid Device Canvas descriptor");
          final dimensions = device.dimensions;
          if (!_isBoundedString(device.deviceKey, maxDeviceCanvasIpcIdentifierLength) ||
              !_isBoundedString(device.displayName, maxDeviceCanvasIpcDisplayLength) ||
              !_isBoundedString(device.runtimeDescription, maxDeviceCanvasIpcDisplayLength) ||
              !_isBoundedString(device.modelDescription, maxDeviceCanvasIpcDisplayLength) ||
              (dimensions != null &&
                  (dimensions.width > maxDeviceCanvasDimension || dimensions.height > maxDeviceCanvasDimension))) {
            throw const FormatException("Device Canvas descriptor exceeds protocol limits");
          }
          if (!seenDeviceKeys.add(device.deviceKey)) throw const FormatException("duplicate Device Canvas device key");
        }
      case DeviceCanvasHeartbeat(:final canvasInstanceId, :final observedAt):
        if (!_isBoundedString(canvasInstanceId, maxDeviceCanvasIpcIdentifierLength)) {
          throw const FormatException("invalid canvasInstanceId");
        }
        if (observedAt <= 0) throw const FormatException("observedAt must be positive");
      case DeviceCanvasStreamStartedMessage(
        :final requestId,
        :final leaseId,
        :final answer,
        :final iceCandidates,
      ):
        _validateStreamCorrelation(requestId: requestId, leaseId: leaseId);
        if (answer.type != DeviceCanvasRtcDescriptionType.answer || !answer.isValid) {
          throw const FormatException("invalid Device Canvas stream answer");
        }
        if (iceCandidates.length > maxDeviceCanvasIceCandidates ||
            iceCandidates.any((candidate) => !candidate.isValid)) {
          throw const FormatException("invalid Device Canvas ICE candidates");
        }
      case DeviceCanvasStreamStartFailedMessage(:final requestId, :final leaseId, :final reason):
        _validateStreamCorrelation(requestId: requestId, leaseId: leaseId);
        if (reason == DeviceCanvasStreamStartFailureReason.unknown) {
          throw const FormatException("unknown Device Canvas stream start failure reason");
        }
      case DeviceCanvasStreamClosedMessage(:final leaseId, :final reason):
        if (!_isBoundedString(leaseId, maxDeviceCanvasStreamLeaseIdLength)) {
          throw const FormatException("invalid leaseId");
        }
        if (reason == DeviceCanvasStreamCloseReason.unknown) {
          throw const FormatException("unknown Device Canvas stream close reason");
        }
    }
  }

  void _validateStreamCorrelation({required String requestId, required String leaseId}) {
    if (!_isBoundedString(requestId, maxDeviceCanvasStreamRequestIdLength)) {
      throw const FormatException("invalid requestId");
    }
    if (!_isBoundedString(leaseId, maxDeviceCanvasStreamLeaseIdLength)) {
      throw const FormatException("invalid leaseId");
    }
  }

  bool _isBoundedString(String value, int maxLength) => value.isNotEmpty && value.length <= maxLength;
}
