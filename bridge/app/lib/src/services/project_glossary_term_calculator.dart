import "dart:math" show min;

import "package:path/path.dart" as p;

import "../repositories/models/project_glossary_source.dart";

/// Selects a small, deterministic set of likely spoken technical terms from
/// bounded project metadata and tracked path names.
class const ProjectGlossaryTermCalculator() {
  static const int maximumTerms = 50;

  static final RegExp _metadataTokenPattern = RegExp(
    r"(?:[Cc]\+\+|[CFcf]#|[A-Za-z][A-Za-z0-9]*(?:[.+#-][A-Za-z0-9]+)*)",
  );
  static final RegExp _metadataSecretSpanPattern = RegExp(
    "[A-Za-z0-9][A-Za-z0-9_./+=#-]{15,}",
  );
  static final RegExp _credentialTripleDoubleAssignmentPattern = RegExp(
    r'''["']?(?:password|passwd|pwd|secret|api[_-]?key|token|credential|authorization)["']?\s*[:=]\s*'''
    r'''"""[\s\S]*?(?:"""|$)''',
    caseSensitive: false,
  );
  static final RegExp _credentialTripleSingleAssignmentPattern = RegExp(
    r"""["']?(?:password|passwd|pwd|secret|api[_-]?key|token|credential|authorization)["']?\s*[:=]\s*"""
    r"""'''[\s\S]*?(?:'''|$)""",
    caseSensitive: false,
  );
  static final RegExp _credentialAssignmentPattern = RegExp(
    r'''["']?(?:password|passwd|pwd|secret|api[_-]?key|token|credential|authorization)["']?\s*[:=]\s*'''
    r'''(?:["'][^"'\r\n]*["']|[^\r\n,;}\]]+)''',
    caseSensitive: false,
  );
  static final RegExp _xmlOpeningElementPattern = RegExp(
    r'''<([A-Za-z_][A-Za-z0-9_.:-]*)(?:\s[^<>]*?)?\s*(/?)>''',
  );
  static final RegExp _yamlBlockHeaderPattern = RegExp(
    r'''^([ \t]*)(-[ \t]+)?["']?([A-Za-z_][A-Za-z0-9_.:-]*)["']?\s*:\s*[|>][1-9+-]*\s*(?:#.*)?\r?$''',
  );
  static final RegExp _xmlNameAcronymBoundaryPattern = RegExp("([A-Z]+)([A-Z][a-z])");
  static final RegExp _xmlNameCamelBoundaryPattern = RegExp("([a-z0-9])([A-Z])");
  static final RegExp _xmlNameSeparatorPattern = RegExp(r"[.:\-_]+");
  static final RegExp _authorizationCredentialPattern = RegExp(
    r'''["']?authorization["']?\s*[:=]\s*(?:["'][^"'\r\n]*["']|[^\r\n,;}\]]+)''',
    caseSensitive: false,
  );
  static final RegExp _bearerCredentialPattern = RegExp(
    r'''bearer\s+[A-Za-z0-9_./+=#-]{8,}["']?''',
    caseSensitive: false,
  );
  static final RegExp _credentialPrefixedSpanPattern = RegExp(
    "(?:AIza|AKIA|ASIA|gh[oprsu]|github[_-]?pat|rk[_-]?live|sk[_-]?(?:ant|live|proj)|xox[a-z])"
    "[_-]?[A-Za-z0-9_./+=#-]{8,}",
    caseSensitive: false,
  );
  static final RegExp _credentialLabeledSpanPattern = RegExp(
    "(?:password|passwd|pwd|secret|api[_-]?key|token|credential|authorization)[_-]+"
    "[A-Za-z0-9_./+=#-]{8,}",
    caseSensitive: false,
  );
  static final RegExp _hexTokenPattern = RegExp(r"^[A-Fa-f0-9]{12,}$");
  static final RegExp _allCapsPattern = RegExp(r"^[A-Z]{2,}$");
  static final RegExp _hasUpperPattern = RegExp("[A-Z]");
  static final RegExp _hasLowerPattern = RegExp("[a-z]");
  static final RegExp _hasDigitPattern = RegExp("[0-9]");
  static final RegExp _hasLetterPattern = RegExp("[A-Za-z]");
  static final RegExp _startsWithLetterPattern = RegExp("^[A-Za-z]");
  static final RegExp _credentialNonAlphaNumericPattern = RegExp("[^A-Za-z0-9]");
  static final RegExp _credentialDelimiterPattern = RegExp("[/=_+.]");

