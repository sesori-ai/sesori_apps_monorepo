import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("PluginProject serializes directory independently from id", () {
    const project = PluginProject(
      id: "project-123",
      directory: "/repo",
      name: "Repo",
      activity: PluginProjectActivity(createdAt: 100, updatedAt: 200),
    );

    expect(project.toJson(), {
      "id": "project-123",
      "directory": "/repo",
      "name": "Repo",
      "activity": {
        "createdAt": 100,
        "updatedAt": 200,
      },
    });
  });
}
