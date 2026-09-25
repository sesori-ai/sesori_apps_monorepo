import hashlib
import json
from pathlib import Path
import tempfile
import unittest

from prepare_desktop_release import prepare


SOURCE = "a" * 40
TOOLING = "b" * 40
REPO = "sesori-ai/sesori_apps_monorepo"


class PrepareDesktopReleaseTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.output = self.root / "prepared"
        self.save(self.root / "run.json", {"id": 42, "repository": {"full_name": REPO},
                  "path": ".github/workflows/desktop-qualification.yml", "event": "workflow_dispatch",
                  "conclusion": "success", "head_sha": SOURCE, "head_branch": "main", "status": "completed"})
        for arch in ("arm64", "x64"):
            packages = self.root / f"desktop-macos-packages-{arch}"
            packages.mkdir()
            evidence = self.root / f"desktop-macos-evidence-{arch}"
            bundle = evidence / "desktop-bundle"
            bundle.mkdir(parents=True)
            identity = {"version": "1.8.4", "buildNumber": 24, "sourceSha": SOURCE,
                        "os": "macos", "architecture": arch}
            (bundle / "dart-defines.env").write_text(
                f"SESORI_DESKTOP_BUNDLE_IDENTITY={json.dumps(identity)}\nSESORI_DESKTOP_RELEASE_CHANNEL=stable\n")
            (bundle / "build-source-changes.patch").touch()
            packaging = evidence / "desktop-macos-packaging"
            packaging.mkdir()
            self.save(packaging / "desktop-bundle.json", identity)
            digests = {}
            for suffix in ("zip", "dmg"):
                name = f"Sesori-macos-{arch}.{suffix}"
                payload = name.encode()
                (packages / name).write_bytes(payload)
                digests[name] = hashlib.sha256(payload).hexdigest()
            inventory = {"binaries": [{"path": "fixture", "architecture": arch}], "helperVersion": "1.8.4"}
            self.save(packaging / "packaging.json", {"architecture": arch, "packagerSourceSha": SOURCE,
                      "artifacts": digests, "zip": inventory, "dmg": inventory})
            for kind in ("app", "dmg"):
                self.save(packaging / f"{kind}-notarization.json", {"status": "Accepted"})

    @staticmethod
    def save(path, data):
        path.write_text(json.dumps(data))

    def run_prepare(self, **overrides):
        args = dict(root=self.root, output=self.output, source_sha=SOURCE, tooling_sha=TOOLING,
                    channel="stable", repository=REPO, run_id=42, current_run_id=None)
        prepare(**(args | overrides))

    def test_deterministic_complete_private_metadata(self):
        self.run_prepare()
        self.run_prepare(output=self.root / "second")
        result = json.loads((self.output / "desktop-release.json").read_text())
        self.assertEqual(result["tag"], "v1.8.4")
        self.assertEqual(result["producerWorkflowSha"], SOURCE)
        self.assertNotIn("githubLatest", result)  # The shared finalizer owns Latest.
        self.assertEqual(result["sourceSha"], SOURCE)
        self.assertEqual(result["preparationSourceSha"], TOOLING)
        self.assertEqual(len(result["artifacts"]), 4)
        for row in result["artifacts"]:
            self.assertEqual(row["sourceSha"], SOURCE)
            self.assertEqual(row["channel"], "stable")
        for name in ("desktop-release.json", "checksums.txt"):
            self.assertEqual((self.output / name).read_bytes(), (self.root / "second" / name).read_bytes())

    def test_internal_requires_compiled_channel(self):
        with self.assertRaisesRegex(ValueError, "relabel"):
            self.run_prepare(channel="internal")
        self.assertFalse(self.output.exists())
        for path in self.root.glob("*/desktop-bundle/dart-defines.env"):
            path.write_text(path.read_text().replace("CHANNEL=stable", "CHANNEL=internal"))
        self.run_prepare(channel="internal")
        self.assertEqual(json.loads((self.output / "desktop-release.json").read_text())["tag"],
                         "v1.8.4-internal.24")

    def test_run_provenance_rejections(self):
        path = self.root / "run.json"
        original = json.loads(path.read_text())
        for field, value in (("id", 43), ("head_sha", "not-a-sha"), ("event", "pull_request"),
                             ("conclusion", "failure"), ("path", "other.yml"), ("head_branch", "feature"),
                             ("repository", {"full_name": "someone/fork"})):
            with self.subTest(field=field):
                self.save(path, original | {field: value})
                with self.assertRaises(ValueError):
                    self.run_prepare()
                self.assertFalse(self.output.exists())
        self.save(path, original)

    def test_shared_finalizer_accepts_only_its_own_in_progress_run(self):
        path = self.root / "run.json"
        original = json.loads(path.read_text())
        self.save(path, original | {"path": ".github/workflows/release-all-platforms.yml",
                                  "status": "in_progress", "conclusion": None})
        for current_run_id, tooling_sha in ((None, SOURCE), (43, SOURCE), (42, TOOLING)):
            with self.subTest(current_run_id=current_run_id, tooling_sha=tooling_sha):
                with self.assertRaisesRegex(ValueError, "successful producer"):
                    self.run_prepare(current_run_id=current_run_id, tooling_sha=tooling_sha)
        self.run_prepare(current_run_id=42, tooling_sha=SOURCE)

    def test_completed_production_run_preserves_product_and_workflow_sources(self):
        path = self.root / "run.json"
        self.save(path, json.loads(path.read_text()) | {
            "path": ".github/workflows/submit-release.yml", "head_sha": TOOLING})
        self.run_prepare()
        result = json.loads((self.output / "desktop-release.json").read_text())
        self.assertEqual(result["sourceSha"], SOURCE)
        self.assertEqual(result["producerWorkflowSha"], TOOLING)

    def test_private_qualification_can_rebuild_the_selected_product_source(self):
        path = self.root / "run.json"
        self.save(path, json.loads(path.read_text()) | {"head_sha": TOOLING})
        self.run_prepare()
        result = json.loads((self.output / "desktop-release.json").read_text())
        self.assertEqual(result["sourceSha"], SOURCE)
        self.assertEqual(result["producerWorkflowSha"], TOOLING)

    def test_internal_cycle_requires_its_own_product_source(self):
        path = self.root / "run.json"
        self.save(path, json.loads(path.read_text()) | {
            "path": ".github/workflows/release-all-platforms.yml", "head_sha": TOOLING})
        with self.assertRaisesRegex(ValueError, "Run source differs"):
            self.run_prepare()

    def test_current_failed_run_is_not_admitted(self):
        path = self.root / "run.json"
        self.save(path, json.loads(path.read_text()) | {
            "path": ".github/workflows/submit-release.yml", "conclusion": "failure"})
        with self.assertRaisesRegex(ValueError, "successful producer"):
            self.run_prepare(current_run_id=42, tooling_sha=SOURCE)

    def test_rejects_altered_evidence_and_payloads(self):
        prefix = "desktop-macos-evidence-x64/"
        cases = {
            prefix + "desktop-bundle/build-source-changes.patch": b"dirty",
            prefix + "desktop-bundle/dart-defines.env": b"SESORI_DESKTOP_BUNDLE_IDENTITY={}\n",
            prefix + "desktop-macos-packaging/app-notarization.json": b'{"status":"Invalid"}',
            prefix + "desktop-macos-packaging/desktop-bundle.json": b'{}',
            prefix + "desktop-macos-packaging/packaging.json": b'{}',
            "desktop-macos-packages-x64/Sesori-macos-x64.zip": b"changed bytes",
        }
        for relative, replacement in cases.items():
            with self.subTest(path=relative):
                path = self.root / relative
                original = path.read_bytes()
                path.write_bytes(replacement)
                with self.assertRaises((ValueError, KeyError)):
                    self.run_prepare()
                self.assertFalse(self.output.exists())
                path.write_bytes(original)

    def test_identity_mismatch_between_cpus(self):
        path = self.root / "desktop-macos-evidence-x64/desktop-macos-packaging/desktop-bundle.json"
        original = json.loads(path.read_text())
        for field, value in (("buildNumber", 25), ("version", "1.8.5"), ("version", "1.8.4-internal.24"),
                             ("architecture", "arm64"), ("sourceSha", TOOLING), ("buildNumber", True)):
            with self.subTest(field=field, value=value):
                self.save(path, original | {field: value})
                with self.assertRaises(ValueError):
                    self.run_prepare()
                self.assertFalse(self.output.exists())
        self.save(path, original)

    def test_inventory_and_packager_mismatch(self):
        path = self.root / "desktop-macos-evidence-x64/desktop-macos-packaging/packaging.json"
        original = json.loads(path.read_text())
        for field, value in (("dmg", {"binaries": []}), ("packagerSourceSha", TOOLING),
                             ("architecture", "arm64"), ("artifacts", {})):
            with self.subTest(field=field):
                self.save(path, original | {field: value})
                with self.assertRaises(ValueError):
                    self.run_prepare()
        self.save(path, original)

    def test_missing_cpu_rejected(self):
        (self.root / "desktop-macos-packages-x64/Sesori-macos-x64.zip").unlink()
        with self.assertRaises(FileNotFoundError):
            self.run_prepare()
        self.assertFalse(self.output.exists())

    def test_existing_preparation_not_overwritten(self):
        self.output.mkdir()
        with self.assertRaises(FileExistsError):
            self.run_prepare()

    def test_workflow_is_read_only_and_producer_records_channel(self):
        repo = Path(__file__).resolve().parents[2]
        workflow = (repo / ".github/workflows/desktop-release.yml").read_text()
        for forbidden in ("contents: write", "secrets.", "gh release", "gh api --method", "macos_signing_ci",
                          "release-all-platforms", "submit-release", "internal-release-attempt"):
            self.assertNotIn(forbidden, workflow)
        # Pin the sole permission block, including its end: no job override or
        # newly writable scope can be added without revisiting this contract.
        self.assertEqual(workflow.count("permissions:"), 1)
        self.assertIn("permissions:\n  contents: read\n  actions: read\n\njobs:", workflow)
        self.assertIn("persist-credentials: false", workflow)
        producer = (repo / ".github/workflows/desktop-qualification.yml").read_text()
        self.assertIn('--channel "$CHANNEL"', producer)
        self.assertIn("CHANNEL: ${{ inputs.channel }}", producer)
        self.assertIn("build/desktop-bundle/dart-defines.env", producer)


if __name__ == "__main__":
    unittest.main()
