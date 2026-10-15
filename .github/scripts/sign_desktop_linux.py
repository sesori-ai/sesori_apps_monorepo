"""Sign already-qualified Linux packages without publishing or executing their payloads."""

import argparse
import json
import os
import re
import shutil
from pathlib import Path

from linux_signing import PUBLIC_KEY, run, sha256, signing_key

CHECKSUMS = "desktop-linux-checksums.txt"


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
    root, output = root.resolve(), output.resolve()
    identity, packages = load_packages(root=root)
    with signing_key(output=output, fingerprint=fingerprint) as key:
        artifacts = []
        for source, unsigned_digest in packages:
            target = output / source.name
            shutil.copy2(source, target)
            if target.suffix == ".rpm":
                payload_command = ["rpm", "-qp", "--qf", "%{PAYLOADDIGEST}"]
                payload_before = run(command=[*payload_command, str(target)], env=key.env)
                run(command=[
                    "rpmsign", "--define", "_openpgp_sign gpg",
                    "--define", f"_openpgp_sign_id {key.fingerprint}",
                    "--define", f"_gpg_path {key.home}",
                    "--define", "_gpg_digest_algo sha256",
                    "--define", "_gpg_sign_cmd_extra_args --batch --pinentry-mode loopback "
                                f"--passphrase-file {key.password}",
                    "--addsign", str(target),
                ], env=key.env)
                if run(command=[*payload_command, str(target)], env=key.env) != payload_before:
                    raise ValueError("RPM signing changed the package payload digest")
                verify_rpm(package=target, public_key=key.public_key, database=key.home.parent / "rpmdb", env=key.env)
            artifacts.append({"name": target.name, "sha256": sha256(path=target),
                              "bytes": target.stat().st_size, "unsignedSha256": unsigned_digest})
        checksums = output / CHECKSUMS
        checksums.write_text("".join(f"{item['sha256']}  {item['name']}\n" for item in artifacts), encoding="utf-8")
        key.sign_detached(source=checksums, signature=output / f"{CHECKSUMS}.asc")
    report = {"schemaVersion": 1, "identity": identity, "signerFingerprint": key.fingerprint,
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
