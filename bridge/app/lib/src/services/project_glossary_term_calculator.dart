import "dart:math" show min;

import "package:path/path.dart" as p;

import "../repositories/models/project_glossary_source.dart";
import "project_glossary_english_words.dart";

/// Selects a small, deterministic set of likely spoken technical terms from
/// bounded project metadata and tracked path names.
class const ProjectGlossaryTermCalculator() {
  // Whole ASCII words only, so "Español" leaves no "Espa" fragment.
  static final RegExp _metadataTokenPattern = RegExp(
    r"(?<![\p{L}\p{N}])(?:[Cc]\+\+|[CFcf]#|[A-Za-z][A-Za-z0-9]*(?![\p{L}\p{N}]))",
    unicode: true,
  );
  static final RegExp _identifierPattern = RegExp(r"^[A-Za-z][A-Za-z0-9]*$");
  static final RegExp _metadataSecretSpanPattern = RegExp(
    "[A-Za-z0-9][A-Za-z0-9_./+=#-]{15,}",
  );
  static final RegExp _credentialTripleDoubleAssignmentPattern = RegExp(
    r'''["']?([A-Za-z_][A-Za-z0-9_.:-]*)["']?\s*[:=]\s*"""[\s\S]*?(?:"""|$)''',
  );
  static final RegExp _credentialTripleSingleAssignmentPattern = RegExp(
    r"""["']?([A-Za-z_][A-Za-z0-9_.:-]*)["']?\s*[:=]\s*'''[\s\S]*?(?:'''|$)""",
  );
  static final RegExp _credentialAssignmentPattern = RegExp(
    r'''["']?([A-Za-z_][A-Za-z0-9_.:-]*)["']?\s*[:=]\s*'''
    r'''(?:"(?:\\.|[^"\\\r\n])*"|'(?:\\.|[^'\\\r\n])*'|[^\r\n,;}\]]+)''',
  );
  static final RegExp _credentialOptionPattern = RegExp(
    r'''--([A-Za-z][A-Za-z0-9_-]*)[ \t]+'''
    r'''(?:"(?:\\.|[^"\\\r\n])*"|'(?:\\.|[^'\\\r\n])*'|[^\s,;]+)''',
  );
  static final RegExp _xmlOpeningElementPattern = RegExp(
    r'''<([A-Za-z_][A-Za-z0-9_.:-]*)(?:\s[^<>]*?)?\s*(/?)>''',
  );
  static final RegExp _yamlCredentialHeaderPattern = RegExp(
    r'''^([ \t]*)(-[ \t]+)?["']?([A-Za-z_][A-Za-z0-9_.:-]*)["']?\s*:\s*.*\r?$''',
  );
  static final RegExp _xmlNameAcronymBoundaryPattern = RegExp("([A-Z]+)([A-Z][a-z])");
  static final RegExp _xmlNameCamelBoundaryPattern = RegExp("([a-z0-9])([A-Z])");
  static final RegExp _xmlNameSeparatorPattern = RegExp(r"[.:\-_]+");
  static final RegExp _uriUserInfoPattern = RegExp(
    r'''[A-Za-z][A-Za-z0-9+.-]*://[^\s/:@"'<>]+:[^\s/@"'<>]+@''',
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
  // Hash and color fragments such as "c4f042" or "ffcb47".
  static final RegExp _hexTokenPattern = RegExp(r"^(?:[A-Fa-f0-9]{12,}|(?=.*[0-9])[A-Fa-f0-9]{5,})$");
  // File numbering or icon sizes such as "p01" or "Square30x30Logo".
  static final RegExp _serialTokenPattern = RegExp(r"^[A-Za-z][0-9]{2,}$|[0-9]x[0-9]");
  static final RegExp _allCapsPattern = RegExp(r"^[A-Z]{2,}$");
  static final RegExp _hasUpperPattern = RegExp("[A-Z]");
  static final RegExp _hasLowerPattern = RegExp("[a-z]");
  static final RegExp _hasDigitPattern = RegExp("[0-9]");
  static final RegExp _hasLetterPattern = RegExp("[A-Za-z]");
  static final RegExp _credentialNonAlphaNumericPattern = RegExp("[^A-Za-z0-9]");
  static final RegExp _credentialDelimiterPattern = RegExp("[/=_+.]");

  static const Set<String> _shortSymbolicTerms = {"c#", "f#"};
  static const Set<String> _credentialNameComponents = {
    "apikey",
    "authorization",
    "pass",
    "credential",
    "passwd",
    "password",
    "passphrase",
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

  // Generic software and scaffolding vocabulary that the English word list does not cover.
  static const String _stopWordsText = """
androidmanifest api app appdelegate appfile appinfo async auth backend bmp changelog cli cmakelists cmd com
config const css debugprofile dev devdependencies dir dockerfile dockerignore drawable env etc fastfile favicon
gemfile generatedpluginregistrant gif git gitattributes gitignore gitkeep gradle hdpi html http ide
ideworkspacechecks impl imageset init ios jpeg jpg json lifecycle linux login macos makefile mdpi metadata mipmap
monorepo multi non npmrc org param parser plugin png podfile pre prettierignore prettierrc pubspec readme repo res
runnertests runtime sdk src startup svg toml tsconfig txt uri url util webp widget workflow workspace www xcassets
xcodeproj xcshareddata xcworkspace xhdpi xml xxhdpi xxxhdpi yaml yml
""";
  static final Set<String> _stopWords = Set.unmodifiable(
    _stopWordsText.trim().split(RegExp(r"\s+")),
  );
  static final Set<String> _englishWords = Set.unmodifiable(
    projectGlossaryEnglishWordsText.trim().split(RegExp(r"\s+")),
  );
  static const List<(String, String)> _inflectionSuffixes = [
    ("ies", "y"),
    ("ied", "y"),
    ("es", ""),
    ("s", ""),
    ("ed", ""),
    ("ed", "e"),
    ("ing", ""),
    ("ing", "e"),
  ];

  List<String> calculate({required ProjectGlossarySource source, required int maximumTerms}) {
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

    final rankedKeys = {for (final candidate in ranked) candidate.canonical.toLowerCase()};
    return ranked
        .map((candidate) => candidate.canonical)
        // A plural adds nothing beside its ranked singular, such as "schemas" beside "schema".
        .where((term) {
          final key = term.toLowerCase();
          return !key.endsWith("s") || !rankedKeys.contains(key.substring(0, key.length - 1));
        })
        .take(maximumTerms)
        .toList(growable: false);
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

    // Only a single identifier such as "GoRouter" stays whole; "sesori-bridge-arm64" contributes its parts.
    if (includeCompound && _identifierPattern.hasMatch(filtered)) {
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
        );

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
      final header = _yamlCredentialHeaderPattern.firstMatch(lines[index]);
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

  String _filterCredentialAssignments(String value) {
    final tripleDouble = _redactCredentialAssignments(
      value: value,
      pattern: _credentialTripleDoubleAssignmentPattern,
    );
    final tripleSingle = _redactCredentialAssignments(
      value: tripleDouble,
      pattern: _credentialTripleSingleAssignmentPattern,
    );
    return _redactCredentialAssignments(
      value: tripleSingle,
      pattern: _credentialAssignmentPattern,
    );
  }

  String _redactCredentialAssignments({required String value, required RegExp pattern}) {
    return value.replaceAllMapped(
      pattern,
      (match) => _isCredentialName(match.group(1)!) ? " " : match.group(0)!,
    );
  }

  String _filterCredentialOptions(String value) {
    return value.replaceAllMapped(
      _credentialOptionPattern,
      (match) => _isCredentialName(match.group(1)!) ? " " : match.group(0)!,
    );
  }

  String _filterCredentialSpans(String value) {
    final structured = _filterYamlCredentialBlocks(
      _filterXmlCredentialElements(value),
    );
    final options = _filterCredentialOptions(
      _filterCredentialAssignments(structured),
    );
    return options
        .replaceAll(_uriUserInfoPattern, " ")
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
    if (!_isEligible(term)) return;

    final key = term.toLowerCase();
    if (distinctTerms != null && !distinctTerms.add(key)) return;

    final candidate = candidates.putIfAbsent(
      key,
      () => _GlossaryCandidate(canonical: term, canonicalPriority: origin.priority),
    );
    candidate.record(term: term, origin: origin, isCompound: isCompound);
  }

  bool _isEligible(String term) {
    if (term.length > 40) return false;
    final folded = term.toLowerCase();
    if (_isCommonWord(word: folded)) return false;
    if (_hexTokenPattern.hasMatch(term) || _serialTokenPattern.hasMatch(term)) return false;
    if (_looksCredentialShaped(term)) return false;

    if (term.length < 3 && !_shortSymbolicTerms.contains(folded)) return false;
    if (_hasDigitPattern.allMatches(term).length > 6) return false;
    return true;
  }

  // ponytail: suffix folding, not a stemmer; an irregular form passes unless it is listed itself.
  static bool _isCommonWord({required String word}) {
    if (_isListedWord(word: word)) return true;
    for (final (suffix, replacement) in _inflectionSuffixes) {
      if (!word.endsWith(suffix)) continue;
      final stem = word.substring(0, word.length - suffix.length);
      if (_isListedWord(word: "$stem$replacement")) return true;
      // Doubled final consonant: "stopped" -> "stop", "running" -> "run".
      final isDoubled = replacement.isEmpty && stem.length > 3 && stem[stem.length - 1] == stem[stem.length - 2];
      if (isDoubled && _isListedWord(word: stem.substring(0, stem.length - 1))) return true;
    }
    return false;
  }

  static bool _isListedWord({required String word}) => _stopWords.contains(word) || _englishWords.contains(word);

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
