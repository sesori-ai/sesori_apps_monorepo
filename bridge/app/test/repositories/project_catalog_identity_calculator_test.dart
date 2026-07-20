import "package:sesori_bridge/src/api/database/tables/projects_table.dart";
import "package:sesori_bridge/src/repositories/project_catalog_identity_calculator.dart";
import "package:test/test.dart";

void main() {
  const calculator = ProjectCatalogIdentityCalculator();

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
