"""Bounded GitHub calls and anonymous public-byte verification for release publishers."""

import hashlib
import subprocess
from urllib.request import urlopen


def github(*, arguments: list[str]) -> str:
    return subprocess.run(["gh", *arguments], check=True, stdout=subprocess.PIPE,
                          text=True, timeout=300).stdout


def public_sha256(*, url: str) -> str:
    # Deliberately no GH_TOKEN/Authorization: prove ordinary public retrieval.
    digest = hashlib.sha256()
    with urlopen(url, timeout=60) as response:
        while chunk := response.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()
