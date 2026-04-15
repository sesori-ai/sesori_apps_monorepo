final class BridgeVersion implements Comparable<BridgeVersion> {
  final int major;
  final int minor;
  final int patch;
  final List<String> prereleaseIdentifiers;
  final List<String> buildMetadataIdentifiers;

  const BridgeVersion._({
    required this.major,
    required this.minor,
    required this.patch,
    required this.prereleaseIdentifiers,
    required this.buildMetadataIdentifiers,
  });

  factory BridgeVersion.parse({required String value}) {
    final String normalized = value.trim();
    if (normalized.isEmpty) {
      throw const FormatException('Version is empty.');
    }

    final List<String> buildSplit = normalized.split('+');
    if (buildSplit.length > 2) {
      throw FormatException('Invalid build metadata in version "$value".');
    }

    final String coreAndPrerelease = buildSplit.first;
    final List<String> buildMetadataIdentifiers = buildSplit.length == 2
        ? _parseIdentifiers(value: buildSplit[1], label: 'build metadata')
        : const [];

    final List<String> prereleaseSplit = coreAndPrerelease.split('-');
    if (prereleaseSplit.length > 2) {
      throw FormatException('Invalid prerelease segment in version "$value".');
    }

    final List<String> coreParts = prereleaseSplit.first.split('.');
    if (coreParts.length != 3) {
      throw FormatException('Version "$value" must use X.Y.Z core segments.');
    }

    final List<int> parsedCore = coreParts.map((part) => _parseCorePart(part: part, value: value)).toList();
    final List<String> prereleaseIdentifiers = prereleaseSplit.length == 2
        ? _parseIdentifiers(value: prereleaseSplit[1], label: 'prerelease')
        : const [];

    return BridgeVersion._(
      major: parsedCore[0],
      minor: parsedCore[1],
      patch: parsedCore[2],
      prereleaseIdentifiers: prereleaseIdentifiers,
      buildMetadataIdentifiers: buildMetadataIdentifiers,
    );
  }

  static BridgeVersion? tryParse({required String value}) {
    try {
      return BridgeVersion.parse(value: value);
    } on FormatException {
      return null;
    }
  }

  bool get isStable => prereleaseIdentifiers.isEmpty;

  @override
  int compareTo(BridgeVersion other) {
    final int majorComparison = major.compareTo(other.major);
    if (majorComparison != 0) {
      return majorComparison;
    }

    final int minorComparison = minor.compareTo(other.minor);
    if (minorComparison != 0) {
      return minorComparison;
    }

    final int patchComparison = patch.compareTo(other.patch);
    if (patchComparison != 0) {
      return patchComparison;
    }

    if (isStable && other.isStable) {
      return 0;
    }
    if (isStable) {
      return 1;
    }
    if (other.isStable) {
      return -1;
    }

    final int sharedLength = prereleaseIdentifiers.length < other.prereleaseIdentifiers.length
        ? prereleaseIdentifiers.length
        : other.prereleaseIdentifiers.length;
    for (var index = 0; index < sharedLength; index++) {
      final int identifierComparison = _compareIdentifier(
        left: prereleaseIdentifiers[index],
        right: other.prereleaseIdentifiers[index],
      );
      if (identifierComparison != 0) {
        return identifierComparison;
      }
    }

    return prereleaseIdentifiers.length.compareTo(other.prereleaseIdentifiers.length);
  }

  @override
  String toString() {
    final String core = '$major.$minor.$patch';
    final String prerelease = prereleaseIdentifiers.isEmpty ? '' : '-${prereleaseIdentifiers.join('.')}';
    final String build = buildMetadataIdentifiers.isEmpty ? '' : '+${buildMetadataIdentifiers.join('.')}';
    return '$core$prerelease$build';
  }

  static int _parseCorePart({required String part, required String value}) {
    if (part.isEmpty) {
      throw FormatException('Version "$value" contains an empty numeric segment.');
    }

    final int? parsed = int.tryParse(part);
    if (parsed == null || parsed < 0) {
      throw FormatException('Version "$value" contains invalid numeric segment "$part".');
    }

    return parsed;
  }

  static List<String> _parseIdentifiers({required String value, required String label}) {
    if (value.isEmpty) {
      throw FormatException('Version contains empty $label.');
    }

    final List<String> identifiers = value.split('.');
    if (identifiers.any((identifier) => identifier.isEmpty)) {
      throw FormatException('Version contains empty $label identifiers.');
    }

    return List<String>.unmodifiable(identifiers);
  }

  static int _compareIdentifier({required String left, required String right}) {
    final int? leftNumeric = int.tryParse(left);
    final int? rightNumeric = int.tryParse(right);

    if (leftNumeric != null && rightNumeric != null) {
      return leftNumeric.compareTo(rightNumeric);
    }
    if (leftNumeric != null) {
      return -1;
    }
    if (rightNumeric != null) {
      return 1;
    }
    return left.compareTo(right);
  }
}
