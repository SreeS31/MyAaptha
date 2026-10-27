"""Record local build identities without claiming signing or release approval."""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from datetime import datetime, timezone
from pathlib import Path


ARTIFACTS = {
    "api": "backend/spring-boot-app/target/myaaptha-service-0.1.0.jar",
    "web_build_id": "frontend/nextjs-app/.next/BUILD_ID",
    "android_debug": "mobile/flutter-app/build/app/outputs/flutter-apk/app-debug.apk",
}
WEB_BUNDLE = "frontend/nextjs-app/.next/standalone"


def fingerprint(path: Path) -> dict:
    before = path.stat()
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(block)
    after = path.stat()
    if (before.st_size, before.st_mtime_ns) != (after.st_size, after.st_mtime_ns):
        raise ValueError("An artifact changed while hashing. Finish the build and retry.")
    return {"sizeBytes": after.st_size, "sha256": digest.hexdigest()}


def is_link(path: Path) -> bool:
    return path.is_symlink() or (hasattr(path, "is_junction") and path.is_junction())


def bundle_files(bundle: Path) -> list[Path]:
    result = []
    def fail(error):
        raise error
    for directory, directories, files in os.walk(bundle, followlinks=False, onerror=fail):
        current = Path(directory)
        for name in list(directories):
            path = current / name
            if is_link(path):
                raise ValueError("Web bundle contains a link/junction; assemble regular files before recording.")
            if path.relative_to(bundle).as_posix() == ".next/cache":
                directories.remove(name)
        for name in files:
            path = current / name
            if is_link(path):
                raise ValueError("Web bundle contains a link/junction; assemble regular files before recording.")
            result.append(path)
    return sorted(result, key=lambda path: path.relative_to(bundle).as_posix())


def web_bundle_snapshot(root: Path) -> dict:
    bundle = root / WEB_BUNDLE
    if is_link(bundle):
        raise ValueError("Web bundle root must not be a link/junction.")
    if not bundle.is_dir():
        return {"path": WEB_BUNDLE, "present": False, "missing": ["standalone bundle"]}
    files = bundle_files(bundle)
    manifest = [{"path": path.relative_to(bundle).as_posix(), **fingerprint(path)} for path in files]
    if [path.relative_to(bundle).as_posix() for path in bundle_files(bundle)] != [item["path"] for item in manifest]:
        raise ValueError("Web bundle files changed while recording. Finish the build and retry.")
    names = {item["path"] for item in manifest}
    required = ("server.js", "package.json", ".next/BUILD_ID", "node_modules/next/package.json")
    missing = [name for name in required if name not in names]
    missing += [prefix for prefix in ("public/", ".next/static/") if not any(name.startswith(prefix) for name in names)]
    # Paths and file content are significant; filesystem timestamps are not.
    canonical = json.dumps(manifest, ensure_ascii=False, sort_keys=True, separators=(",", ":")).encode("utf-8")
    return {"path": WEB_BUNDLE, "present": not missing, "missing": missing,
            "algorithm": "sha256-canonical-json-v1", "sha256": hashlib.sha256(canonical).hexdigest(),
            "fileCount": len(manifest), "sizeBytes": sum(item["sizeBytes"] for item in manifest),
            "excluded": [".next/cache/"], "manifest": manifest}


def snapshot(root: Path) -> dict:
    root = root.resolve()
    artifacts = []
    for name, relative in ARTIFACTS.items():
        path = root / relative
        item = {"name": name, "path": relative, "present": path.is_file()}
        if item["present"]:
            if is_link(path):
                raise ValueError("Artifact paths must not be links/junctions.")
            item.update(fingerprint(path))
            if name == "web_build_id":
                item["buildId"] = path.read_text(encoding="utf-8").strip()
        artifacts.append(item)
    web_bundle = web_bundle_snapshot(root)
    outer_id = next(item for item in artifacts if item["name"] == "web_build_id")
    inner_id = next((item for item in web_bundle.get("manifest", []) if item["path"] == ".next/BUILD_ID"), {})
    if outer_id["present"] and inner_id and outer_id["sha256"] != inner_id["sha256"]:
        web_bundle["present"] = False
        web_bundle["missing"].append("matching standalone BUILD_ID")
    return {
        "schemaVersion": 2,
        "recordedAt": datetime.now(timezone.utc).isoformat(),
        "scope": "Local API/APK and assembled standalone web bundle identities; not production container approval.",
        "releaseApproved": False,
        "androidVariant": "debug; physical-device acceptance and store signing remain pending",
        "allPresent": all(item["present"] for item in artifacts) and web_bundle["present"],
        "artifacts": artifacts,
        "webBundle": web_bundle,
    }


def matches(record: dict, current: dict) -> bool:
    return (isinstance(record, dict) and record.get("schemaVersion") == current["schemaVersion"] == 2
            and record.get("releaseApproved") is False
            and record.get("allPresent") is True and current["allPresent"] is True
            and record.get("artifacts") == current["artifacts"]
            and record.get("webBundle") == current["webBundle"])


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, default=Path(__file__).resolve().parents[1])
    action = parser.add_mutually_exclusive_group(required=True)
    action.add_argument("--output", type=Path)
    action.add_argument("--verify", type=Path, help="Verify current bytes against a version-2 identity record.")
    args = parser.parse_args()
    if args.output:
        output = args.output.resolve()
        if output.suffix.lower() != ".json" or output.is_relative_to((args.root / WEB_BUNDLE).resolve()):
            parser.error("Write the JSON identity record outside the assembled web bundle.")
    try:
        result = snapshot(args.root)
    except (OSError, ValueError) as error:
        parser.exit(1, f"Artifact recording failed: {error}\n")
    if args.verify:
        try:
            verified = matches(json.loads(args.verify.read_text(encoding="utf-8")), result)
        except (OSError, ValueError, TypeError):
            verified = False
        print(json.dumps({"matches": verified, "releaseApproved": False}))
        return 0 if verified else 1
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(json.dumps({"allPresent": result["allPresent"], "releaseApproved": False,
                      "output": str(args.output)}))
    return 0 if result["allPresent"] else 1


if __name__ == "__main__":
    raise SystemExit(main())
