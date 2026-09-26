"""Exercise publication with local artifacts and mocked GitHub/public HTTP boundaries."""
import hashlib
import io
import json
import os
from pathlib import Path
import subprocess
import tempfile
import textwrap
import unittest
from unittest.mock import patch

import publish_desktop_release as publisher
import test_prepare_desktop_release as fixtures


class PublishDesktopReleaseTest(unittest.TestCase):
    def setUp(self):
        self.fixture = fixtures.PrepareDesktopReleaseTest()
        self.fixture.setUp()
        self.addCleanup(self.fixture.doCleanups)
        self.root = self.fixture.root
        self.uploads = []
        self.public = {}
        self.release = {"draft": False, "prerelease": False, "assets": []}
        self.args = dict(root=self.root, output=self.fixture.output, source_sha=fixtures.SOURCE,
                         tooling_sha=fixtures.TOOLING, channel="stable", repository=fixtures.REPO,
                         run_id=42, current_run_id=None, version="1.8.4", build_number=24)

    @property
    def tag(self):
        return "v1.8.4-internal.24" if self.args["channel"] == "internal" else "v1.8.4"

    def github(self, *, arguments):
        if arguments[0] == "api":
            self.assertEqual(arguments, ["api", f"repos/{fixtures.REPO}/releases/tags/{self.tag}"])
            return json.dumps(self.release)
        self.assertEqual(arguments[:3], ["release", "upload", self.tag])
        self.assertEqual(arguments[4:], ["--repo", fixtures.REPO])
        path = Path(arguments[3])
        self.assertNotIn(path.name, self.public, "Existing assets must never be overwritten")
        self.uploads.append(path.name)
        self.public[path.name] = path.read_bytes()
        return ""

    def download(self, url, *, timeout):
        self.assertEqual(timeout, 60)
        prefix = f"https://github.com/{fixtures.REPO}/releases/download/{self.tag}/"
        self.assertTrue(url.startswith(prefix))
        return io.BytesIO(self.public[url.removeprefix(prefix)])

    def publish(self):
        with patch.object(publisher, "github", side_effect=self.github), \
                patch.object(publisher, "urlopen", side_effect=self.download):
            publisher.publish(**self.args)

    def test_payloads_verified_before_metadata_and_no_bridge_assets_changed(self):
        self.publish()
        self.assertEqual(self.uploads, [
            "Sesori-macos-arm64.dmg", "Sesori-macos-arm64.zip",
            "Sesori-macos-x64.dmg", "Sesori-macos-x64.zip",
            "desktop-checksums.txt", "desktop-release.json",
        ])
        metadata = json.loads(self.public["desktop-release.json"])
        self.assertEqual(metadata["tag"], "v1.8.4")
        self.assertEqual(metadata["sourceSha"], fixtures.SOURCE)

    def use_internal(self):
        self.args["channel"] = "internal"
        for path in self.root.glob("*/desktop-bundle/dart-defines.env"):
            path.write_text(path.read_text().replace("CHANNEL=stable", "CHANNEL=internal"))

    def test_internal_uses_the_existing_shared_prerelease(self):
        self.use_internal()
        self.release["prerelease"] = True
        self.publish()
        self.assertEqual(json.loads(self.public["desktop-release.json"])["tag"], "v1.8.4-internal.24")

    def test_internal_cannot_attach_to_a_stable_release(self):
        self.use_internal()
        with self.assertRaisesRegex(ValueError, "internal pre-release"):
            self.publish()
        self.assertEqual(self.uploads, [])

    def test_partial_upload_retry_reuses_identical_asset(self):
        name = "Sesori-macos-arm64.dmg"
        self.public[name] = (self.root / "desktop-macos-packages-arm64" / name).read_bytes()
        self.release["assets"] = [{"name": name}]
        self.publish()
        self.assertNotIn(name, self.uploads)
        self.assertEqual(len(self.uploads), 5)

    def test_conflicting_existing_asset_refuses_replacement_and_metadata(self):
        name = "Sesori-macos-arm64.dmg"
        self.public[name] = b"already delivered different bytes"
        self.release["assets"] = [{"name": name}]
        with self.assertRaisesRegex(ValueError, "refusing replacement"):
            self.publish()
        self.assertEqual(self.uploads, [])

    def test_bad_public_download_never_publishes_completion_metadata(self):
        with patch.object(publisher, "github", side_effect=self.github), \
                patch.object(publisher, "public_sha256", return_value="0" * 64):
            with self.assertRaisesRegex(ValueError, "digest mismatch"):
                publisher.publish(**self.args)
        self.assertEqual(self.uploads, ["Sesori-macos-arm64.dmg"])

    def test_shared_identity_mismatch_never_calls_github(self):
        for field, value in (("version", "1.8.5"), ("build_number", 25)):
            with self.subTest(field=field), patch.object(publisher, "github") as gh:
                with self.assertRaisesRegex(ValueError, "shared release"):
                    publisher.publish(**(self.args | {field: value, "output": self.root / field}))
                gh.assert_not_called()

    def test_draft_release_cannot_claim_public_retrieval(self):
        self.release["draft"] = True
        with self.assertRaisesRegex(ValueError, "already be public"):
            self.publish()
        self.assertEqual(self.uploads, [])

    def test_http_hash_reads_without_auth_and_in_bounded_chunks(self):
        payload = b"fixture" * 200_000
        response = io.BytesIO(payload)
        with patch.object(publisher, "urlopen", return_value=response) as opened, \
                patch.object(response, "read", wraps=response.read) as chunks:
            result = publisher.public_sha256(url="https://example.invalid/asset.zip")
        opened.assert_called_once_with("https://example.invalid/asset.zip", timeout=60)
        self.assertEqual(len(chunks.call_args_list), 3)
        self.assertTrue(all(call.args == (1024 * 1024,) for call in chunks.call_args_list))
        self.assertEqual(result, hashlib.sha256(payload).hexdigest())


