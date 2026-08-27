import "dart:convert";

import "package:freezed_annotation/freezed_annotation.dart";

part "device_canvas_client.freezed.dart";
part "device_canvas_client.g.dart";

const int maxDeviceCanvasClientIdentifierLength = 2048;
const int maxDeviceCanvasClientDeviceKeyLength = 512;
const int maxDeviceCanvasStreamOperationIdLength = 128;
const int maxDeviceCanvasStreamLeaseIdLength = 128;
const int maxDeviceCanvasRtcSdpBytes = 262144;
const int maxDeviceCanvasRtcFingerprintLength = 256;
const int maxDeviceCanvasIceCandidates = 64;
const int maxDeviceCanvasIceCandidateLength = 2048;
const int maxDeviceCanvasIceCandidateSdpMidLength = 128;
const int maxDeviceCanvasTurnUrls = 8;
const int maxDeviceCanvasTurnUrlLength = 2048;
const int maxDeviceCanvasTurnUsernameByteCount = 508;
const int maxDeviceCanvasTurnCredentialLength = 512;

enum DeviceCanvasClientConnectionStatus() {
  @JsonValue("disconnected")
  disconnected,
  @JsonValue("connected")
  connected,
  @JsonValue("unknown")
  unknown,
}

enum DeviceCanvasClientPlatform() {
  @JsonValue("ios")
  ios,
  @JsonValue("android")
  android,
  @JsonValue("unknown")
  unknown,
}

enum DeviceCanvasClientOrientation() {
  @JsonValue("portrait")
  portrait,
  @JsonValue("landscape")
  landscape,
  @JsonValue("unknown")
  unknown,
}

enum DeviceCanvasMutationOutcome() {
  @JsonValue("claimed")
  claimed,
  @JsonValue("alreadyOwned")
  alreadyOwned,
  @JsonValue("reassigned")
  reassigned,
  @JsonValue("conflict")
  conflict,
  @JsonValue("deviceUnavailable")
  deviceUnavailable,
  @JsonValue("sessionUnavailable")
  sessionUnavailable,
  @JsonValue("released")
  released,
  @JsonValue("alreadyReleased")
  alreadyReleased,
  @JsonValue("unknown")
  unknown,
}

enum DeviceCanvasRtcDescriptionType() {
  @JsonValue("offer")
  offer,
  @JsonValue("answer")
  answer,
  @JsonValue("unknown")
  unknown,
}

enum DeviceCanvasStreamStartOutcome() {
  @JsonValue("started")
  started,
  @JsonValue("controllerConflict")
  controllerConflict,
  @JsonValue("unavailable")
  unavailable,
  @JsonValue("unauthorized")
  unauthorized,
  @JsonValue("unsupported")
  unsupported,
  @JsonValue("unknown")
  unknown,
}

enum DeviceCanvasStreamPrepareOutcome() {
  @JsonValue("prepared")
  prepared,
  @JsonValue("controllerConflict")
  controllerConflict,
  @JsonValue("unavailable")
  unavailable,
  @JsonValue("unauthorized")
  unauthorized,
  @JsonValue("unsupported")
  unsupported,
  @JsonValue("unknown")
  unknown,
}

enum DeviceCanvasStreamStatusOutcome() {
  @JsonValue("active")
  active,
  @JsonValue("inactive")
  inactive,
  @JsonValue("controllerConflict")
  controllerConflict,
  @JsonValue("unavailable")
  unavailable,
  @JsonValue("unauthorized")
  unauthorized,
  @JsonValue("unknown")
  unknown,
}

