#!/usr/bin/env python3
"""Read-only identity ledger for one FDE employee runtime closure.

The inspector never synchronizes, publishes, materializes, deletes, or rewrites
assets.  It compares the reviewed source closure with an optional bdsh mirror,
an installed Desktop Bridge release fingerprint, explicit environment evidence,
and an optional frozen batch runtime snapshot.
"""

from __future__ import annotations

import argparse
import hashlib
import json
import re
from pathlib import Path, PurePosixPath
from typing import Any
from urllib.parse import urlsplit, urlunsplit

REPORT_SCHEMA = "yoodesk.fde/runtime-drift-report/v1"
HEX_SHA256 = re.compile(r"^[0-9a-f]{64}$")
SNAPSHOT_MANIFEST = ".yoodesk-runtime-snapshot.json"


class EvidenceError(ValueError):
    """Raised when evidence cannot be read without crossing a trust boundary."""


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    root = Path(__file__).resolve().parents[4]
    parser = argparse.ArgumentParser(
        description="Compare FDE source, mirror, release, materialization, and batch snapshot identities.",
    )
    parser.add_argument("--employee-id", required=True)
    parser.add_argument(
        "--manifest",
        type=Path,
        default=root / "yoodesk-dzhyg" / "manifests" / "fde_modules.json",
    )
    parser.add_argument(
        "--asset-root",
        type=Path,
        default=root / "yoodesk-dzhyg",
    )
    parser.add_argument("--bdsh-root", type=Path)
    parser.add_argument(
        "--release-fingerprint-json",
        type=Path,
        help="JSON emitted by the installed Desktop Bridge `release` command.",
    )
    parser.add_argument("--batch-root", type=Path)
    parser.add_argument(
        "--snapshot-rel-path",
        action="append",
        default=[],
        help="Exact attested release path selected by the reviewed batch producer; repeat for the full snapshot closure.",
    )
    parser.add_argument(
        "--snapshot-policy",
        choices=("historical", "fresh"),
        default="historical",
        help="Historical snapshots may differ from the current release; fresh snapshots must match it.",
    )
    parser.add_argument("--rel-path", action="append", default=[])
    parser.add_argument("--expected-account-url")
    parser.add_argument("--observed-account-url")
    parser.add_argument("--expected-fde-url")
    parser.add_argument("--observed-fde-url")
    parser.add_argument(
        "--require-complete",
        action="store_true",
        help="Return exit 2 when environment, mirror, or release evidence is missing.",
    )
    parser.add_argument("--json", action="store_true")
    return parser.parse_args(argv)


def checked_root(path: Path, label: str) -> Path:
    if path.is_symlink():
        raise EvidenceError(f"{label} must not be a symlink: {path}")
    if not path.is_dir():
        raise EvidenceError(f"{label} is not a directory: {path}")
    return path.resolve(strict=True)