class DesktopReleaseWorkflowTest(unittest.TestCase):
    def test_shared_calls_keep_existing_finalizers_and_approval_boundary(self):
        root = Path(__file__).resolve().parents[1] / "workflows"
        for filename, build_job, dependency, channel in (
            ("release-all-platforms.yml", "desktop-macos", "finalize", "internal"),
            ("submit-release.yml", "build-desktop-macos", "release", "stable"),
        ):
            with self.subTest(workflow=filename):
                text = (root / filename).read_text()
                build = text.split(f"  {build_job}:\n", 1)[1].split("\n  publish-desktop:", 1)[0]
                self.assertIn("uses: ./.github/workflows/desktop-qualification.yml", build)
                self.assertIn("secrets: inherit", build)
                self.assertIn("build_number: ${{ needs.", build)
                permissions = build.split("    permissions:\n", 1)[1].split("    uses:", 1)[0]
                # GitHub validates even skipped nested upgrade jobs, which read PR provenance.
                self.assertEqual(dict(line.strip().split(": ") for line in permissions.splitlines()),
                                 {"contents": "read", "actions": "read", "pull-requests": "read"})
                publish = text.split("  publish-desktop:\n", 1)[1].split("\n  #", 1)[0]
                self.assertIn("vars.DESKTOP_MACOS_PUBLICATION_ENABLED == 'true'", publish)
                self.assertIn(build_job, publish)
                self.assertIn(dependency, publish)
                self.assertIn(f"channel: {channel}", publish)
                self.assertIn("uses: ./.github/workflows/_reusable-desktop-publish.yml", publish)
        submit = (root / "submit-release.yml").read_text()
        self.assertIn("environment: store-production", submit)
        release = submit.split("\n  release:\n", 1)[1]
        self.assertIn("needs.tag.result == 'success'", release)
        self.assertNotIn("build-desktop-macos", release)
        internal = (root / "release-all-platforms.yml").read_text().split("\n  finalize:\n", 1)[1]
        self.assertIn("needs: [preflight, next-build-number, ios, android, bridge]", internal)

    def test_npm_downloads_only_bridge_assets_from_the_shared_release(self):
        root = Path(__file__).resolve().parents[1]
        workflow = (root / "workflows/bridge-npm-publish.yml").read_text()
        self.assertIn('--pattern "sesori-bridge-*.tar.gz"', workflow)
        self.assertIn('--pattern "sesori-bridge-*.zip"', workflow)
        self.assertNotIn('--pattern "*.zip"', workflow)
        self.assertNotIn('--pattern "*.tar.gz"', workflow)

    def test_publisher_cannot_create_or_promote_releases_or_expose_private_evidence(self):
        root = Path(__file__).resolve().parents[1]
        workflow = (root / "workflows/_reusable-desktop-publish.yml").read_text()
        self.assertIn("vars.DESKTOP_MACOS_PUBLICATION_ENABLED == 'true'", workflow)
        self.assertIn('"$GITHUB_REF" == refs/heads/main', workflow)
        for forbidden in ("secrets.", "environment:", "workflow_dispatch:", "gh release create", "gh release edit"):
            self.assertNotIn(forbidden, workflow)
        producer = (root / "workflows/desktop-qualification.yml").read_text()
        self.assertIn("workflow_call:", producer)
        self.assertIn("ref: ${{ inputs.source_sha || github.sha }}", producer)
        self.assertIn("${{ inputs.build_number || github.run_number }}", producer)
        self.assertIn("git merge-base --is-ancestor HEAD origin/main", producer)
        self.assertIn("desktop-qualification-${{ github.workflow }}-", producer)
        self.assertIn("'/.ci-workflow/'", producer)
        self.assertIn("git rev-parse --git-path info/exclude", producer)