  static const Set<String> _shortSymbolicTerms = {"c#", "f#"};
  static const Set<String> _credentialNameComponents = {
    "apikey",
    "authorization",
    "credential",
    "passwd",
    "password",
    "pwd",
    "secret",
    "token",
  };

  static const Set<String> _credentialPrefixes = {
    "aiza",
    "akia",
    "asia",
    "gho",
    "ghp",
    "ghr",
    "ghs",
    "ghu",
    "githubpat",
    "rklive",
    "skant",
    "sklive",
    "skproj",
    "xoxa",
    "xoxb",
    "xoxp",
    "xoxr",
    "xoxs",
  };

  static const String _stopWordsText = """
a about action actions active after agent all also an and any agents analytics android api app apps are as
architecture asset assets assets.xcassets at auth authentication background backend base before bin bridge
build builder by cache catalog cmakelists class client code command common connection component components
config configuration const controller core create current data database debug default delete design desktop
detail directory dev docs document documents error event events example examples extension factory fake
feature features file foundation files final for from generated get git handler has helper home host http
https if injection icon ios icons image implementation import info install in index input interface internal
is json launch launcher lifecycle light lib linux license list lists local login macos main make managed
management manager manifest metadata message messages mobile model models module monorepo new not of open on
or output package packages page parser part path plan platform plugin plugins prefer product project
projects push progress protocol provider public read readme register release repository request routing
runner runner.xcodeproj relay response route runtime screen server service session sessions settings setup
skill shared source src start startup state status storage store theme tracker support terminal test testing
tests text that the this to token tool tools type update use used user utils value values version view voice
when with web widget widgets will windows window workspace www
""";
  static final Set<String> _stopWords = Set.unmodifiable(
    _stopWordsText.trim().split(RegExp(r"\s+")),
  );

  List<String> calculate({required ProjectGlossarySource source}) {
    final candidates = <String, _GlossaryCandidate>{};

    _recordIdentifier(
      candidates: candidates,
      value: source.projectName,
      origin: _GlossaryTermOrigin.project,
      includeCompound: true,
    );
    if (source.repositoryName case final repositoryName?) {
      _recordIdentifier(
        candidates: candidates,
        value: repositoryName,
        origin: _GlossaryTermOrigin.project,
        includeCompound: true,
      );
    }

    for (final relativePath in source.trackedPaths) {
      final pathTerms = <String>{};
      final segments = p.split(relativePath);
      for (var index = 0; index < segments.length; index++) {
        var segment = segments[index];
        if (index == segments.length - 1) {
          segment = p.basenameWithoutExtension(segment);
        }
        _recordIdentifier(
          candidates: candidates,
          value: segment,
          origin: _GlossaryTermOrigin.path,
          includeCompound: _hasTechnicalSignal(segment),
          distinctTerms: pathTerms,
        );
      }
    }

    for (final document in source.metadataDocuments) {
      final documentTerms = <String>{};
      final filteredDocument = _filterCredentialSpans(document);
      for (final match in _metadataTokenPattern.allMatches(filteredDocument)) {
        _recordTerm(
          candidates: candidates,
          term: match.group(0)!,
          origin: _GlossaryTermOrigin.metadata,
          isCompound: false,
          distinctTerms: documentTerms,
        );
      }
    }

    final ranked = candidates.values.where((candidate) => candidate.score >= 4).toList()
      ..sort((left, right) {
        final scoreOrder = right.score.compareTo(left.score);
        if (scoreOrder != 0) return scoreOrder;
        final foldedOrder = left.canonical.toLowerCase().compareTo(right.canonical.toLowerCase());
        if (foldedOrder != 0) return foldedOrder;
        return left.canonical.compareTo(right.canonical);
      });

    return ranked.take(maximumTerms).map((candidate) => candidate.canonical).toList(growable: false);
  }

