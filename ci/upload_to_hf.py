#!/usr/bin/env python3
"""
Infortts Hugging Face CDN Uploader for Jenkins CI/CD.
Uploads built APK binaries, OTA patches, and manifests directly to Hugging Face Dataset CDN (rttss/ota-patches).
Guarantees 0 bytes static binary accumulation on VPS infrastructure.
"""

import os
import sys
import json
import time
import hashlib
import argparse

def get_token(custom_token=None):
    if custom_token:
        return custom_token
    if os.environ.get("HF_TOKEN"):
        return os.environ["HF_TOKEN"]
    if os.environ.get("HUGGING_FACE_HUB_TOKEN"):
        return os.environ["HUGGING_FACE_HUB_TOKEN"]
    
    # Check standard local cache files
    paths = [
        os.path.expanduser("~/.cache/huggingface/token"),
        os.path.expanduser("~/.huggingface/token"),
        os.path.expanduser("~/.config/huggingface/token")
    ]
    for p in paths:
        if os.path.exists(p):
            with open(p, "r") as f:
                t = f.read().strip()
                if t:
                    return t
    return None

def sha256_file(filepath):
    h = hashlib.sha256()
    with open(filepath, "rb") as f:
        while chunk := f.read(65536):
            h.update(chunk)
    return h.hexdigest()

def main():
    parser = argparse.ArgumentParser(description="Upload APKs and OTA patches to Hugging Face CDN.")
    parser.add_argument("--slug", required=True, help="App slug name (e.g. waptia, mitochondria)")
    parser.add_argument("--apk", help="Path to built release APK file")
    parser.add_argument("--patch", help="Path to OTA differential patch file")
    parser.add_argument("--version", default="1.0.0", help="Version name (e.g. 1.2.0 or 2.03.01+20301)")
    parser.add_argument("--version-code", type=int, help="Android Version code (default: build number from --version '+<build>')")
    parser.add_argument("--track", default="internal", help="Distribution track (internal, alpha, beta, production)")
    parser.add_argument("--repo", default="rttss/ota-patches", help="Hugging Face Dataset repo ID")
    parser.add_argument("--token", help="Hugging Face write token")

    args = parser.parse_args()

    # A requested artifact that is not on disk must abort the publish: the manifest is
    # the contract OTA clients read, and a manifest advertising a URL whose binary was
    # never uploaded turns every client update into a 404. Fail before touching the CDN.
    for flag, path in (("--apk", args.apk), ("--patch", args.patch)):
        if path and not os.path.isfile(path):
            print(f"[ERROR] {flag} '{path}' does not exist — refusing to publish a manifest "
                  f"that points at a missing artifact.", file=sys.stderr)
            sys.exit(2)

    if args.version_code is None:
        # ci/jenkins-common.groovy passes only --version ("<base>+<build>"); deriving the
        # code from the build suffix keeps the manifest consistent instead of pinning 1.
        parts = args.version.split("+", 1)
        try:
            args.version_code = int(parts[1]) if len(parts) > 1 else 0
        except ValueError:
            print(f"[ERROR] Cannot derive version code from --version '{args.version}' "
                  f"(expected '<base>+<build>'); pass --version-code explicitly.", file=sys.stderr)
            sys.exit(2)

    token = get_token(args.token)

    if not token:
        print("[ERROR] No Hugging Face authentication token found in environment or credentials cache.", file=sys.stderr)
        sys.exit(1)

    try:
        from huggingface_hub import HfApi, create_repo
    except ImportError:
        print("[INFO] Installing huggingface_hub...")
        if os.system(f"{sys.executable} -m pip install -q huggingface_hub") != 0:
            print("[ERROR] Failed to install huggingface_hub — cannot publish to the CDN.", file=sys.stderr)
            sys.exit(1)
        from huggingface_hub import HfApi, create_repo

    api = HfApi(token=token)
    repo_id = args.repo

    # Ensure dataset repo exists
    try:
        create_repo(repo_id=repo_id, repo_type="dataset", token=token, exist_ok=True)
    except Exception as e:
        print(f"[WARN] Repository check: {e}")

    slug = args.slug.strip().lower()
    manifest = {
        "slug": slug,
        "package_name": f"com.infortts.{slug}",
        "version_name": args.version,
        "version_code": args.version_code,
        "track": args.track,
        "updated_at": int(time.time()),
        "timestamp_iso": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())
    }

    # 1. Upload APK if provided (apk_url is added to the manifest only once the binary
    #    is really on the CDN, so a manifest never advertises a dead download URL)
    if args.apk and os.path.exists(args.apk):
        apk_size = os.path.getsize(args.apk)
        apk_hash = sha256_file(args.apk)
        manifest["size_bytes"] = apk_size
        manifest["sha256"] = apk_hash
        manifest["apk_url"] = f"https://huggingface.co/datasets/{repo_id}/resolve/main/{slug}/{slug}.apk"

        print(f"[HF CDN] Uploading {slug}.apk ({apk_size / (1024*1024):.2f} MB, SHA256: {apk_hash[:12]}...)")
        api.upload_file(
            path_or_fileobj=args.apk,
            path_in_repo=f"{slug}/{slug}.apk",
            repo_id=repo_id,
            repo_type="dataset",
            commit_message=f"CI: Release APK {slug} v{args.version} [{args.track}]"
        )
        print(f"[HF CDN] APK Live CDN: {manifest['apk_url']}")

    # 2. Upload Patch if provided
    if args.patch and os.path.exists(args.patch):
        patch_name = os.path.basename(args.patch)
        patch_size = os.path.getsize(args.patch)
        patch_hash = sha256_file(args.patch)
        manifest["patch"] = {
            "filename": patch_name,
            "size_bytes": patch_size,
            "sha256": patch_hash,
            "url": f"https://huggingface.co/datasets/{repo_id}/resolve/main/{slug}/patches/{patch_name}"
        }
        print(f"[HF CDN] Uploading patch {patch_name} ({patch_size / 1024:.2f} KB)...")
        api.upload_file(
            path_or_fileobj=args.patch,
            path_in_repo=f"{slug}/patches/{patch_name}",
            repo_id=repo_id,
            repo_type="dataset",
            commit_message=f"CI: OTA Patch {slug} v{args.version}"
        )

    # 3. Upload Manifest
    manifest_bytes = json.dumps(manifest, indent=2).encode("utf-8")
    api.upload_file(
        path_or_fileobj=manifest_bytes,
        path_in_repo=f"{slug}/manifest.json",
        repo_id=repo_id,
        repo_type="dataset",
        commit_message=f"CI: Update manifest for {slug} v{args.version}"
    )
    print(f"[HF CDN] Manifest Live: https://huggingface.co/datasets/{repo_id}/raw/main/{slug}/manifest.json")
    print(json.dumps(manifest, indent=2))

if __name__ == "__main__":
    main()
