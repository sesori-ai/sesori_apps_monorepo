"""One temporary OpenPGP key owner for Linux desktop packages and Bridge archives."""

import contextlib
import hashlib
import os
import re
import subprocess
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Iterator

KEY_SECRET = "LINUX_GPG_PRIVATE_KEY"
PASSPHRASE_SECRET = "LINUX_GPG_PASSPHRASE"
PUBLIC_KEY = "sesori-linux-public.asc"


def run(*, command: list[str], env: dict[str, str], input_text: str | None = None) -> str:
    # Retain diagnostics on CalledProcessError without printing supplied secrets.
    return subprocess.run(command, env=env, input=input_text, text=True, capture_output=True,
                          check=True, timeout=120).stdout


def sha256(*, path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def primary_fingerprints(*, listing: str) -> list[str]:
    fingerprints = []
    primary = False
    for line in listing.splitlines():
        fields = line.split(":")
        if fields[0] == "sec":
            primary = True
        elif fields[0] == "fpr" and primary:
            fingerprints.append(fields[9])
            primary = False
    return fingerprints


@dataclass(frozen=True)
class LinuxSigningKey:
    fingerprint: str
    home: Path
    password: Path
    public_key: Path
    env: dict[str, str]
    public_env: dict[str, str]

    def sign_detached(self, *, source: Path, signature: Path) -> None:
        run(command=["gpg", "--batch", "--pinentry-mode", "loopback", "--passphrase-file", str(self.password),
                     "--local-user", self.fingerprint, "--digest-algo", "SHA256", "--armor", "--detach-sign",
                     "--output", str(signature), str(source)], env=self.env)
        # Verification must not rely on the signing home's private key.
        run(command=["gpg", "--batch", "--verify", str(signature), str(source)], env=self.public_env)

    def sign_cleartext(self, *, source: Path, signature: Path) -> None:
        run(command=["gpg", "--batch", "--pinentry-mode", "loopback", "--passphrase-file", str(self.password),
                     "--local-user", self.fingerprint, "--digest-algo", "SHA256", "--clearsign",
                     "--output", str(signature), str(source)], env=self.env)
        run(command=["gpg", "--batch", "--verify", str(signature)], env=self.public_env)


@contextlib.contextmanager
def signing_key(*, output: Path, fingerprint: str) -> Iterator[LinuxSigningKey]:
    private_key = os.environ.pop(KEY_SECRET, "")
    passphrase = os.environ.pop(PASSPHRASE_SECRET, "")
    if not private_key or not passphrase:
        raise ValueError("Linux signing requires both protected environment secrets")
    fingerprint = fingerprint.upper()
    if re.fullmatch(r"[A-F0-9]{40}", fingerprint) is None:
        raise ValueError("LINUX_GPG_FINGERPRINT must be the full primary-key fingerprint")
    if output.exists():
        raise FileExistsError(f"Signing output already exists: {output}")
    output.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix="sesori-linux-signing-") as temporary:
        work = Path(temporary)
        home, public_home = work / "gnupg", work / "public-gnupg"
        home.mkdir(mode=0o700)
        public_home.mkdir(mode=0o700)
        password = work / "passphrase"
        with password.open("x", encoding="utf-8") as stream:
            password.chmod(0o600)
            stream.write(passphrase)
        env = {**os.environ, "GNUPGHOME": str(home), "LC_ALL": "C"}
        public_env = {**os.environ, "GNUPGHOME": str(public_home), "LC_ALL": "C"}
        try:
            run(command=["gpg", "--batch", "--import"], env=env, input_text=private_key)
            listing = run(command=["gpg", "--batch", "--with-colons", "--list-secret-keys"], env=env)
            if primary_fingerprints(listing=listing) != [fingerprint]:
                raise ValueError("Imported signing key does not match LINUX_GPG_FINGERPRINT")
            public_key = output / PUBLIC_KEY
            public_key.write_text(run(command=["gpg", "--batch", "--armor", "--export", fingerprint], env=env),
                                  encoding="utf-8")
            run(command=["gpg", "--batch", "--import", str(public_key)], env=public_env)
            yield LinuxSigningKey(fingerprint=fingerprint, home=home, password=password,
                                  public_key=public_key, env=env, public_env=public_env)
        finally:
            run(command=["gpgconf", "--homedir", str(home), "--kill", "all"], env=env)
