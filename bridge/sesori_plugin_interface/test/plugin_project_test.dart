import "package:sesori_plugin_interface/sesori_plugin_interface.dart";
import "package:test/test.dart";

void main() {
  test("PluginProject serializes session-derived activity only", () {
    const project = PluginProject(
      id: "/repo",
      name: "Repo",
      activity: PluginProjectActivity(createdAt: 100, updatedAt: 200),
    );

    expect(project.toJson(), {
      "id": "/repo",
      "name": "Repo",
      "activity": {
        "createdAt": 100,
        "updatedAt": 200,
      },
    });
  });
}
