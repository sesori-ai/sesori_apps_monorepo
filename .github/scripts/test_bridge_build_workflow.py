"""Bridge build configuration contracts; native release builds remain CI evidence."""
import re
import unittest
from pathlib import Path

WORKFLOW = Path(__file__).resolve().parents[1] / "workflows/_reusable-bridge-build.yml"


class BridgeBuildWorkflowTest(unittest.TestCase):
    def setUp(self):
        self.workflow = WORKFLOW.read_text()
        self.steps = re.findall(r"(?ms)^      - .*?(?=^      - |\Z)", self.workflow)

    def step_using(self, action):
        matches = [step for step in self.steps if f"uses: {action}" in step]
        self.assertEqual(len(matches), 1, action)
        return matches[0]

    def test_every_target_uses_the_source_pinned_standalone_dart_sdk(self):
        checkouts = [step for step in self.steps if "uses: actions/checkout@" in step]
        self.assertEqual(len(checkouts), 2)
        self.assertIn("ref: ${{ inputs.ref }}", checkouts[0])
        self.assertIn("path: .ci-workflow", checkouts[1])
        self.assertNotIn("ref: ${{ inputs.ref }}", checkouts[1])
        resolver = self.step_using("./.ci-workflow/.github/actions/resolve-flutter-dart-version")
        setup = self.step_using("dart-lang/setup-dart@")
        self.assertIn("id: dart-version", resolver)
        self.assertIn("sdk: ${{ steps.dart-version.outputs.version }}", setup)
        for step in (resolver, setup):
            self.assertNotRegex(step, r"(?m)^        if:")
        self.assertNotIn("uses: ./.ci-workflow/.github/actions/setup-flutter", self.workflow)
        self.assertNotIn("matrix.use_asdf", self.workflow)

    def test_pub_dependencies_are_cached_per_host_and_resolved_for_all_targets(self):
        cache = self.step_using("actions/cache@")
        self.assertIn("${{ runner.os }}-${{ runner.arch }}-pub-", cache)
        self.assertIn("hashFiles('bridge/pubspec.lock')", cache)
        self.assertNotRegex(cache, r"(?m)^        if:")
        dependencies = [step for step in self.steps if "run: dart pub get\n" in step]
        self.assertEqual(len(dependencies), 1)
        self.assertIn("working-directory: bridge\n", dependencies[0])
        self.assertNotRegex(dependencies[0], r"(?m)^        if:")

    def test_six_archives_keep_the_complete_cli_bundle(self):
        self.assertEqual(
            set(re.findall(r"asset_name: (\S+)", self.workflow)),
            {f"sesori-bridge-{os}-{arch}" for os in ("macos", "linux", "windows") for arch in ("x64", "arm64")},
        )
        self.assertIn("run: dart build cli -o build/cli", self.workflow)
        self.assertIn("-C build/cli/bundle .", self.workflow)
        self.assertIn('Compress-Archive -Path "bridge/app/build/cli/bundle/*"', self.workflow)


if __name__ == "__main__":
    unittest.main()