  void _recordIdentifier({
    required Map<String, _GlossaryCandidate> candidates,
    required String value,
    required _GlossaryTermOrigin origin,
    required bool includeCompound,
    Set<String>? distinctTerms,
  }) {
    final filtered = _filterCredentialSpans(value).trim();
    if (filtered.isEmpty) return;

    if (includeCompound && !filtered.contains("_") && !filtered.contains(RegExp(r"\s"))) {
      _recordTerm(
        candidates: candidates,
        term: filtered,
        origin: origin,
        isCompound: true,
        distinctTerms: distinctTerms,
      );
    }

    final separated = filtered
        .replaceAllMapped(
          RegExp("([A-Z]+)([A-Z][a-z])"),
          (match) => "${match.group(1)} ${match.group(2)}",
        )
        .replaceAllMapped(
          RegExp("([a-z0-9])([A-Z])"),
          (match) => "${match.group(1)} ${match.group(2)}",
        )
        .replaceAll(RegExp(r"[-_\s.]+"), " ");

    for (final match in _metadataTokenPattern.allMatches(separated)) {
      _recordTerm(
        candidates: candidates,
        term: match.group(0)!,
        origin: origin,
        isCompound: false,
        distinctTerms: distinctTerms,
      );
    }
  }

  String _filterXmlCredentialElements(String value) {
    final filtered = StringBuffer();
    var cursor = 0;
    for (final opening in _xmlOpeningElementPattern.allMatches(value)) {
      if (opening.start < cursor) continue;
      final name = opening.group(1)!;
      if (!_isCredentialName(name)) continue;

      filtered.write(value.substring(cursor, opening.start));
      if (opening.group(2) == "/") {
        cursor = opening.end;
        continue;
      }

      final closing = RegExp(
        "</${RegExp.escape(name)}\\s*>",
        caseSensitive: false,
      ).firstMatch(value.substring(opening.end));
      cursor = closing == null ? value.length : opening.end + closing.end;
    }
    if (cursor == 0) return value;
    filtered.write(value.substring(cursor));
    return filtered.toString();
  }

  String _filterYamlCredentialBlocks(String value) {
    final filtered = <String>[];
    final lines = value.split("\n");
    var index = 0;
    while (index < lines.length) {
      final header = _yamlBlockHeaderPattern.firstMatch(lines[index]);
      if (header == null || !_isCredentialName(header.group(3)!)) {
        filtered.add(lines[index]);
        index++;
        continue;
      }

      final headerIndent = header.group(1)!.length + (header.group(2)?.length ?? 0);
      filtered.add("");
      index++;
      while (index < lines.length) {
        final line = lines[index];
        if (line.trim().isEmpty) {
          filtered.add("");
          index++;
          continue;
        }
        final contentIndent = line.length - line.trimLeft().length;
        if (contentIndent <= headerIndent) break;
        filtered.add("");
        index++;
      }
    }
    return filtered.join("\n");
  }

  bool _isCredentialName(String name) {
    final components = name
        .replaceAllMapped(
          _xmlNameAcronymBoundaryPattern,
          (match) => "${match.group(1)}.${match.group(2)}",
        )
        .replaceAllMapped(
          _xmlNameCamelBoundaryPattern,
          (match) => "${match.group(1)}.${match.group(2)}",
        )
        .toLowerCase()
        .split(_xmlNameSeparatorPattern);
    for (var index = 0; index < components.length; index++) {
      if (_credentialNameComponents.contains(components[index])) return true;
      final isApiKey =
          components[index] == "api" && index + 1 < components.length && components[index + 1] == "key";
      if (isApiKey) return true;
    }
    return false;
  }

  String _filterCredentialSpans(String value) {
    final structured = _filterYamlCredentialBlocks(
      _filterXmlCredentialElements(value),
    );
    return structured
        .replaceAll(_authorizationCredentialPattern, " ")
        .replaceAll(_credentialTripleDoubleAssignmentPattern, " ")
        .replaceAll(_credentialTripleSingleAssignmentPattern, " ")
        .replaceAll(_credentialAssignmentPattern, " ")
        .replaceAll(_bearerCredentialPattern, " ")
        .replaceAll(_credentialLabeledSpanPattern, " ")
        .replaceAll(_credentialPrefixedSpanPattern, " ")
        .replaceAllMapped(
          _metadataSecretSpanPattern,
          (match) => _looksCredentialShaped(match.group(0)!) ? " " : match.group(0)!,
        );
  }