enum DeviceCanvasStreamStopOutcome() {
  @JsonValue("stopped")
  stopped,
  @JsonValue("alreadyStopped")
  alreadyStopped,
  @JsonValue("unauthorized")
  unauthorized,
  @JsonValue("unknown")
  unknown,
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasRtcDescription._() with _$DeviceCanvasRtcDescription {
  const factory({
    @JsonKey(unknownEnumValue: DeviceCanvasRtcDescriptionType.unknown)
    required DeviceCanvasRtcDescriptionType type,
    required String sdp,
    required String fingerprint,
  }) = _DeviceCanvasRtcDescription;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasRtcDescriptionFromJson(json);

  bool get isValid {
    if (type == DeviceCanvasRtcDescriptionType.unknown ||
        utf8.encode(sdp).length > maxDeviceCanvasRtcSdpBytes ||
        fingerprint.isEmpty ||
        fingerprint.length > maxDeviceCanvasRtcFingerprintLength ||
        !RegExp(r"^sha-256 (?:[0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}$").hasMatch(fingerprint)) {
      return false;
    }
    final fingerprintLines = sdp.split(RegExp(r"\r?\n")).where((line) => line.startsWith("a=fingerprint:"));
    return fingerprintLines.length == 1 && fingerprintLines.single == "a=fingerprint:$fingerprint";
  }
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasIceCandidate._() with _$DeviceCanvasIceCandidate {
  const factory({
    required String candidate,
    required String sdpMid,
    required int sdpMLineIndex,
  }) = _DeviceCanvasIceCandidate;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasIceCandidateFromJson(json);

  bool get isValid =>
      candidate.isNotEmpty &&
      candidate.length <= maxDeviceCanvasIceCandidateLength &&
      sdpMid.isNotEmpty &&
      sdpMid.length <= maxDeviceCanvasIceCandidateSdpMidLength &&
      sdpMLineIndex >= 0;
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasTurnCredentialsRequest._() with _$DeviceCanvasTurnCredentialsRequest {
  const factory({
    required String bridgeId,
    required String operationId,
    required int leaseExpiresAt,
  }) = _DeviceCanvasTurnCredentialsRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasTurnCredentialsRequestFromJson(json);
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasTurnConfiguration._() with _$DeviceCanvasTurnConfiguration {
  const factory({
    required List<String> urls,
    required String username,
    required String credential,
    required int expiresAt,
  }) = _DeviceCanvasTurnConfiguration;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasTurnConfigurationFromJson(json);

  List<String>? get canonicalUrls {
    if (urls.isEmpty || urls.length > maxDeviceCanvasTurnUrls) return null;
    final canonical = <String>[];
    for (final url in urls) {
      final normalized = canonicalizeDeviceCanvasTurnUrl(url);
      if (normalized == null || canonical.contains(normalized)) return null;
      canonical.add(normalized);
    }
    return List<String>.unmodifiable(canonical);
  }

  bool get isValid =>
      canonicalUrls != null &&
      username.isNotEmpty &&
      utf8.encode(username).length <= maxDeviceCanvasTurnUsernameByteCount &&
      credential.isNotEmpty &&
      credential.length <= maxDeviceCanvasTurnCredentialLength &&
      expiresAt > 0;
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasStreamPrepareRequest._() with _$DeviceCanvasStreamPrepareRequest {
  const factory({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    required int expectedClaimRevision,
    required String operationId,
    required String leaseId,
    required bool control,
  }) = _DeviceCanvasStreamPrepareRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasStreamPrepareRequestFromJson(json);

  bool get isValid =>
      _isValidDeviceCanvasStreamIdentity(
        expectedBridgeId: expectedBridgeId,
        sessionId: sessionId,
        deviceKey: deviceKey,
        expectedClaimRevision: expectedClaimRevision,
      ) &&
      _isValidDeviceCanvasStreamOperationId(operationId) &&
      _isValidDeviceCanvasStreamLeaseId(leaseId);
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasStreamPrepareResponse._() with _$DeviceCanvasStreamPrepareResponse {
  const factory({
    @JsonKey(unknownEnumValue: DeviceCanvasStreamPrepareOutcome.unknown)
    required DeviceCanvasStreamPrepareOutcome outcome,
    required String? leaseId,
    required int? expiresAt,
    required DeviceCanvasTurnConfiguration? turn,
  }) = _DeviceCanvasStreamPrepareResponse;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasStreamPrepareResponseFromJson(json);

  bool get isValid => switch (outcome) {
    DeviceCanvasStreamPrepareOutcome.prepared => _isValidDeviceCanvasStreamPreparePayload(
      leaseId: leaseId,
      expiresAt: expiresAt,
      turn: turn,
    ),
    DeviceCanvasStreamPrepareOutcome.controllerConflict ||
    DeviceCanvasStreamPrepareOutcome.unavailable ||
    DeviceCanvasStreamPrepareOutcome.unauthorized ||
    DeviceCanvasStreamPrepareOutcome.unsupported => leaseId == null && expiresAt == null && turn == null,
    DeviceCanvasStreamPrepareOutcome.unknown => false,
  };
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasStreamStartRequest._() with _$DeviceCanvasStreamStartRequest {
  const factory({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    required int expectedClaimRevision,
    required String operationId,
    required String? leaseId,
    required bool control,
    required DeviceCanvasRtcDescription offer,
    @Default(<DeviceCanvasIceCandidate>[]) List<DeviceCanvasIceCandidate> iceCandidates,
  }) = _DeviceCanvasStreamStartRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasStreamStartRequestFromJson(json);

  bool get isValid =>
      _isValidDeviceCanvasStreamIdentity(
        expectedBridgeId: expectedBridgeId,
        sessionId: sessionId,
        deviceKey: deviceKey,
        expectedClaimRevision: expectedClaimRevision,
      ) &&
      _isValidDeviceCanvasStreamOperationId(operationId) &&
      _isValidOptionalDeviceCanvasStreamLeaseId(leaseId) &&
      offer.type == DeviceCanvasRtcDescriptionType.offer &&
      offer.isValid &&
      iceCandidates.length <= maxDeviceCanvasIceCandidates &&
      iceCandidates.every((candidate) => candidate.isValid);
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasStreamStartResponse._() with _$DeviceCanvasStreamStartResponse {
  const factory({
    @JsonKey(unknownEnumValue: DeviceCanvasStreamStartOutcome.unknown)
    required DeviceCanvasStreamStartOutcome outcome,
    required String? leaseId,
    required int? expiresAt,
    required DeviceCanvasRtcDescription? answer,
    @Default(<DeviceCanvasIceCandidate>[]) List<DeviceCanvasIceCandidate> iceCandidates,
    required DeviceCanvasTurnConfiguration? turn,
  }) = _DeviceCanvasStreamStartResponse;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasStreamStartResponseFromJson(json);

  bool get isValid => switch (outcome) {
    DeviceCanvasStreamStartOutcome.started => _isValidDeviceCanvasStreamPayload(
      leaseId: leaseId,
      expiresAt: expiresAt,
      answer: answer,
      iceCandidates: iceCandidates,
      turn: turn,
    ),
    DeviceCanvasStreamStartOutcome.controllerConflict ||
    DeviceCanvasStreamStartOutcome.unavailable ||
    DeviceCanvasStreamStartOutcome.unauthorized ||
    DeviceCanvasStreamStartOutcome.unsupported => _hasNoDeviceCanvasStreamPayload(
      leaseId: leaseId,
      expiresAt: expiresAt,
      answer: answer,
      iceCandidates: iceCandidates,
      turn: turn,
      offerFingerprint: null,
    ),
    DeviceCanvasStreamStartOutcome.unknown => false,
  };
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasStreamStatusRequest._() with _$DeviceCanvasStreamStatusRequest {
  const factory({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    required int expectedClaimRevision,
    required String operationId,
  }) = _DeviceCanvasStreamStatusRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasStreamStatusRequestFromJson(json);

  bool get isValid =>
      _isValidDeviceCanvasStreamIdentity(
        expectedBridgeId: expectedBridgeId,
        sessionId: sessionId,
        deviceKey: deviceKey,
        expectedClaimRevision: expectedClaimRevision,
      ) &&
      _isValidDeviceCanvasStreamOperationId(operationId);
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasStreamStatusResponse._() with _$DeviceCanvasStreamStatusResponse {
  const factory({
    @JsonKey(unknownEnumValue: DeviceCanvasStreamStatusOutcome.unknown)
    required DeviceCanvasStreamStatusOutcome outcome,
    required String? leaseId,
    required int? expiresAt,
    required DeviceCanvasRtcDescription? answer,
    @Default(<DeviceCanvasIceCandidate>[]) List<DeviceCanvasIceCandidate> iceCandidates,
    required DeviceCanvasTurnConfiguration? turn,
    required String? offerFingerprint,
  }) = _DeviceCanvasStreamStatusResponse;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasStreamStatusResponseFromJson(json);

  bool get isValid => switch (outcome) {
    DeviceCanvasStreamStatusOutcome.active => _isValidDeviceCanvasStreamPayload(
      leaseId: leaseId,
      expiresAt: expiresAt,
      answer: answer,
      iceCandidates: iceCandidates,
      turn: turn,
    ) &&
        _isValidOptionalDeviceCanvasFingerprint(offerFingerprint),
    DeviceCanvasStreamStatusOutcome.inactive ||
    DeviceCanvasStreamStatusOutcome.controllerConflict ||
    DeviceCanvasStreamStatusOutcome.unavailable ||
    DeviceCanvasStreamStatusOutcome.unauthorized => _hasNoDeviceCanvasStreamPayload(
      leaseId: leaseId,
      expiresAt: expiresAt,
      answer: answer,
      iceCandidates: iceCandidates,
      turn: turn,
      offerFingerprint: offerFingerprint,
    ),
    DeviceCanvasStreamStatusOutcome.unknown => false,
  };
}

@Freezed(fromJson: true, toJson: true, toStringOverride: false)
sealed class const DeviceCanvasStreamStopRequest._() with _$DeviceCanvasStreamStopRequest {
  const factory({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    required int expectedClaimRevision,
    required String leaseId,
  }) = _DeviceCanvasStreamStopRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasStreamStopRequestFromJson(json);

  bool get isValid =>
      _isValidDeviceCanvasStreamIdentity(
        expectedBridgeId: expectedBridgeId,
        sessionId: sessionId,
        deviceKey: deviceKey,
        expectedClaimRevision: expectedClaimRevision,
      ) &&
      leaseId.isNotEmpty &&
      leaseId.length <= maxDeviceCanvasStreamLeaseIdLength;
}

@Freezed(fromJson: true, toJson: true)
sealed class const DeviceCanvasStreamStopResponse._() with _$DeviceCanvasStreamStopResponse {
  const factory({
    @JsonKey(unknownEnumValue: DeviceCanvasStreamStopOutcome.unknown) required DeviceCanvasStreamStopOutcome outcome,
  }) = _DeviceCanvasStreamStopResponse;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasStreamStopResponseFromJson(json);

  bool get isValid => outcome != DeviceCanvasStreamStopOutcome.unknown;
}

bool _isValidDeviceCanvasStreamIdentity({
  required String expectedBridgeId,
  required String sessionId,
  required String deviceKey,
  required int expectedClaimRevision,
}) =>
    expectedBridgeId.isNotEmpty &&
    expectedBridgeId.length <= maxDeviceCanvasClientIdentifierLength &&
    sessionId.isNotEmpty &&
    sessionId.length <= maxDeviceCanvasClientIdentifierLength &&
    deviceKey.isNotEmpty &&
    deviceKey.length <= maxDeviceCanvasClientDeviceKeyLength &&
    expectedClaimRevision > 0;

bool _isValidDeviceCanvasStreamPayload({
  required String? leaseId,
  required int? expiresAt,
  required DeviceCanvasRtcDescription? answer,
  required List<DeviceCanvasIceCandidate> iceCandidates,
  required DeviceCanvasTurnConfiguration? turn,
}) =>
    leaseId != null &&
    leaseId.isNotEmpty &&
    leaseId.length <= maxDeviceCanvasStreamLeaseIdLength &&
    expiresAt != null &&
    expiresAt > 0 &&
    answer != null &&
    answer.type == DeviceCanvasRtcDescriptionType.answer &&
    answer.isValid &&
    iceCandidates.length <= maxDeviceCanvasIceCandidates &&
    iceCandidates.every((candidate) => candidate.isValid) &&
    (turn?.isValid ?? true);

bool _hasNoDeviceCanvasStreamPayload({
  required String? leaseId,
  required int? expiresAt,
  required DeviceCanvasRtcDescription? answer,
  required List<DeviceCanvasIceCandidate> iceCandidates,
  required DeviceCanvasTurnConfiguration? turn,
  required String? offerFingerprint,
}) =>
    leaseId == null &&
    expiresAt == null &&
    answer == null &&
    iceCandidates.isEmpty &&
    turn == null &&
    offerFingerprint == null;

bool _isValidDeviceCanvasFingerprint(String fingerprint) =>
    fingerprint.isNotEmpty &&
    fingerprint.length <= maxDeviceCanvasRtcFingerprintLength &&
    RegExp(r"^sha-256 (?:[0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}$").hasMatch(fingerprint);

bool _isValidOptionalDeviceCanvasFingerprint(String? fingerprint) =>
    fingerprint == null || _isValidDeviceCanvasFingerprint(fingerprint);

bool _isValidDeviceCanvasStreamOperationId(String operationId) =>
    operationId.isNotEmpty &&
    operationId.length <= maxDeviceCanvasStreamOperationIdLength &&
    RegExp(r"^[A-Za-z0-9_-]+$").hasMatch(operationId);

bool _isValidDeviceCanvasStreamLeaseId(String leaseId) =>
    leaseId.isNotEmpty &&
    leaseId.length <= maxDeviceCanvasStreamLeaseIdLength &&
    RegExp(r"^[A-Za-z0-9_-]+$").hasMatch(leaseId);

bool _isValidOptionalDeviceCanvasStreamLeaseId(String? leaseId) =>
    leaseId == null || _isValidDeviceCanvasStreamLeaseId(leaseId);

bool _isValidDeviceCanvasStreamPreparePayload({
  required String? leaseId,
  required int? expiresAt,
  required DeviceCanvasTurnConfiguration? turn,
}) =>
    leaseId != null &&
    _isValidDeviceCanvasStreamLeaseId(leaseId) &&
    expiresAt != null &&
    expiresAt > 0 &&
    turn != null &&
    turn.isValid &&
    turn.expiresAt == expiresAt;

String? canonicalizeDeviceCanvasTurnUrl(String value) {
  if (value.isEmpty || value.length > maxDeviceCanvasTurnUrlLength || value.runes.any(_isWhitespaceOrControl)) {
    return null;
  }
  final schemeEnd = value.indexOf(":");
  if (schemeEnd <= 0) return null;
  final scheme = value.substring(0, schemeEnd).toLowerCase();
  if (scheme != "turn" && scheme != "turns") return null;

  final remainder = value.substring(schemeEnd + 1);
  final queryStart = remainder.indexOf("?");
  if (queryStart >= 0 && remainder.indexOf("?", queryStart + 1) >= 0) return null;
  final authority = queryStart < 0 ? remainder : remainder.substring(0, queryStart);
  if (authority.isEmpty || authority.contains("/") || authority.contains("@") || authority.contains("#")) {
    return null;
  }
  final defaultTransport = scheme == "turn" ? "udp" : "tcp";
  final String transport;
  if (queryStart < 0) {
    transport = defaultTransport;
  } else {
    final query = remainder.substring(queryStart + 1).toLowerCase();
    if (query != "transport=udp" && query != "transport=tcp") return null;
    transport = query.substring("transport=".length);
  }
  if (scheme == "turns" && transport != "tcp") return null;

  final normalizedAuthority = _canonicalizeDeviceCanvasTurnAuthority(authority);
  if (normalizedAuthority == null) return null;
  final port = normalizedAuthority.port ?? (scheme == "turn" ? 3478 : 5349);
  return "$scheme:${normalizedAuthority.host}:$port?transport=$transport";
}

({String host, int? port})? _canonicalizeDeviceCanvasTurnAuthority(String authority) {
  if (authority.startsWith("[")) {
    final closingBracket = authority.indexOf("]");
    if (closingBracket <= 1) return null;
    final host = _canonicalizeDeviceCanvasIpv6(authority.substring(1, closingBracket));
    if (host == null) return null;
    final suffix = authority.substring(closingBracket + 1);
    if (suffix.isEmpty) return (host: "[$host]", port: null);
    if (!suffix.startsWith(":")) return null;
    final port = _parseDeviceCanvasTurnPort(suffix.substring(1));
    return port == null ? null : (host: "[$host]", port: port);
  }
  if (authority.contains("[") || authority.contains("]")) return null;

  final portSeparator = authority.indexOf(":");
  final hostValue = portSeparator < 0 ? authority : authority.substring(0, portSeparator);
  final host = _canonicalizeDeviceCanvasTurnHost(hostValue);
  if (host == null) return null;
  if (portSeparator < 0) return (host: host, port: null);
  final port = _parseDeviceCanvasTurnPort(authority.substring(portSeparator + 1));
  return port == null ? null : (host: host, port: port);
}

String? _canonicalizeDeviceCanvasTurnHost(String value) {
  if (value.isEmpty || value.codeUnits.length > 253) return null;
  final ipv4 = _canonicalizeDeviceCanvasIpv4(value);
  if (ipv4 != null) return ipv4;
  if (_looksLikeAlternateNumericHost(value)) return null;

  final host = value.endsWith(".") ? value.substring(0, value.length - 1) : value;
  if (host.isEmpty) return null;
  final labels = host.split(".");
  for (final label in labels) {
    if (label.isEmpty || label.length > 63) return null;
    final units = label.codeUnits;
    if (!_isAsciiAlphaNumeric(units.first) || !_isAsciiAlphaNumeric(units.last)) return null;
    if (units.any((unit) => !_isAsciiAlphaNumeric(unit) && unit != 45)) return null;
  }
  return host.toLowerCase();
}

String? _canonicalizeDeviceCanvasIpv4(String value) {
  final segments = value.split(".");
  if (segments.length != 4) return null;
  final canonical = <String>[];
  for (final segment in segments) {
    if (segment.isEmpty || segment.codeUnits.any((unit) => unit < 48 || unit > 57)) return null;
    final parsed = int.tryParse(segment);
    if (parsed == null || parsed > 255 || "$parsed" != segment) return null;
    canonical.add("$parsed");
  }
  return canonical.join(".");
}

String? _canonicalizeDeviceCanvasIpv6(String value) {
  if (value.isEmpty || value.contains(".")) return null;
  final compression = value.indexOf("::");
  if (compression >= 0 && value.indexOf("::", compression + 2) >= 0) return null;
  final List<int> segments;
  if (compression < 0) {
    final parsed = _parseDeviceCanvasIpv6Segments(value);
    if (parsed == null || parsed.length != 8) return null;
    segments = parsed;
  } else {
    final left = _parseDeviceCanvasIpv6Segments(value.substring(0, compression), allowEmpty: true);
    final right = _parseDeviceCanvasIpv6Segments(value.substring(compression + 2), allowEmpty: true);
    if (left == null || right == null || left.length + right.length >= 8) return null;
    segments = <int>[...left, ...List<int>.filled(8 - left.length - right.length, 0), ...right];
  }
  if (_isDeviceCanvasIpv4EmbeddedIpv6(segments)) return null;

  var bestStart = -1;
  var bestLength = 0;
  for (var index = 0; index < segments.length;) {
    if (segments[index] != 0) {
      index += 1;
      continue;
    }
    final start = index;
    while (index < segments.length && segments[index] == 0) {
      index += 1;
    }
    final length = index - start;
    if (length >= 2 && length > bestLength) {
      bestStart = start;
      bestLength = length;
    }
  }
  if (bestStart < 0) return segments.map((segment) => segment.toRadixString(16)).join(":");

  final buffer = StringBuffer();
  var index = 0;
  while (index < segments.length) {
    if (index == bestStart) {
      buffer.write("::");
      index += bestLength;
      continue;
    }
    final rendered = buffer.toString();
    if (rendered.isNotEmpty && !rendered.endsWith(":")) buffer.write(":");
    buffer.write(segments[index].toRadixString(16));
    index += 1;
  }
  return buffer.toString();
}

List<int>? _parseDeviceCanvasIpv6Segments(String value, {bool allowEmpty = false}) {
  if (value.isEmpty) return allowEmpty ? <int>[] : null;
  final parsed = <int>[];
  for (final segment in value.split(":")) {
    if (segment.isEmpty || segment.length > 4 || !RegExp(r"^[0-9A-Fa-f]+$").hasMatch(segment)) return null;
    parsed.add(int.parse(segment, radix: 16));
  }
  return parsed;
}

bool _isDeviceCanvasIpv4EmbeddedIpv6(List<int> segments) {
  final special = segments.take(7).every((segment) => segment == 0) && segments.last <= 1;
  final compatible = segments.take(6).every((segment) => segment == 0) && !special;
  final mapped = segments.take(5).every((segment) => segment == 0) && segments[5] == 0xffff;
  final translatable =
      segments.take(4).every((segment) => segment == 0) && segments[4] == 0xffff && segments[5] == 0;
  return compatible || mapped || translatable;
}

bool _looksLikeAlternateNumericHost(String value) {
  if (RegExp(r"^[0-9.]+$").hasMatch(value)) return true;
  final labels = value.split(".");
  return labels.isNotEmpty &&
      labels.every(
        (label) => RegExp(r"^[0-9]+$").hasMatch(label) || RegExp(r"^0[xX][0-9A-Fa-f]+$").hasMatch(label),
      );
}

int? _parseDeviceCanvasTurnPort(String value) {
  if (value.isEmpty || value.codeUnits.any((unit) => unit < 48 || unit > 57)) return null;
  final port = int.tryParse(value);
  return port != null && port >= 1 && port <= 65535 ? port : null;
}

bool _isAsciiAlphaNumeric(int unit) =>
    (unit >= 48 && unit <= 57) || (unit >= 65 && unit <= 90) || (unit >= 97 && unit <= 122);

bool _isWhitespaceOrControl(int rune) =>
    rune <= 0x20 ||
    (rune >= 0x7f && rune <= 0xa0) ||
    rune == 0x1680 ||
    (rune >= 0x2000 && rune <= 0x200a) ||
    rune == 0x2028 ||
    rune == 0x2029 ||
    rune == 0x202f ||
    rune == 0x205f ||
    rune == 0x3000;

@Freezed(fromJson: true, toJson: true)
sealed class const DeviceCanvasSessionStatusRequest._() with _$DeviceCanvasSessionStatusRequest {
  const factory({required String sessionId}) = _DeviceCanvasSessionStatusRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasSessionStatusRequestFromJson(json);

  bool get isValid => sessionId.isNotEmpty && sessionId.length <= maxDeviceCanvasClientIdentifierLength;
}

@Freezed(fromJson: true, toJson: true)
sealed class const DeviceCanvasClaimRequest._() with _$DeviceCanvasClaimRequest {
  const factory({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    @Default(false) bool reassign,
    required String? expectedOwnerSessionId,
    required int? expectedClaimRevision,
  }) = _DeviceCanvasClaimRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasClaimRequestFromJson(json);

  bool get isValid {
    if (expectedBridgeId.isEmpty ||
        expectedBridgeId.length > maxDeviceCanvasClientIdentifierLength ||
        sessionId.isEmpty ||
        sessionId.length > maxDeviceCanvasClientIdentifierLength ||
        deviceKey.isEmpty ||
        deviceKey.length > maxDeviceCanvasClientDeviceKeyLength) {
      return false;
    }
    if (!reassign) return expectedOwnerSessionId == null && expectedClaimRevision == null;
    final ownerSessionId = expectedOwnerSessionId;
    final claimRevision = expectedClaimRevision;
    return ownerSessionId != null &&
        ownerSessionId.isNotEmpty &&
        ownerSessionId != sessionId &&
        ownerSessionId.length <= maxDeviceCanvasClientIdentifierLength &&
        claimRevision != null &&
        claimRevision > 0;
  }
}

@Freezed(fromJson: true, toJson: true)
sealed class const DeviceCanvasReleaseRequest._() with _$DeviceCanvasReleaseRequest {
  const factory({
    required String expectedBridgeId,
    required String sessionId,
    required String deviceKey,
    required int expectedClaimRevision,
  }) = _DeviceCanvasReleaseRequest;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasReleaseRequestFromJson(json);

  bool get isValid =>
      expectedBridgeId.isNotEmpty &&
      expectedBridgeId.length <= maxDeviceCanvasClientIdentifierLength &&
      sessionId.isNotEmpty &&
      sessionId.length <= maxDeviceCanvasClientIdentifierLength &&
      deviceKey.isNotEmpty &&
      deviceKey.length <= maxDeviceCanvasClientDeviceKeyLength &&
      expectedClaimRevision > 0;
}

@Freezed(fromJson: true, toJson: true)
sealed class DeviceCanvasClientCapabilities with _$DeviceCanvasClientCapabilities {
  const factory({
    @Default(false) bool localView,
    @Default(false) bool remoteVideo,
    @Default(false) bool remoteControl,
    @Default(false) bool input,
  }) = _DeviceCanvasClientCapabilities;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasClientCapabilitiesFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class DeviceCanvasClientDimensions with _$DeviceCanvasClientDimensions {
  const factory({required int width, required int height}) = _DeviceCanvasClientDimensions;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasClientDimensionsFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class DeviceCanvasClientDescriptor with _$DeviceCanvasClientDescriptor {
  const factory({
    @JsonKey(unknownEnumValue: DeviceCanvasClientPlatform.unknown) required DeviceCanvasClientPlatform platform,
    required String displayName,
    required String runtimeDescription,
    required String modelDescription,
    required DeviceCanvasClientDimensions? dimensions,
    @JsonKey(unknownEnumValue: DeviceCanvasClientOrientation.unknown)
    required DeviceCanvasClientOrientation? orientation,
    required DeviceCanvasClientCapabilities capabilities,
  }) = _DeviceCanvasClientDescriptor;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasClientDescriptorFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class DeviceCanvasClaimStatus with _$DeviceCanvasClaimStatus {
  const factory({
    required String projectId,
    required String sessionId,
    required int revision,
    required int claimedAt,
    required String? displayTitle,
  }) = _DeviceCanvasClaimStatus;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasClaimStatusFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class DeviceCanvasDeviceStatus with _$DeviceCanvasDeviceStatus {
  const factory({
    required String deviceKey,
    required DeviceCanvasClientDescriptor? descriptor,
    required DeviceCanvasClaimStatus? claim,
  }) = _DeviceCanvasDeviceStatus;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasDeviceStatusFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class DeviceCanvasSessionStatusResponse with _$DeviceCanvasSessionStatusResponse {
  const factory({
    required String bridgeId,
    required String sessionId,
    required bool sessionAvailable,
    required String? projectId,
    @JsonKey(unknownEnumValue: DeviceCanvasClientConnectionStatus.unknown)
    @Default(DeviceCanvasClientConnectionStatus.unknown)
    DeviceCanvasClientConnectionStatus connection,
    @Default(<DeviceCanvasDeviceStatus>[]) List<DeviceCanvasDeviceStatus> devices,
    @Default(false) bool inventoryTruncated,
    @Default(false) bool supportsReassignment,
  }) = _DeviceCanvasSessionStatusResponse;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasSessionStatusResponseFromJson(json);
}

@Freezed(fromJson: true, toJson: true)
sealed class DeviceCanvasMutationResponse with _$DeviceCanvasMutationResponse {
  const factory({
    @JsonKey(unknownEnumValue: DeviceCanvasMutationOutcome.unknown) required DeviceCanvasMutationOutcome outcome,
    required DeviceCanvasSessionStatusResponse status,
  }) = _DeviceCanvasMutationResponse;

  factory fromJson(Map<String, dynamic> json) => _$DeviceCanvasMutationResponseFromJson(json);
}
