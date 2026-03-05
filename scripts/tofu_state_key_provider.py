#!/usr/bin/env python3

import base64
import hashlib
import json
import os
import sys


def fail(message: str) -> None:
    print(message, file=sys.stderr)
    raise SystemExit(1)


def main() -> None:
    header = {"magic": "OpenTofu-External-Key-Provider", "version": 1}
    sys.stdout.write(json.dumps(header) + "\n")
    sys.stdout.flush()

    input_raw = sys.stdin.read().strip()
    has_metadata = input_raw not in ("", "null")
    if has_metadata:
        try:
            if not isinstance(json.loads(input_raw), dict):
                fail("external key provider input must be an object or null")
        except json.JSONDecodeError as exc:
            fail(f"failed to decode external key provider input: {exc}")

    passphrase = os.environ.get("TOFU_STATE_PASSPHRASE") or os.environ.get("TF_VAR_tofu_state_passphrase")

    if passphrase is None or len(passphrase) < 16:
        fail("TOFU_STATE_PASSPHRASE must be set to at least 16 characters")
    assert passphrase is not None

    salt = hashlib.sha256(b"unofficial-postmarketos/meta-state-key").digest()[:16]
    key = hashlib.pbkdf2_hmac("sha512", passphrase.encode("utf-8"), salt, 600000, dklen=32)
    key_b64 = base64.b64encode(key).decode("ascii")

    output = {
        "keys": {
            "encryption_key": key_b64,
        },
        "meta": {
            "external_data": {
                "salt": base64.b64encode(salt).decode("ascii"),
            }
        },
    }

    if has_metadata:
        output["keys"]["decryption_key"] = key_b64

    sys.stdout.write(json.dumps(output))


if __name__ == "__main__":
    main()