class InternalReleaseRolloverTest(unittest.TestCase):
    @staticmethod
    def release(*, tag, published, complete=False, prerelease=True, draft=False):
        return {"tag_name": tag, "published_at": published, "prerelease": prerelease, "draft": draft,
                "assets": [{"name": "desktop-release.json"}] if complete else []}

    def roll(self, *, releases, tag):
        workflow = Path(__file__).resolve().parents[1] / "workflows/release-all-platforms.yml"
        step = workflow.read_text().split("      - name: Roll internal pre-release\n", 1)[1]
        script = textwrap.dedent(step.split("        run: |\n", 1)[1].split("      - name: Summary", 1)[0])
        return self.run_script(script=script, releases=releases, tag=tag)

    def run_script(self, *, script, releases, tag):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            (root / "releases.json").write_text(json.dumps(releases))
            (root / "artifacts").mkdir()
            for name in ["fixture.tar.gz", "fixture.zip", "checksums.txt"]:
                (root / "artifacts" / name).write_text("fixture")
            gh = root / "gh"
            gh.write_text(textwrap.dedent('''\
                #!/usr/bin/env python3
                import json, os, pathlib, sys
                args = sys.argv[1:]
                root = pathlib.Path(os.environ["FAKE_GH_ROOT"])
                releases = json.loads((root / "releases.json").read_text())
                with (root / "calls.jsonl").open("a") as log:
                    log.write(json.dumps(args) + "\\n")
                if args[0] == "api":
                    assert args == ["api", "repos/fixture/repo/releases?per_page=100"], args
                    print(json.dumps(releases))
                elif args[:2] == ["release", "view"]:
                    sys.exit(0 if any(r["tag_name"] == args[2] for r in releases) else 1)
                else:
                    assert args[0] == "release" and args[1] in ["delete", "create", "upload", "edit"], args
                '''))
            gh.chmod(0o755)
            env = os.environ | {"PATH": f"{root}:{os.environ['PATH']}", "FAKE_GH_ROOT": str(root),
                                "GITHUB_REPOSITORY": "fixture/repo", "TAG": tag,
                                "VERSION": "1.0.0", "BUILD_NUMBER": tag.rsplit(".", 1)[1]}
            result = subprocess.run(["bash", "-c", script], cwd=root, env=env, capture_output=True, text=True)
            self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
            return [json.loads(line) for line in (root / "calls.jsonl").read_text().splitlines()]

    def test_rollover_preserves_completed_desktop_through_repeated_failures(self):
        completed = self.release(tag="v1.0.0-internal.11", published="2026-09-25T11:00:00Z", complete=True)
        # A failed desktop build/attachment leaves the newer shared release without its manifest.
        for failed_tag, next_tag in [("v1.0.0-internal.12", "v1.0.0-internal.13"),
                                     ("v1.0.0-internal.13", "v1.0.0-internal.14")]:
            with self.subTest(failed=failed_tag):
                failed = self.release(tag=failed_tag, published="2026-09-25T12:00:00Z")
                calls = self.roll(releases=[failed, completed], tag=next_tag)
                self.assertNotIn(["release", "delete", completed["tag_name"], "--yes"], calls)
                self.assertIn(["release", "delete", failed_tag, "--yes"], calls)
                self.assertTrue(any(c[:3] == ["release", "create", next_tag] for c in calls))

    def test_rollover_retires_older_desktop_only_after_a_newer_completion(self):
        older = self.release(tag="v1.0.0-internal.11", published="2026-09-25T11:00:00Z", complete=True)
        newer = self.release(tag="v1.0.0-internal.13", published="2026-09-25T13:00:00Z", complete=True)
        stable = self.release(tag="v1.0.0", published="2026-09-25T14:00:00Z", complete=True, prerelease=False)
        beta = self.release(tag="v1.0.0-beta.1", published="2026-09-25T14:00:00Z", complete=True)
        draft = self.release(tag="v1.0.0-internal.15", published=None, complete=True, draft=True)
        calls = self.roll(releases=[older, draft, beta, stable, newer], tag="v1.0.0-internal.16")
        deleted = [c[2] for c in calls if c[:2] == ["release", "delete"]]
        self.assertCountEqual(deleted, [older["tag_name"], draft["tag_name"]])
        self.assertNotIn(newer["tag_name"], deleted)

    def test_rollover_keeps_existing_cleanup_before_any_desktop_publication(self):
        old = self.release(tag="v1.0.0-internal.10", published="2026-09-25T10:00:00Z")
        calls = self.roll(releases=[old], tag="v1.0.0-internal.11")
        self.assertIn(["release", "delete", old["tag_name"], "--yes"], calls)

    def test_rollover_retains_current_completed_release_on_retry(self):
        old = self.release(tag="v1.0.0-internal.10", published="2026-09-25T10:00:00Z", complete=True)
        current = self.release(tag="v1.0.0-internal.11", published="2026-09-25T11:00:00Z", complete=True)
        calls = self.roll(releases=[old, current], tag=current["tag_name"])
        self.assertIn(["release", "delete", old["tag_name"], "--yes"], calls)
        self.assertNotIn(["release", "delete", current["tag_name"], "--yes"], calls)
        self.assertTrue(any(c[:3] == ["release", "upload", current["tag_name"]] for c in calls))

    def test_stable_cleanup_preserves_desktop_previews_regardless_of_stable_assets(self):
        workflow = Path(__file__).resolve().parents[1] / "workflows/bridge-npm-publish.yml"
        step = workflow.read_text().split("      - name: Delete superseded internal pre-release\n", 1)[1]
        script = textwrap.dedent(step.split("        run: |\n", 1)[1].split("\n  publish-platform:", 1)[0])
        older = self.release(tag="v1.0.0-internal.10", published="2026-09-25T10:00:00Z", complete=True)
        newer = self.release(tag="v1.0.0-internal.11", published="2026-09-25T11:00:00Z", complete=True)
        incomplete = self.release(tag="v1.0.0-internal.12", published="2026-09-25T12:00:00Z")
        other_version = self.release(tag="v1.0.1-internal.13", published="2026-09-25T13:00:00Z")
        beta = self.release(tag="v1.0.0-beta.1", published="2026-09-25T13:00:00Z")
        for stable_complete in [False, True]:
            with self.subTest(stable_has_desktop=stable_complete):
                stable = self.release(tag="v1.0.0", published="2026-09-25T14:00:00Z",
                                      complete=stable_complete, prerelease=False)
                calls = self.run_script(script=script, tag=stable["tag_name"],
                                        releases=[stable, other_version, incomplete, newer, older, beta])
                deleted = [c[2] for c in calls if c[:2] == ["release", "delete"]]
                self.assertEqual(deleted, [incomplete["tag_name"]])


if __name__ == "__main__":
    unittest.main()