  void _recordTerm({
    required Map<String, _GlossaryCandidate> candidates,
    required String term,
    required _GlossaryTermOrigin origin,
    required bool isCompound,
    Set<String>? distinctTerms,
  }) {
    final normalized = term.trim().replaceAll(RegExp(r"^[.-]+|[.-]+$"), "");
    if (!_isEligible(normalized)) return;

    final key = normalized.toLowerCase();
    if (distinctTerms != null && !distinctTerms.add(key)) return;

    final candidate = candidates.putIfAbsent(
      key,
      () => _GlossaryCandidate(canonical: normalized, canonicalPriority: origin.priority),
    );
    candidate.record(term: normalized, origin: origin, isCompound: isCompound);
  }

  bool _isEligible(String term) {
    if (term.length > 40 || !_hasLetterPattern.hasMatch(term) || !_startsWithLetterPattern.hasMatch(term)) {
      return false;
    }
    final folded = term.toLowerCase();
    if (_stopWords.contains(folded)) return false;
    if (_hexTokenPattern.hasMatch(term)) return false;
    if (_looksCredentialShaped(term)) return false;

    final minimumLength = _allCapsPattern.hasMatch(term) ? 2 : 3;
    if (term.length < minimumLength && !_shortSymbolicTerms.contains(folded)) return false;
    if (_hasDigitPattern.allMatches(term).length > 6) return false;
    return true;
  }

  static bool _looksCredentialShaped(String value) {
    final compact = value.replaceAll(_credentialNonAlphaNumericPattern, "");
    final folded = compact.toLowerCase();
    if (compact.length >= 16 && _credentialPrefixes.any(folded.startsWith)) return true;
    if (compact.length < 20 || !_hasLetterPattern.hasMatch(compact)) return false;

    final upperCount = _hasUpperPattern.allMatches(compact).length;
    final lowerCount = _hasLowerPattern.allMatches(compact).length;
    final digitCount = _hasDigitPattern.allMatches(compact).length;
    final distinctCharacters = compact.codeUnits.toSet().length;
    if (distinctCharacters < 10) return false;

    return (_credentialDelimiterPattern.hasMatch(value) && upperCount >= 6 && lowerCount >= 6 && digitCount >= 1) ||
        (digitCount == 0 && upperCount >= 6 && lowerCount >= 6 && distinctCharacters >= 12) ||
        (upperCount >= 6 && lowerCount >= 6 && digitCount >= 3) ||
        (upperCount == 0 && lowerCount >= 12 && digitCount >= 6) ||
        (lowerCount == 0 && upperCount >= 12 && digitCount >= 2);
  }

  static bool _hasTechnicalSignal(String value) {
    final hasMixedCase = _hasUpperPattern.hasMatch(value) && _hasLowerPattern.hasMatch(value);
    return hasMixedCase ||
        _allCapsPattern.hasMatch(value) ||
        _hasDigitPattern.hasMatch(value) ||
        value.contains("+") ||
        value.contains("#");
  }
}

enum _GlossaryTermOrigin(final int priority) {
  project(3),
  metadata(2),
  path(1),
}

final class _GlossaryCandidate({
  required var String canonical,
  required var int canonicalPriority,
}) {
  bool fromProjectName = false;
  int pathOccurrences = 0;
  int metadataOccurrences = 0;
  bool hasTechnicalSignal = false;
  bool isCompound = false;

  int get score =>
      (fromProjectName ? 100 : 0) +
      min(pathOccurrences, 10) * 4 +
      min(metadataOccurrences, 5) * 3 +
      (hasTechnicalSignal ? 8 : 0) +
      (isCompound ? 2 : 0);

  void record({required String term, required _GlossaryTermOrigin origin, required bool isCompound}) {
    switch (origin) {
      case _GlossaryTermOrigin.project:
        fromProjectName = true;
      case _GlossaryTermOrigin.metadata:
        metadataOccurrences++;
      case _GlossaryTermOrigin.path:
        pathOccurrences++;
    }

    hasTechnicalSignal = hasTechnicalSignal || ProjectGlossaryTermCalculator._hasTechnicalSignal(term);
    this.isCompound = this.isCompound || isCompound;

    final termPriority = origin.priority;
    if (termPriority > canonicalPriority ||
        (termPriority == canonicalPriority &&
            ProjectGlossaryTermCalculator._hasTechnicalSignal(term) &&
            !ProjectGlossaryTermCalculator._hasTechnicalSignal(canonical))) {
      canonical = term;
      canonicalPriority = termPriority;
    }
  }
}
