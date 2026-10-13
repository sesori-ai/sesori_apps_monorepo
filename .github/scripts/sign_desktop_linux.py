"""Sign already-qualified Linux packages without publishing or executing their payloads."""

import argparse
import hashlib
import json
import os
import re
import shutil
import subprocess
import tempfile
from pathlib import Path

KEY_SECRET = "LINUX_GPG_PRIVATE_KEY"
PASSPHRASE_SECRET = "LINUX_GPG_PASSPHRASE"
PUBLIC_KEY = "sesori-linux-public.asc"
CHECKSUMS = "desktop-linux-checksums.txt"


def run(*, command: list[str], env: dict[str, str], input_text: str | None = None) -> str:
    # Captured failures retain their output on CalledProcessError, but never print
    # GPG import/signing diagnostics that could reflect supplied secret material.
    return subprocess.run(command, env=env, input=input_text, text=True, capture_output=True,
                          check=True, timeout=120).stdout


def sha256(*, path: Path) -> str:
    with path.open("rb") as stream:
        return hashlib.file_digest(stream, "sha256").hexdigest()


def load_packages(*, root: Path) -> tuple[dict, list[tuple[Path, str]]]:
    identity = None
    packages = []
    for package_format in ("deb", "rpm"):
        report = json.loads((root / package_format / "packaging.json").read_text(encoding="utf-8"))
        current = report["bundle"]["identity"]
        if current["os"] != "linux" or report["format"] != package_format:
            raise ValueError("Expected Linux package evidence for the selected format")
        if identity is not None and current != identity:
            raise ValueError("DEB and RPM must have identical bundle identity")
        identity = current
        expected_name = (f"Sesori-linux-{current['architecture']}-{current['version']}-"
                         f"{current['buildNumber']}.{package_format}")
        if report["package"]["name"] != expected_name:
            raise ValueError("Package filename does not match its bundle identity")
        path = root / package_format / expected_name
        digest = sha256(path=path)
        if digest != report["package"]["sha256"] or path.stat().st_size != report["package"]["bytes"]:
            raise ValueError(f"Package differs from qualified evidence: {path.name}")
        packages.append((path, digest))
    return identity, packages


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


def verify_rpm(*, package: Path, public_key: Path, database: Path, env: dict[str, str]) -> None:
    database.mkdir()
    run(command=["rpm", "--dbpath", str(database), "--initdb"], env=env)
    run(command=["rpmkeys", "--dbpath", str(database), "--import", str(public_key)], env=env)
    result = run(command=["rpmkeys", "--dbpath", str(database), "--checksig", "--verbose", str(package)], env=env)
    # A digest-only unsigned RPM can pass --checksig. Require an actual signature
    # verified using the fresh database containing only the pinned signing key.
    if re.search(r"Signature.*: OK", result, re.IGNORECASE) is None:
        raise ValueError("RPM has no verified OpenPGP signature")


def sign_packages(*, root: Path, output: Path, fingerprint: str) -> dict:
    private_key = os.environ.pop(KEY_SECRET, "")
    passphrase = os.environ.pop(PASSPHRASE_SECRET, "")
    if not private_key or not passphrase:
        raise ValueError("Linux signing requires both protected environment secrets")
    fingerprint = fingerprint.upper()
    if re.fullmatch(r"[A-F0-9]{40}", fingerprint) is None:
        raise ValueError("LINUX_GPG_FINGERPRINT must be the full primary-key fingerprint")
    root, output = root.resolve(), output.resolve()
    if output.exists():
        raise FileExistsError(f"Signing output already exists: {output}")
    identity, packages = load_packages(root=root)
    output.mkdir(parents=True)
    with tempfile.TemporaryDirectory(prefix="sesori-linux-signing-") as temporary:
        work = Path(temporary)
        home = work / "gnupg"
        home.mkdir(mode=0o700)
        password = work / "passphrase"
        with password.open("x", encoding="utf-8") as stream:
            password.chmod(0o600)
            stream.write(passphrase)
        env = {**os.environ, "GNUPGHOME": str(home), "LC_ALL": "C"}
        try:
            run(command=["gpg", "--batch", "--import"], env=env, input_text=private_key)
            listing = run(command=["gpg", "--batch", "--with-colons", "--list-secret-keys"], env=env)
            if primary_fingerprints(listing=listing) != [fingerprint]:
                raise ValueError("Imported signing key does not match LINUX_GPG_FINGERPRINT")
            public_key = output / PUBLIC_KEY
            public_key.write_text(run(command=["gpg", "--batch", "--armor", "--export", fingerprint], env=env),
                                  encoding="utf-8")
            artifacts = []
            for source, unsigned_digest in packages:
                target = output / source.name
                shutil.copy2(source, target)
                if target.suffix == ".rpm":
                    payload_command = ["rpm", "-qp", "--qf", "%{PAYLOADDIGEST}"]
                    payload_before = run(command=[*payload_command, str(target)], env=env)
                    run(command=[
                        "rpmsign", "--define", "_openpgp_sign gpg",
                        "--define", f"_openpgp_sign_id {fingerprint}",
                        "--define", f"_gpg_path {home}",
                        "--define", "_gpg_digest_algo sha256",
                        "--define", "_gpg_sign_cmd_extra_args --batch --pinentry-mode loopback "
                                    f"--passphrase-file {password}",
                        "--addsign", str(target),
                    ], env=env)
                    if run(command=[*payload_command, str(target)], env=env) != payload_before:
                        raise ValueError("RPM signing changed the package payload digest")
                    verify_rpm(package=target, public_key=public_key, database=work / "rpmdb", env=env)
                artifacts.append({"name": target.name, "sha256": sha256(path=target),
                                  "bytes": target.stat().st_size, "unsignedSha256": unsigned_digest})
            checksums = output / CHECKSUMS
            checksums.write_text("".join(f"{item['sha256']}  {item['name']}\n" for item in artifacts),
                                 encoding="utf-8")
            signature = output / f"{CHECKSUMS}.asc"
            run(command=["gpg", "--batch", "--pinentry-mode", "loopback", "--passphrase-file", str(password),
                         "--local-user", fingerprint, "--digest-algo", "SHA256", "--armor", "--detach-sign",
                         "--output", str(signature), str(checksums)], env=env)
            # Verification must need only the public key, not the secret-key home.
            verify_home = work / "public-gnupg"
            verify_home.mkdir(mode=0o700)
            public_env = {**os.environ, "GNUPGHOME": str(verify_home), "LC_ALL": "C"}
            run(command=["gpg", "--batch", "--import", str(public_key)], env=public_env)
            run(command=["gpg", "--batch", "--verify", str(signature), str(checksums)], env=public_env)
        finally:
            run(command=["gpgconf", "--homedir", str(home), "--kill", "all"], env=env)
        report = {"schemaVersion": 1, "identity": identity, "signerFingerprint": fingerprint,
                  "artifacts": artifacts, "checksumFile": CHECKSUMS, "publicKeyFile": PUBLIC_KEY,
                  "proofBoundary": "RPM OpenPGP signature and detached signed checksums for DEB/RPM; "
                                   "not APT/RPM repository publication, desktop-session or upgrade qualification"}
        (output / "signing.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = sign_packages(root=args.root, output=args.output, fingerprint=os.environ.get("LINUX_GPG_FINGERPRINT", ""))
    print(f"Signed Linux {report['identity']['architecture']} packages; "
          f"public fingerprint {report['signerFingerprint']}")


if __name__ == "__main__":
    main()
