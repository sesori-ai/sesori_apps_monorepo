"""Sign and verify desktop update payloads with the Ed25519 update key.

One key signs Sparkle appcast enclosures (`sparkle:edSignature`) and Velopack feeds
(`releases.<channel>.json.sig`). Signatures and public keys are base64 of the raw
Ed25519 bytes, which is Sparkle's format and what the desktop verifier reads.
"""

import argparse
import base64
import subprocess
import sys
import tempfile
from pathlib import Path

# DER SubjectPublicKeyInfo header for an Ed25519 key; the raw 32-byte key follows it.
ED25519_SPKI_PREFIX = bytes.fromhex("302a300506032b6570032100")


def _openssl(*args: str) -> bytes:
    result = subprocess.run(["openssl", *args], capture_output=True)
    if result.returncode != 0:
        raise RuntimeError(f"openssl {args[0]} failed: {result.stderr.decode(errors='replace').strip()}")
    return result.stdout


def public_key(*, key: Path) -> str:
    der = _openssl("pkey", "-in", str(key), "-pubout", "-outform", "DER")
    if len(der) != len(ED25519_SPKI_PREFIX) + 32 or not der.startswith(ED25519_SPKI_PREFIX):
        raise ValueError("The update signing key is not an Ed25519 key")
    return base64.b64encode(der[len(ED25519_SPKI_PREFIX):]).decode()


def sign(*, key: Path, payload: Path) -> str:
    public_key(key=key)
    return base64.b64encode(_openssl("pkeyutl", "-sign", "-rawin", "-inkey", str(key), "-in", str(payload))).decode()


def verify(*, public_key_b64: str, payload: Path, signature_b64: str) -> bool:
    raw_key = base64.b64decode(public_key_b64, validate=True)
    if len(raw_key) != 32:
        raise ValueError("An Ed25519 public key is 32 bytes")
    with tempfile.TemporaryDirectory() as scratch:
        key_file, signature_file = Path(scratch) / "public.der", Path(scratch) / "signature"
        key_file.write_bytes(ED25519_SPKI_PREFIX + raw_key)
        signature_file.write_bytes(base64.b64decode(signature_b64, validate=True))
        result = subprocess.run(
            ["openssl", "pkeyutl", "-verify", "-rawin", "-pubin", "-keyform", "DER", "-inkey", str(key_file),
             "-in", str(payload), "-sigfile", str(signature_file)],
            capture_output=True,
        )
    if result.returncode == 0:
        return True
    if b"Signature Verification Failure" in result.stdout:
        return False
    raise RuntimeError(f"openssl could not check the update signature: {result.stderr.decode(errors='replace').strip()}")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    for name in ("sign", "public-key"):
        command = commands.add_parser(name)
        command.add_argument("--key", type=Path, required=True)
        if name == "sign":
            command.add_argument("--payload", type=Path, required=True)
    check = commands.add_parser("verify")
    check.add_argument("--public-key", required=True)
    check.add_argument("--payload", type=Path, required=True)
    check.add_argument("--signature", required=True)
    args = parser.parse_args()

    if args.command == "public-key":
        print(public_key(key=args.key))
    elif args.command == "sign":
        print(sign(key=args.key, payload=args.payload))
    elif not verify(public_key_b64=args.public_key, payload=args.payload, signature_b64=args.signature):
        print("Update signature does not match the public key", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
