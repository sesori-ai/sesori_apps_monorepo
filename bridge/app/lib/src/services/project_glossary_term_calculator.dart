import "dart:math" show min;

import "package:path/path.dart" as p;

import "../repositories/models/project_glossary_source.dart";

/// Selects a small, deterministic set of likely spoken technical terms from
/// bounded project metadata and tracked path names.
class const ProjectGlossaryTermCalculator() {
  static const int maximumTerms = 50;

  static final RegExp _metadataTokenPattern = RegExp(
    "[A-Za-z][A-Za-z0-9]*(?:[.+#-][A-Za-z0-9]+)*",
  );
  static final RegExp _hexTokenPattern = RegExp(r"^[A-Fa-f0-9]{12,}$");
  static final RegExp _allCapsPattern = RegExp(r"^[A-Z]{2,}$");
  static final RegExp _hasUpperPattern = RegExp("[A-Z]");
  static final RegExp _hasLowerPattern = RegExp("[a-z]");
  static final RegExp _hasDigitPattern = RegExp("[0-9]");
  static final RegExp _hasLetterPattern = RegExp("[A-Za-z]");
  static final RegExp _startsWithLetterPattern = RegExp("^[A-Za-z]");

  static const Set<String> _stopWords = {
    "a",
    "about",
    "action",
    "actions",
    "active",
    "after",
    "agent",
    "all",
    "also",
    "an",
    "and",
    "any",
    "agents",
    "analytics",
    "android",
    "api",
    "app",
    "apps",
    "are",
    "as",
    "architecture",
    "asset",
    "assets",
    "assets.xcassets",
    "at",
    "auth",
    "authentication",
    "background",
    "backend",
    "base",
    "before",
    "bin",
    "bridge",
    "build",
    "builder",
    "by",
    "cache",
    "catalog",
    "cmakelists",
    "class",
    "client",
    "code",
    "command",
    "common",
    "connection",
    "component",
    "components",
    "config",
    "configuration",
    "const",
    "controller",
    "core",
    "create",
    "current",
    "data",
    "database",
    "debug",
    "default",
    "delete",
    "design",
    "desktop",
    "detail",
    "directory",
    "dev",
    "docs",
    "document",
    "documents",
    "error",
    "event",
    "events",
    "example",
    "examples",
    "extension",
    "factory",
    "fake",
    "feature",
    "features",
    "file",
    "foundation",
    "files",
    "final",
    "for",
    "from",
    "generated",
    "get",
    "git",
    "handler",
    "has",
    "helper",
    "home",
    "host",
    "http",
    "https",
    "if",
    "injection",
    "icon",
    "ios",
    "icons",
    "image",
    "implementation",
    "import",
    "info",
    "install",
    "in",
    "index",
    "input",
    "interface",
    "internal",
    "is",
    "json",
    "launch",
    "launcher",
    "lifecycle",
    "light",
    "lib",
    "linux",
    "license",
    "list",
    "lists",
    "local",
    "login",
    "macos",
    "main",
    "make",
    "managed",
    "management",
    "manager",
    "manifest",
    "metadata",
    "message",
    "messages",
    "mobile",
    "model",
    "models",
    "module",
    "monorepo",
    "new",
    "not",
    "of",
    "open",
    "on",
    "or",
    "output",
    "package",
    "packages",
    "page",
    "parser",
    "part",
    "path",
    "plan",
    "platform",
    "plugin",
    "plugins",
    "prefer",
    "product",
    "project",
    "projects",
    "push",
    "progress",
    "protocol",
    "provider",
    "public",
    "read",
    "readme",
    "register",
    "release",
    "repository",
    "request",
    "routing",
    "runner",
    "runner.xcodeproj",
    "relay",
    "response",
    "route",
    "runtime",
    "screen",
    "server",
    "service",
    "session",
    "sessions",
    "settings",
    "setup",
    "skill",
    "shared",
    "source",
    "src",
    "start",
    "startup",
    "state",
    "status",
    "storage",
    "store",
    "theme",
    "tracker",
    "support",
    "terminal",
    "test",
    "testing",
    "tests",
    "text",
    "that",
    "the",
    "this",
    "to",
    "token",
    "tool",
    "tools",
    "type",
    "update",
    "use",
    "used",
    "user",
    "utils",
    "value",
    "values",
    "version",
    "view",
    "voice",
    "when",
    "with",
    "web",
    "widget",
    "widgets",
    "will",
    "windows",
    "window",
    "workspace",
    "www",
  };

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
      for (final match in _metadataTokenPattern.allMatches(document)) {
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
    final trimmed = value.trim();
    if (trimmed.isEmpty) return;

    if (includeCompound && !trimmed.contains("_")) {
      _recordTerm(
        candidates: candidates,
        term: trimmed,
        origin: origin,
        isCompound: true,
        distinctTerms: distinctTerms,
      );
    }

    final separated = trimmed
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

    final minimumLength = _allCapsPattern.hasMatch(term) ? 2 : 3;
    if (term.length < minimumLength) return false;
    if (_hasDigitPattern.allMatches(term).length > 6) return false;
    return true;
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
