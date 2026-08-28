import unittest
from pathlib import Path

from publish_firebase_analytics_release_cutoff import (
    PARAMETER_KEY,
    RemoteConfigPublicationError,
    RemoteConfigTemplate,
    publish_cutoff,
)


class _FakeRemoteConfigClient:
    def __init__(self, *, template: dict, etag: str = '"etag-7"') -> None:
        self.template = template
        self.etag = etag
        self.validated: list[tuple[dict, str]] = []
        self.published: list[tuple[dict, str]] = []

    def fetch_template(self) -> RemoteConfigTemplate:
        return RemoteConfigTemplate(body=self.template, etag=self.etag)

    def validate_template(self, *, template: dict, etag: str) -> None:
        self.validated.append((template, etag))

    def publish_template(self, *, template: dict, etag: str) -> None:
        self.published.append((template, etag))


class PublishCutoffTest(unittest.TestCase):
    def test_parameter_key_matches_the_mobile_source(self) -> None:
        mobile_source = Path(
            "client/app/lib/core/platform/firebase_analytics_release_cutoff_source.dart"
        ).read_text()

        self.assertIn(f'parameterKey = "{PARAMETER_KEY}"', mobile_source)

    def test_release_workflow_requires_the_cutoff_after_android_production_submission(self) -> None:
        workflow = Path(".github/workflows/submit-release.yml").read_text()
        publisher_workflow = Path(
            ".github/workflows/publish-firebase-analytics-release-cutoff.yml"
        ).read_text()

        self.assertNotIn("workflow_dispatch:", publisher_workflow)
        self.assertIn("publish-analytics-release-cutoff:", workflow)
        self.assertIn("needs: [resolve, submit-android]", workflow)
        self.assertIn(
            "needs: [resolve, submit-ios, submit-android, publish-analytics-release-cutoff, "
            "build-bridge, approve-bridge-only]",
            workflow,
        )

    def test_adds_the_cutoff_without_changing_unrelated_parameters(self) -> None:
        client = _FakeRemoteConfigClient(
            template={
                "parameters": {"unrelated": {"defaultValue": {"value": "keep"}}},
                "version": {"versionNumber": "7"},
            }
        )

        self.assertTrue(publish_cutoff(client=client, build_number=738))

        expected_parameter = client.published[0][0]["parameters"][PARAMETER_KEY]
        self.assertEqual(expected_parameter["defaultValue"]["value"], "738")
        self.assertEqual(client.published[0][0]["parameters"]["unrelated"]["defaultValue"]["value"], "keep")
        self.assertNotIn("version", client.published[0][0])
        self.assertEqual(client.validated, client.published)
        self.assertEqual(client.published[0][1], '"etag-7"')

    def test_updates_the_cutoff_monotonically(self) -> None:
        client = _FakeRemoteConfigClient(
            template={"parameters": {PARAMETER_KEY: {"defaultValue": {"value": "737"}}}}
        )

        self.assertTrue(publish_cutoff(client=client, build_number=738))
        self.assertEqual(client.published[0][0]["parameters"][PARAMETER_KEY]["defaultValue"]["value"], "738")

    def test_equal_cutoff_is_an_idempotent_no_op(self) -> None:
        client = _FakeRemoteConfigClient(
            template={"parameters": {PARAMETER_KEY: {"defaultValue": {"value": "738"}}}}
        )

        self.assertFalse(publish_cutoff(client=client, build_number=738))
        self.assertEqual(client.validated, [])
        self.assertEqual(client.published, [])

    def test_rejects_a_cutoff_regression(self) -> None:
        client = _FakeRemoteConfigClient(
            template={"parameters": {PARAMETER_KEY: {"defaultValue": {"value": "739"}}}}
        )

        with self.assertRaisesRegex(RemoteConfigPublicationError, "Refusing to move"):
            publish_cutoff(client=client, build_number=738)

    def test_rejects_an_invalid_existing_cutoff(self) -> None:
        client = _FakeRemoteConfigClient(
            template={"parameters": {PARAMETER_KEY: {"defaultValue": {"value": "invalid"}}}}
        )

        with self.assertRaisesRegex(RemoteConfigPublicationError, "is not an integer"):
            publish_cutoff(client=client, build_number=738)


if __name__ == "__main__":
    unittest.main()
