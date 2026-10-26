import "package:path/path.dart" as p;
import "package:sesori_bridge/src/api/database/tables/projects_table.dart";
import "package:sesori_bridge/src/repositories/project_catalog_identity_calculator.dart";
import "package:test/test.dart";

void main() {
  final calculator = ProjectCatalogIdentityCalculator(scratchRoot: "/scratch", pathContext: p.context);

  group("scratch rule with POSIX paths", () {
    final posix = ProjectCatalogIdentityCalculator(
      scratchRoot: "/home/alex/.sesori/scratch",
      pathContext: p.Context(style: p.Style.posix, current: "/"),
    );

    test("recognizes the root however it is spelled", () {
      expect(posix.isScratchRoot(path: "/home/alex/.sesori/scratch"), isTrue);
      expect(posix.isScratchRoot(path: "/home/alex/.sesori/scratch/"), isTrue);
      expect(posix.isScratchRoot(path: "/home/alex/.sesori/./scratch"), isTrue);
      expect(posix.isScratchRoot(path: "/home/alex/.sesori/scratch/2026-10-25-k3f9q2"), isFalse);
      expect(posix.isScratchRoot(path: "/home/alex/.sesori/worktrees"), isFalse);
    });

    test("counts the root and everything inside it as scratch", () {
      expect(posix.isWithinScratch(path: "/home/alex/.sesori/scratch"), isTrue);
      expect(posix.isWithinScratch(path: "/home/alex/.sesori/scratch/2026-10-25-k3f9q2"), isTrue);
      expect(posix.isWithinScratch(path: "/home/alex/.sesori/scratch/2026-10-25-k3f9q2/src"), isTrue);
    });

    test("does not count siblings, prefixes or escapes as scratch", () {
      expect(posix.isWithinScratch(path: "/home/alex/.sesori"), isFalse);
      expect(posix.isWithinScratch(path: "/home/alex/.sesori/scratch-old/run"), isFalse);
      expect(posix.isWithinScratch(path: "/home/alex/.sesori/scratch/../worktrees/run"), isFalse);
      expect(posix.isWithinScratch(path: "/projects/app"), isFalse);
    });

    test("accepts only a direct child of the root as a session folder", () {
      expect(posix.isScratchSessionDirectory(path: "/home/alex/.sesori/scratch/2026-10-25-k3f9q2"), isTrue);
      expect(posix.isScratchSessionDirectory(path: "/home/alex/.sesori/scratch/2026-10-25-k3f9q2/"), isTrue);
      expect(posix.isScratchSessionDirectory(path: "/home/alex/.sesori/scratch"), isFalse);
      expect(posix.isScratchSessionDirectory(path: "/home/alex/.sesori/scratch/2026-10-25-k3f9q2/src"), isFalse);
      expect(posix.isScratchSessionDirectory(path: "/home/alex/.sesori/worktrees/run"), isFalse);
      expect(posix.isScratchSessionDirectory(path: "/home/alex/.sesori"), isFalse);
      expect(posix.isScratchSessionDirectory(path: "/"), isFalse);
    });

    test("refuses session folders spelled with .. segments", () {
      expect(posix.isScratchSessionDirectory(path: "/home/alex/.sesori/scratch/a/../2026-10-25-k3f9q2"), isFalse);
      expect(posix.isScratchSessionDirectory(path: "/home/alex/.sesori/scratch/2026-10-25-k3f9q2/src/.."), isFalse);
      expect(posix.isScratchSessionDirectory(path: "/home/alex/.sesori/scratch/../scratch/run"), isFalse);
    });

    test("does not treat a non-path project id as the root", () {
      expect(posix.isScratchRoot(path: "global"), isFalse);
      expect(posix.isWithinScratch(path: "global"), isFalse);
    });
  });

  group("scratch rule with Windows paths", () {
    final windows = ProjectCatalogIdentityCalculator(
      scratchRoot: r"C:\Users\Alex\.sesori\scratch",
      pathContext: p.Context(style: p.Style.windows, current: r"C:\"),
    );

    test("recognizes the root across separators, case and trailing separators", () {
      expect(windows.isScratchRoot(path: r"C:\Users\Alex\.sesori\scratch"), isTrue);
      expect(windows.isScratchRoot(path: r"c:\users\alex\.SESORI\Scratch\"), isTrue);
      expect(windows.isScratchRoot(path: "C:/Users/Alex/.sesori/scratch"), isTrue);
      expect(windows.isScratchRoot(path: r"D:\Users\Alex\.sesori\scratch"), isFalse);
    });

    test("counts the root and everything inside it as scratch", () {
      expect(windows.isWithinScratch(path: r"C:\Users\Alex\.sesori\scratch"), isTrue);
      expect(windows.isWithinScratch(path: r"C:\Users\Alex\.sesori\scratch\2026-10-25-k3f9q2\src"), isTrue);
      expect(windows.isWithinScratch(path: "c:/users/alex/.sesori/scratch/2026-10-25-k3f9q2"), isTrue);
    });

    test("does not count siblings, other drives or escapes as scratch", () {
      expect(windows.isWithinScratch(path: r"C:\Users\Alex\.sesori\scratch-old\run"), isFalse);
      expect(windows.isWithinScratch(path: r"D:\Users\Alex\.sesori\scratch\run"), isFalse);
      expect(windows.isWithinScratch(path: r"C:\Users\Alex\.sesori\scratch\..\worktrees\run"), isFalse);
    });

    test("accepts only a direct child of the root as a session folder", () {
      expect(windows.isScratchSessionDirectory(path: r"C:\Users\Alex\.sesori\scratch\2026-10-25-k3f9q2"), isTrue);
      expect(windows.isScratchSessionDirectory(path: "C:/Users/Alex/.sesori/scratch/2026-10-25-k3f9q2"), isTrue);
      expect(windows.isScratchSessionDirectory(path: r"c:\users\alex\.sesori\scratch\2026-10-25-k3f9q2\"), isTrue);
      expect(windows.isScratchSessionDirectory(path: r"C:\Users\Alex\.sesori\scratch"), isFalse);
      expect(windows.isScratchSessionDirectory(path: r"C:\Users\Alex\.sesori\scratch\run\src"), isFalse);
      expect(windows.isScratchSessionDirectory(path: r"D:\Users\Alex\.sesori\scratch\run"), isFalse);
      expect(windows.isScratchSessionDirectory(path: r"C:\"), isFalse);
    });

    test("refuses session folders spelled with .. segments", () {
      expect(windows.isScratchSessionDirectory(path: r"C:\Users\Alex\.sesori\scratch\a\..\run"), isFalse);
      expect(windows.isScratchSessionDirectory(path: "C:/Users/Alex/.sesori/scratch/a/../run"), isFalse);
    });
  });

  test("builds an order-independent normalized-path index", () {
    final winner = _project(id: "a-project", path: "/projects/current/.");
    final duplicate = _project(id: "z-project", path: "/projects/current");

    final forward = calculator.buildProjectsByNormalizedPath(
      projects: [duplicate, winner],
    );
    final reversed = calculator.buildProjectsByNormalizedPath(
      projects: [winner, duplicate],
    );

    expect(forward["/projects/current"], same(winner));
    expect(reversed["/projects/current"], same(winner));
  });

  test("prefers an exact project id over an observed-path match", () {
    final exact = _project(id: "z-preferred", path: "/projects/current/.");
    final pathMatch = _project(id: "a-path-owner", path: "/projects/current");
    final projects = [pathMatch, exact];

    final result = calculator.calculate(
      projectsById: {for (final project in projects) project.projectId: project},
      projectsByNormalizedPath: calculator.buildProjectsByNormalizedPath(
        projects: projects,
      ),
      preferredProjectId: exact.projectId,
      observedPath: pathMatch.path,
    );

    expect(result, same(exact));
  });

  test("matches an observed path after normalization when the id is absent", () {
    final pathMatch = _project(id: "path-owner", path: "/projects/current/.");

    final result = calculator.calculate(
      projectsById: {pathMatch.projectId: pathMatch},
      projectsByNormalizedPath: {"/projects/current": pathMatch},
      preferredProjectId: "unknown",
      observedPath: "/projects/current",
    );

    expect(result, same(pathMatch));
  });

  test("returns null when neither identity signal matches", () {
    final other = _project(id: "other", path: "/projects/other");
    final result = calculator.calculate(
      projectsById: {other.projectId: other},
      projectsByNormalizedPath: {other.path: other},
      preferredProjectId: "unknown",
      observedPath: "/projects/current",
    );

    expect(result, isNull);
  });
}

ProjectDto _project({required String id, required String path}) {
  return ProjectDto(
    projectId: id,
    path: path,
    createdAt: 1,
    updatedAt: 1,
    projectionUpdatedAt: 1,
  );
}
