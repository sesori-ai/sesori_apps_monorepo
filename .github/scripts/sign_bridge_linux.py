"""Sign the two existing Linux Bridge archives without unpacking or changing them."""

import argparse
import json
import os
from pathlib import Path

from linux_signing import PUBLIC_KEY, sha256, signing_key

ARCHIVES = ("sesori-bridge-linux-x64.tar.gz", "sesori-bridge-linux-arm64.tar.gz")


def sign_archives(*, root: Path, output: Path, fingerprint: str) -> dict:
    root, output = root.resolve(), output.resolve()
    sources = [root / name for name in ARCHIVES]
    for source in sources:
        if not source.is_file() or source.stat().st_size == 0:
            raise ValueError(f"Missing or empty Linux Bridge archive: {source.name}")
    with signing_key(output=output, fingerprint=fingerprint) as key:
        artifacts = []
        for source in sources:
            signature = output / f"{source.name}.asc"
            key.sign_detached(source=source, signature=signature)
            artifacts.append({"name": source.name, "sha256": sha256(path=source),
                              "bytes": source.stat().st_size, "signature": signature.name})
    # No completion evidence if signing, public-only verification or cleanup fails.
    report = {"schemaVersion": 1, "signerFingerprint": key.fingerprint, "artifacts": artifacts,
              "publicKeyFile": PUBLIC_KEY,
              "proofBoundary": "Detached OpenPGP signatures for unchanged CLI archives; "
                               "not desktop packages or automatic updater signature enforcement"}
    (output / "signing.json").write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    return report


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    report = sign_archives(root=args.root, output=args.output, fingerprint=os.environ.get("LINUX_GPG_FINGERPRINT", ""))
    print(f"Signed both Linux Bridge archives; public fingerprint {report['signerFingerprint']}")


if __name__ == "__main__":
    main()