def checked_json(path: Path, label: str) -> dict[str, Any]:
    if path.is_symlink() or not path.is_file():
        raise EvidenceError(f"{label} must be a regular non-symlink file: {path}")
    try:
        value = json.loads(path.read_text("utf-8"))
    except (OSError, UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise EvidenceError(f"cannot read {label}: {exc}") from exc
    if not isinstance(value, dict):
        raise EvidenceError(f"{label} must contain a JSON object")
    return value


def safe_relative(value: object, label: str) -> PurePosixPath:
    if not isinstance(value, str) or not value or "\\" in value or "\x00" in value:
        raise EvidenceError(f"{label} must be a non-empty portable POSIX relative path")
    if any(part in ("", ".", "..") for part in value.split("/")):
        raise EvidenceError(f"{label} escapes its root: {value}")
    rel = PurePosixPath(value)
    if rel.is_absolute():
        raise EvidenceError(f"{label} escapes its root: {value}")
    return rel


def checked_file(root: Path, rel: PurePosixPath, label: str) -> Path:
    current = root
    for part in rel.parts:
        current = current / part
        if current.is_symlink():
            raise EvidenceError(f"{label} contains a symlink: {current}")
    if not current.is_file():
        raise EvidenceError(f"{label} is missing or not a regular file: {current}")
    resolved = current.resolve(strict=True)
    if resolved != root and root not in resolved.parents:
        raise EvidenceError(f"{label} escapes its root: {current}")
    return resolved


def checked_optional_file(root: Path, rel: PurePosixPath, label: str) -> Path | None:
    current = root
    for part in rel.parts:
        current = current / part
        if current.is_symlink():
            raise EvidenceError(f"{label} contains a symlink: {current}")
    if not current.exists():
        return None
    if not current.is_file():
        raise EvidenceError(f"{label} is not a regular file: {current}")
    resolved = current.resolve(strict=True)
    if resolved != root and root not in resolved.parents:
        raise EvidenceError(f"{label} escapes its root: {current}")
    return resolved


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        while chunk := handle.read(1024 * 1024):
            digest.update(chunk)
    return digest.hexdigest()


def canonical_url(value: str, label: str, *, remote_https: bool = False) -> str:
    candidate = value.strip()
    try:
        parsed = urlsplit(candidate)
        host = parsed.hostname.lower() if parsed.hostname else ""
        _ = parsed.port
    except ValueError as exc:
        raise EvidenceError(f"{label} is not a safe absolute HTTP(S) URL") from exc
    if (
        parsed.scheme not in {"http", "https"}
        or not host
        or parsed.username is not None
        or parsed.password is not None
        or parsed.query
        or parsed.fragment
    ):
        raise EvidenceError(f"{label} is not a safe absolute HTTP(S) URL")
    loopback = host in {"localhost", "127.0.0.1", "::1", "[::1]"}
    if remote_https and parsed.scheme != "https" and not loopback:
        raise EvidenceError(f"{label} must use HTTPS unless it is exact loopback")
    path = parsed.path.rstrip("/")
    return urlunsplit((parsed.scheme.lower(), parsed.netloc.lower(), path, "", ""))


def add_check(
    checks: list[dict[str, Any]],
    check_id: str,
    layer: str,
    status: str,
    *,
    blocking: bool = False,
    detail: str = "",
) -> None:
    checks.append(
        {
            "id": check_id,
            "layer": layer,
            "status": status,
            "blocking": blocking,
            "detail": detail,
        }
    )


def endpoint_check(
    checks: list[dict[str, Any]],
    label: str,
    expected: str | None,
    observed: str | None,
) -> bool:
    if not expected and not observed:
        add_check(checks, f"environment.{label}", "environment", "unverified")
        return False
    if not expected or not observed:
        add_check(
            checks,
            f"environment.{label}",
            "environment",
            "missing",
            blocking=True,
            detail="expected and observed identities must be supplied together",
        )
        return False
    expected_url = canonical_url(
        expected,
        f"expected {label}",
        remote_https=label == "fde_url",
    )
    observed_url = canonical_url(
        observed,
        f"observed {label}",
        remote_https=label == "fde_url",
    )
    equal = expected_url == observed_url
    add_check(
        checks,
        f"environment.{label}",
        "environment",
        "equal" if equal else "different",
        blocking=not equal,
        detail=f"expected={expected_url} observed={observed_url}",
    )
    return equal


def selected_assets(
    manifest: dict[str, Any],
    employee_id: str,
    selected_rel_paths: set[str],
) -> list[dict[str, Any]]:
    modules = manifest.get("modules")
    if not isinstance(modules, list):
        raise EvidenceError("manifest.modules must be an array")
    result: list[dict[str, Any]] = []
    seen: set[str] = set()
    for module in modules:
        if not isinstance(module, dict):
            continue
        module_id = str(module.get("id") or "")
        entries = module.get("assets")
        if not isinstance(entries, list):
            continue
        for entry in entries:
            if not isinstance(entry, dict):
                continue
            targets = entry.get("publish_targets")
            if not isinstance(targets, list):
                continue
            for target in targets:
                if not isinstance(target, dict) or target.get("employee_id") != employee_id:
                    continue
                rel_path = safe_relative(target.get("rel_path"), "publish target rel_path").as_posix()
                if selected_rel_paths and rel_path not in selected_rel_paths:
                    continue
                if rel_path in seen:
                    raise EvidenceError(f"duplicate publish target rel_path: {rel_path}")
                seen.add(rel_path)
                source_rel = safe_relative(entry.get("path"), "manifest asset path")
                mirror_value = entry.get("bdsh_path")
                mirror_rel = (
                    safe_relative(mirror_value, "manifest bdsh_path")
                    if isinstance(mirror_value, str) and mirror_value.strip()
                    else None
                )
                result.append(
                    {
                        "moduleId": module_id,
                        "kind": str(entry.get("kind") or ""),
                        "relPath": rel_path,
                        "sourceRelPath": source_rel,
                        "mirrorRelPath": mirror_rel,
                    }
                )
    if not result:
        raise EvidenceError(f"no runtime assets selected for employee: {employee_id}")
    missing_filters = selected_rel_paths - seen
    if missing_filters:
        raise EvidenceError(f"requested rel_path not in employee closure: {sorted(missing_filters)}")
    return sorted(result, key=lambda item: item["relPath"])


def release_asset_map(
    fingerprint: dict[str, Any],
    employee_id: str,
    release_checks: list[dict[str, Any]],
    materialization_checks: list[dict[str, Any]],
) -> dict[str, dict[str, Any]]:
    if fingerprint.get("employeeId") != employee_id:
        raise EvidenceError("release fingerprint employeeId does not match the requested employee")
    remote = fingerprint.get("remote")
    local = fingerprint.get("local")
    integrity = fingerprint.get("assetIntegrity")
    release_identity_ok = (
        isinstance(remote, dict)
        and remote.get("source") == "custom"
        and remote.get("visible") is True
        and remote.get("enabled") is True
        and isinstance(remote.get("releaseId"), str)
        and bool(remote.get("releaseId"))
        and isinstance(remote.get("releaseManifestHash"), str)
        and bool(remote.get("releaseManifestHash"))
    )
    add_check(
        release_checks,
        "release.identity",
        "active_release",
        "equal" if release_identity_ok else "different",
        blocking=not release_identity_ok,
        detail="remote custom Release must be visible, enabled, and carry release/manifest identities",
    )
    materialization_ok = (
        release_identity_ok
        and isinstance(local, dict)
        and remote.get("releaseId") == local.get("releaseId")
        and remote.get("releaseManifestHash") == local.get("releaseManifestHash")
        and local.get("assetsSynced") is True
        and fingerprint.get("match") is True
        and fingerprint.get("matchBasis") == "release_manifest_hash"
        and isinstance(integrity, dict)
        and integrity.get("allMatch") is True
        and integrity.get("signaturesValid") is True
    )
    add_check(
        materialization_checks,
        "materialization.identity",
        "desktop_materialization",
        "equal" if materialization_ok else "different",
        blocking=not materialization_ok,
        detail="remote/local release and manifest, assetsSynced, match basis, asset hashes, and signatures must close",
    )
    assets = integrity.get("assets") if isinstance(integrity, dict) else None
    if not isinstance(assets, list):
        return {}
    result: dict[str, dict[str, Any]] = {}
    for item in assets:
        if not isinstance(item, dict) or not isinstance(item.get("path"), str):
            continue
        rel_path = safe_relative(item["path"], "release asset path").as_posix()
        if rel_path in result:
            raise EvidenceError(f"duplicate release asset path: {rel_path}")
        result[rel_path] = item
    return result


def snapshot_manifest_expectations(
    snapshot_root: Path,
    attested: dict[str, str],
) -> dict[str, str] | None:
    manifest_path = snapshot_root / SNAPSHOT_MANIFEST
    if not manifest_path.exists():
        return None
    manifest = checked_json(manifest_path, "runtime snapshot manifest")
    rows = manifest.get("files")
    if manifest.get("version") != 1 or not isinstance(rows, list) or not rows:
        raise EvidenceError("runtime snapshot manifest schema or files are invalid")
    expected: dict[str, str] = {}
    signature_rows: list[list[str]] = []
    for row in rows:
        if not isinstance(row, dict):
            raise EvidenceError("runtime snapshot manifest contains a non-object file row")
        local_rel = safe_relative(row.get("path"), "runtime snapshot manifest path")
        local_path = local_rel.as_posix()
        release_path = local_path if local_path in attested else f"runtime/{local_path}"
        digest = str(row.get("sha256") or "").lower()
        if (
            release_path not in attested
            or not HEX_SHA256.fullmatch(digest)
            or digest != attested[release_path]
        ):
            raise EvidenceError(
                f"runtime snapshot manifest has an unattested or invalid file: {local_path}"
            )
        if release_path in expected:
            raise EvidenceError(f"runtime snapshot manifest repeats a file: {local_path}")
        expected[release_path] = digest
        signature_rows.append([local_path, digest])
    expected_signature = json.dumps(
        signature_rows,
        ensure_ascii=False,
        separators=(",", ":"),
    )
    if manifest.get("signature") != expected_signature:
        raise EvidenceError("runtime snapshot manifest signature does not match its file list")
    return expected


def inspect_snapshot(
    batch_root_path: Path,
    employee_id: str,
    current_hashes: dict[str, str],
    policy: str,
    selected_rel_paths: set[str],
    checks: list[dict[str, Any]],
) -> tuple[dict[str, Any], bool, bool]:
    batch_root = checked_root(batch_root_path, "batch root")
    state_path = batch_root / "batch-state.json"
    batch_id = batch_root.name
    if state_path.exists():
        state = checked_json(state_path, "batch state")
        if state.get("employeeId") not in (None, employee_id):
            raise EvidenceError("batch-state employeeId does not match the requested employee")
        batch_id = str(state.get("batchId") or batch_id)
    snapshot_root = checked_root(batch_root / "runtime-snapshot", "runtime snapshot")
    attestation = checked_json(
        snapshot_root / ".yoodesk-fde-asset-attestations.json",
        "runtime snapshot attestation",
    )
    if attestation.get("schemaVersion") != 1 or attestation.get("employeeId") != employee_id:
        raise EvidenceError("runtime snapshot attestation identity or schema is invalid")
    rows = attestation.get("assets")
    if not isinstance(rows, list):
        raise EvidenceError("runtime snapshot attestation assets must be an array")
    attested: dict[str, str] = {}
    for row in rows:
        if not isinstance(row, dict):
            continue
        rel_path = safe_relative(row.get("path"), "snapshot attestation path").as_posix()
        digest = str(row.get("content_hash") or "").lower()
        if not HEX_SHA256.fullmatch(digest) or rel_path in attested:
            raise EvidenceError(f"runtime snapshot attestation has invalid asset: {rel_path}")
        attested[rel_path] = digest

    manifest_expectations = snapshot_manifest_expectations(snapshot_root, attested)
    operator_expectations: dict[str, str] = {}
    for raw_path in selected_rel_paths:
        rel_path = safe_relative(raw_path, "selected snapshot rel_path").as_posix()
        if rel_path not in attested:
            raise EvidenceError(f"selected snapshot path is not attested: {rel_path}")
        operator_expectations[rel_path] = attested[rel_path]
    if operator_expectations and manifest_expectations:
        if operator_expectations != manifest_expectations:
            raise EvidenceError(
                "selected snapshot paths do not match the runtime snapshot manifest"
            )
        expected_snapshot = operator_expectations
        completeness_evidence = "operator_list+snapshot_manifest"
    elif operator_expectations:
        expected_snapshot = operator_expectations
        completeness_evidence = "operator_list"
    elif manifest_expectations:
        expected_snapshot = manifest_expectations
        completeness_evidence = "snapshot_manifest"
    else:
        expected_snapshot = None
        completeness_evidence = "unverified"

    internal_errors: list[str] = []
    current_differences: list[str] = []
    actual_snapshot_paths: set[str] = set()
    inspected = 0
    for path in sorted(snapshot_root.rglob("*")):
        local_rel = path.relative_to(snapshot_root).as_posix()
        if path.is_symlink():
            internal_errors.append(f"symlink:{local_rel}")
            continue
        if local_rel in {
            ".yoodesk-fde-asset-attestations.json",
            SNAPSHOT_MANIFEST,
        }:
            continue
        if path.is_dir():
            continue
        if not path.is_file():
            internal_errors.append(f"unsupported:{local_rel}")
            continue
        release_rel = local_rel if local_rel in attested else f"runtime/{local_rel}"
        actual = sha256(path)
        expected = attested.get(release_rel)
        inspected += 1
        actual_snapshot_paths.add(release_rel)
        if expected is None or actual != expected:
            internal_errors.append(release_rel)
            continue
        if expected_snapshot is not None and expected_snapshot.get(release_rel) != actual:
            internal_errors.append(f"manifest:{release_rel}")
            continue
        current = current_hashes.get(release_rel)
        if current is None or current != actual:
            current_differences.append(release_rel)
    if inspected == 0:
        internal_errors.append("no runtime files")
    if expected_snapshot is not None:
        missing_paths = set(expected_snapshot) - actual_snapshot_paths
        extra_paths = actual_snapshot_paths - set(expected_snapshot)
        internal_errors.extend(f"missing:{path}" for path in sorted(missing_paths))
        internal_errors.extend(f"extra:{path}" for path in sorted(extra_paths))
    snapshot_summary = {
        "batchId": batch_id,
        "inspectedFiles": inspected,
        "differences": current_differences,
        "completenessEvidence": completeness_evidence,
    }
    if internal_errors:
        add_check(
            checks,
            "snapshot.integrity",
            "batch_snapshot",
            "invalid",
            blocking=True,
            detail=",".join(internal_errors[:20]),
        )
        snapshot_summary["differences"] = []
        return snapshot_summary, False, False
    snapshot_complete = expected_snapshot is not None
    add_check(
        checks,
        "snapshot.integrity",
        "batch_snapshot",
        "equal" if snapshot_complete else "unverified",
        detail=(
            f"complete snapshot file set proven by {completeness_evidence}"
            if snapshot_complete
            else "actual files match attestation, but the producer-selected file set is unverified"
        ),
    )
    if current_differences:
        historical = policy == "historical"
        add_check(
            checks,
            "snapshot.current_release",
            "batch_snapshot",
            "expected_historical" if historical else "different",
            blocking=not historical,
            detail=",".join(current_differences[:20]),
        )
        return snapshot_summary, historical, snapshot_complete
    add_check(checks, "snapshot.current_release", "batch_snapshot", "equal")
    return snapshot_summary, True, snapshot_complete


def build_report(args: argparse.Namespace) -> dict[str, Any]:
    if args.snapshot_rel_path and not args.batch_root:
        raise EvidenceError("--snapshot-rel-path requires --batch-root")
    checks: list[dict[str, Any]] = []
    environment_checks: list[dict[str, Any]] = []
    release_identity_checks: list[dict[str, Any]] = []
    materialization_identity_checks: list[dict[str, Any]] = []
    asset_root = checked_root(args.asset_root, "asset root")
    manifest = checked_json(args.manifest, "FDE manifest")
    selected = selected_assets(manifest, args.employee_id, set(args.rel_path))
    mirror_root = checked_root(args.bdsh_root, "bdsh root") if args.bdsh_root else None

    account_equal = endpoint_check(
        environment_checks,
        "account_url",
        args.expected_account_url,
        args.observed_account_url,
    )
    fde_equal = endpoint_check(
        environment_checks,
        "fde_url",
        args.expected_fde_url,
        args.observed_fde_url,
    )

    release_assets: dict[str, dict[str, Any]] = {}
    if args.release_fingerprint_json:
        release_assets = release_asset_map(
            checked_json(args.release_fingerprint_json, "release fingerprint"),
            args.employee_id,
            release_identity_checks,
            materialization_identity_checks,
        )
    else:
        add_check(
            release_identity_checks,
            "release.identity",
            "active_release",
            "unverified",
        )
        add_check(
            materialization_identity_checks,
            "materialization.identity",
            "desktop_materialization",
            "unverified",
        )

    assets: list[dict[str, Any]] = []
    current_hashes: dict[str, str] = {}
    all_mirrors_verified = True
    release_asset_set_verified = False
    all_active_release_assets_verified = bool(release_assets)
    all_materialized_assets_verified = bool(release_assets)
    for item in selected:
        source_path = checked_file(asset_root, item["sourceRelPath"], "authoritative source")
        source_hash = sha256(source_path)
        current_hashes[item["relPath"]] = source_hash
        mirror_result: dict[str, Any] | None = None
        mirror_rel = item["mirrorRelPath"]
        if mirror_rel is not None:
            if mirror_root is None:
                all_mirrors_verified = False
                mirror_result = {"status": "unverified", "relPath": mirror_rel.as_posix()}
            else:
                mirror_path = checked_optional_file(mirror_root, mirror_rel, "bdsh mirror")
                if mirror_path is None:
                    all_mirrors_verified = False
                    mirror_result = {
                        "status": "missing",
                        "relPath": mirror_rel.as_posix(),
                    }
                else:
                    mirror_hash = sha256(mirror_path)
                    equal = mirror_hash == source_hash
                    if not equal:
                        all_mirrors_verified = False
                    mirror_result = {
                        "status": "equal" if equal else "different",
                        "relPath": mirror_rel.as_posix(),
                        "sha256": mirror_hash,
                    }

        release = release_assets.get(item["relPath"])
        release_result: dict[str, Any] | None = None
        if release is not None:
            expected_hash = str(release.get("expectedHash") or "").lower()
            local_hash = str(release.get("localHash") or "").lower()
            active_release_equal = (
                HEX_SHA256.fullmatch(expected_hash) is not None
                and expected_hash == source_hash
            )
            materialization_equal = (
                HEX_SHA256.fullmatch(local_hash) is not None
                and local_hash == expected_hash
                and release.get("match") is True
                and release.get("signatureValid") is True
            )
            if not active_release_equal:
                all_active_release_assets_verified = False
            if not materialization_equal:
                all_materialized_assets_verified = False
            release_result = {
                "activeRelease": {
                    "status": "equal" if active_release_equal else "different",
                    "expectedHash": expected_hash or None,
                },
                "materialization": {
                    "status": "equal" if materialization_equal else "different",
                    "localHash": local_hash or None,
                    "signatureValid": release.get("signatureValid") is True,
                },
            }
        elif args.release_fingerprint_json:
            all_active_release_assets_verified = False
            all_materialized_assets_verified = False
            release_result = {
                "activeRelease": {"status": "missing"},
                "materialization": {"status": "missing"},
            }

        assets.append(
            {
                "moduleId": item["moduleId"],
                "kind": item["kind"],
                "relPath": item["relPath"],
                "source": {
                    "relPath": item["sourceRelPath"].as_posix(),
                    "sha256": source_hash,
                },
                "mirror": mirror_result,
                "releaseMaterialization": release_result,
            }
        )

    mirrored_assets = [item for item in selected if item["mirrorRelPath"] is not None]
    if not mirrored_assets:
        add_check(checks, "source.mirror", "source_mirror", "not_applicable")
    elif mirror_root is None:
        add_check(checks, "source.mirror", "source_mirror", "unverified")
    else:
        add_check(
            checks,
            "source.mirror",
            "source_mirror",
            "equal" if all_mirrors_verified else "different",
            blocking=not all_mirrors_verified,
        )

    checks.extend(environment_checks)
    checks.extend(release_identity_checks)

    selected_release_paths = {item["relPath"] for item in selected}
    if args.release_fingerprint_json:
        observed_release_paths = set(release_assets)
        missing_release_paths = selected_release_paths - observed_release_paths
        extra_release_paths = observed_release_paths - selected_release_paths
        detail_parts = []
        if missing_release_paths:
            detail_parts.append(f"missing={sorted(missing_release_paths)}")
        if extra_release_paths and not args.rel_path:
            detail_parts.append(f"extra={sorted(extra_release_paths)}")
        if missing_release_paths or (extra_release_paths and not args.rel_path):
            release_set_status = "different"
            release_set_blocking = True
        elif args.rel_path:
            release_set_status = "unverified"
            release_set_blocking = False
            detail_parts.append("scoped --rel-path inspection cannot close the full asset set")
        else:
            release_set_status = "equal"
            release_set_blocking = False
            release_asset_set_verified = True
        add_check(
            checks,
            "active_release.asset_set",
            "active_release",
            release_set_status,
            blocking=release_set_blocking,
            detail=" ".join(detail_parts),
        )
    else:
        add_check(
            checks,
            "active_release.asset_set",
            "active_release",
            "unverified",
        )

    if args.release_fingerprint_json:
        add_check(
            checks,
            "source.active_release",
            "active_release",
            "equal" if all_active_release_assets_verified else "different",
            blocking=not all_active_release_assets_verified,
        )
    else:
        add_check(
            checks,
            "source.active_release",
            "active_release",
            "unverified",
        )

    checks.extend(materialization_identity_checks)
    if args.release_fingerprint_json:
        add_check(
            checks,
            "active_release.materialization",
            "desktop_materialization",
            "equal" if all_materialized_assets_verified else "different",
            blocking=not all_materialized_assets_verified,
        )
    else:
        add_check(
            checks,
            "active_release.materialization",
            "desktop_materialization",
            "unverified",
        )

    snapshot: dict[str, Any] | None = None
    snapshot_current = False
    snapshot_complete = False
    if args.batch_root:
        snapshot, snapshot_current, snapshot_complete = inspect_snapshot(
            args.batch_root,
            args.employee_id,
            current_hashes,
            args.snapshot_policy,
            set(args.snapshot_rel_path),
            checks,
        )
    else:
        add_check(checks, "snapshot.current_release", "batch_snapshot", "unverified")

    required_check_ids = {
        "environment.account_url",
        "environment.fde_url",
        "release.identity",
        "active_release.asset_set",
        "source.active_release",
        "materialization.identity",
        "active_release.materialization",
    }
    if mirrored_assets:
        required_check_ids.add("source.mirror")
    if args.batch_root:
        required_check_ids.add("snapshot.integrity")
    if args.snapshot_policy == "fresh":
        required_check_ids.add("snapshot.current_release")
    incomplete_ids = [
        row["id"]
        for row in checks
        if row["id"] in required_check_ids and row["status"] == "unverified"
    ]
    blockers = [row for row in checks if row["blocking"]]
    status = "blocked" if blockers else "incomplete" if incomplete_ids else "pass"
    first_divergence = blockers[0]["id"] if blockers else None
    current_release_ready = (
        not blockers
        and all_mirrors_verified
        and release_asset_set_verified
        and all_active_release_assets_verified
        and all_materialized_assets_verified
        and account_equal
        and fde_equal
    )
    ready_for_fresh_batch = current_release_ready and (
        args.snapshot_policy != "fresh" or (snapshot_current and snapshot_complete)
    )
    historical_snapshot = any(
        row["id"] == "snapshot.current_release" and row["status"] == "expected_historical"
        for row in checks
    )
    return {
        "schema": REPORT_SCHEMA,
        "status": status,
        "employeeId": args.employee_id,
        "firstDivergence": first_divergence,
        "incompleteEvidence": incomplete_ids,
        "currentReleaseReady": current_release_ready,
        "readyForFreshBatch": ready_for_fresh_batch,
        "freshConversationRequired": current_release_ready,
        "freshBatchRequired": historical_snapshot,
        "snapshotPolicy": args.snapshot_policy,
        "checks": checks,
        "assets": assets,
        "snapshot": snapshot,
    }


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    try:
        report = build_report(args)
    except EvidenceError as exc:
        report = {
            "schema": REPORT_SCHEMA,
            "status": "blocked",
            "employeeId": args.employee_id,
            "firstDivergence": "evidence.invalid",
            "error": str(exc),
        }
    if args.json:
        print(json.dumps(report, ensure_ascii=False, indent=2, sort_keys=True))
    else:
        print(
            f"status={report['status']} employee={report['employeeId']} "
            f"first_divergence={report.get('firstDivergence') or 'none'}"
        )
        for row in report.get("checks", []):
            print(f"{row['status']:>19}  {row['id']}  {row.get('detail', '')}".rstrip())
    if report["status"] == "blocked":
        return 1
    if report["status"] == "incomplete" and args.require_complete:
        return 2
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
