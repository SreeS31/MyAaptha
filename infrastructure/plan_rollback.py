"""Compare non-secret release configurations offline; never execute a rollout."""
import argparse
import hashlib
import json
from pathlib import Path
from render_release import validate

IMAGES = {"backend_image": "backend", "frontend_image": "frontend", "ai_image": "ai-agent"}
DEFAULTS = {"backend_max_replicas": 10, "db_pool_size": 20,
            "db_connection_budget": 260, "db_reserved_connections": 40}


def normalized(config):
    if not isinstance(config, dict):
        raise ValueError("Release configuration must be a JSON object")
    validate(config)
    return DEFAULTS | config


def identity(config):
    return hashlib.sha256(json.dumps(config, sort_keys=True, separators=(",", ":")).encode()).hexdigest()


def plan(current, previous):
    current, previous = normalized(current), normalized(previous)
    # Include unknown keys: silently ignoring a newly introduced setting is unsafe.
    changed = sorted(key for key in current.keys() | previous.keys()
                     if key not in IMAGES and (key not in current or key not in previous
                                               or current[key] != previous[key]))
    if changed:
        # Report key names only; never echo unexpected secret values.
        raise ValueError("Non-image settings differ; separate review required: " + ", ".join(changed))
    replacements = [{"deployment": deployment, "from": current[key], "to": previous[key]}
                    for key, deployment in IMAGES.items() if current[key] != previous[key]]
    if not replacements:
        raise ValueError("No image changes to roll back")
    return {"schemaVersion": 1, "releaseApproved": False, "clusterContacted": False,
            "currentConfigSha256": identity(current), "previousConfigSha256": identity(previous),
            "imageChanges": replacements, "schemaCompatibility": "unverified",
            "liveRehearsal": "pending", "requiredChecks": [
                "Confirm the selected cluster and namespace and verify its running image digests.",
                "Review database migrations and old-code compatibility; do not reverse migrations automatically.",
                "Confirm secret/key-ring compatibility, provider callbacks and shared OAuth handoff versions.",
                "Validate the previous images with the current configuration and retained data in staging.",
                "Record approval, execute the reviewed rollback, and verify health plus authenticated flows.",
                "Record alert delivery, timestamps, observed recovery time and the final running digests.",
            ]}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("current", type=Path)
    parser.add_argument("previous", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    try:
        if (args.output.resolve() in (args.current.resolve(), args.previous.resolve())
                or args.output.exists() and any(args.output.samefile(source) for source in (args.current,args.previous))):
            raise ValueError("Output must not overwrite either input release configuration")
        result = plan(json.loads(args.current.read_text(encoding="utf-8")),
                      json.loads(args.previous.read_text(encoding="utf-8")))
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    except (OSError, ValueError, TypeError) as error:
        parser.exit(2, f"Rollback plan rejected: {error}\n")
    print(json.dumps({"imageChanges": len(result["imageChanges"]), "releaseApproved": False,
                      "clusterContacted": False}))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
