#!/usr/bin/env python3
from __future__ import annotations

import argparse
import copy
import gzip
import json
import os
import sys
from dataclasses import dataclass
from typing import Any, Protocol
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

PARAMETER_KEY = "android_latest_production_submission_build"
PARAMETER_DESCRIPTION = "Latest Android build successfully submitted to the Google Play production track."


class RemoteConfigPublicationError(RuntimeError):
    pass


@dataclass(frozen=True)
class RemoteConfigTemplate:
    body: dict[str, Any]
    etag: str


class RemoteConfigClient(Protocol):
    def fetch_template(self) -> RemoteConfigTemplate: ...

    def validate_template(self, *, template: dict[str, Any], etag: str) -> None: ...

    def publish_template(self, *, template: dict[str, Any], etag: str) -> None: ...


class FirebaseRemoteConfigClient:
    def __init__(self, *, project_id: str, access_token: str) -> None:
        self._url = f"https://firebaseremoteconfig.googleapis.com/v1/projects/{project_id}/remoteConfig"
        self._access_token = access_token

    def fetch_template(self) -> RemoteConfigTemplate:
        body, headers = self._request(method="GET", url=self._url)
        etag = headers.get("ETag")
        if not etag:
            raise RemoteConfigPublicationError("Firebase Remote Config did not return an ETag")
        return RemoteConfigTemplate(body=body, etag=etag)

    def validate_template(self, *, template: dict[str, Any], etag: str) -> None:
        _, headers = self._request(
            method="PUT",
            url=f"{self._url}?validate_only=true",
            body=template,
            etag=etag,
        )
        validation_etag = headers.get("ETag")
        if validation_etag is None:
            raise RemoteConfigPublicationError("Firebase Remote Config validation did not return an ETag")
        if not validation_etag.endswith("-0\"") and not validation_etag.endswith("-0"):
            raise RemoteConfigPublicationError(f"Firebase returned an unexpected validation ETag: {validation_etag}")

    def publish_template(self, *, template: dict[str, Any], etag: str) -> None:
        self._request(method="PUT", url=self._url, body=template, etag=etag)

    def _request(
        self,
        *,
        method: str,
        url: str,
        body: dict[str, Any] | None = None,
        etag: str | None = None,
    ) -> tuple[dict[str, Any], Any]:
        headers = {
            "Accept-Encoding": "gzip",
            "Authorization": f"Bearer {self._access_token}",
        }
        encoded_body = None
        if body is not None:
            headers["Content-Type"] = "application/json; UTF8"
            encoded_body = json.dumps(body, separators=(",", ":")).encode("utf-8")
        if etag is not None:
            headers["If-Match"] = etag

        request = Request(url=url, data=encoded_body, headers=headers, method=method)
        try:
            with urlopen(request, timeout=30) as response:
                response_body = response.read()
                if response.headers.get("Content-Encoding") == "gzip":
                    response_body = gzip.decompress(response_body)
                parsed = json.loads(response_body.decode("utf-8")) if response_body else {}
                if not isinstance(parsed, dict):
                    raise RemoteConfigPublicationError("Firebase Remote Config returned a non-object response")
                return parsed, response.headers
        except HTTPError as error:
            response_body = error.read()
            if error.headers.get("Content-Encoding") == "gzip":
                response_body = gzip.decompress(response_body)
            details = response_body.decode("utf-8", errors="replace")
            raise RemoteConfigPublicationError(
                f"Firebase Remote Config request failed with HTTP {error.code}: {details}"
            ) from error
        except URLError as error:
            raise RemoteConfigPublicationError(f"Firebase Remote Config request failed: {error.reason}") from error


def publish_cutoff(*, client: RemoteConfigClient, build_number: int) -> bool:
    if build_number <= 0:
        raise RemoteConfigPublicationError(f"Build number must be positive, got {build_number}")

    current = client.fetch_template()
    existing_build = _read_existing_build(template=current.body)
    if existing_build is not None:
        if build_number < existing_build:
            raise RemoteConfigPublicationError(
                f"Refusing to move {PARAMETER_KEY} backwards from {existing_build} to {build_number}"
            )
        if build_number == existing_build:
            return False

    updated = _updated_template(template=current.body, build_number=build_number)
    client.validate_template(template=updated, etag=current.etag)
    client.publish_template(template=updated, etag=current.etag)
    return True


def _read_existing_build(*, template: dict[str, Any]) -> int | None:
    parameters = template.get("parameters")
    if parameters is None:
        return None
    if not isinstance(parameters, dict):
        raise RemoteConfigPublicationError("Remote Config template parameters must be an object")

    parameter = parameters.get(PARAMETER_KEY)
    if parameter is None:
        return None
    if not isinstance(parameter, dict):
        raise RemoteConfigPublicationError(f"Remote Config parameter {PARAMETER_KEY} must be an object")

    default_value = parameter.get("defaultValue")
    if not isinstance(default_value, dict) or "value" not in default_value:
        raise RemoteConfigPublicationError(f"Remote Config parameter {PARAMETER_KEY} has no default value")
    try:
        build_number = int(default_value["value"])
    except (TypeError, ValueError) as error:
        raise RemoteConfigPublicationError(
            f"Remote Config parameter {PARAMETER_KEY} is not an integer"
        ) from error
    if build_number <= 0:
        raise RemoteConfigPublicationError(
            f"Remote Config parameter {PARAMETER_KEY} must be positive, got {build_number}"
        )
    return build_number


def _updated_template(*, template: dict[str, Any], build_number: int) -> dict[str, Any]:
    updated = copy.deepcopy(template)
    updated.pop("version", None)
    parameters = updated.setdefault("parameters", {})
    if not isinstance(parameters, dict):
        raise RemoteConfigPublicationError("Remote Config template parameters must be an object")

    parameter = parameters.setdefault(PARAMETER_KEY, {})
    if not isinstance(parameter, dict):
        raise RemoteConfigPublicationError(f"Remote Config parameter {PARAMETER_KEY} must be an object")
    parameter["defaultValue"] = {"value": str(build_number)}
    parameter["description"] = PARAMETER_DESCRIPTION
    return updated


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Publish the Android analytics production-submission cutoff")
    parser.add_argument("--project-id", required=True)
    parser.add_argument("--build-number", required=True, type=int)
    return parser.parse_args()


def main() -> int:
    args = _parse_args()
    access_token = os.environ.get("FIREBASE_ACCESS_TOKEN")
    if not access_token:
        print("FIREBASE_ACCESS_TOKEN is required", file=sys.stderr)
        return 2

    client = FirebaseRemoteConfigClient(project_id=args.project_id, access_token=access_token)
    try:
        changed = publish_cutoff(client=client, build_number=args.build_number)
    except RemoteConfigPublicationError as error:
        print(str(error), file=sys.stderr)
        return 1

    if changed:
        print(f"Published {PARAMETER_KEY}={args.build_number}")
    else:
        print(f"{PARAMETER_KEY} is already {args.build_number}; nothing to publish")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
