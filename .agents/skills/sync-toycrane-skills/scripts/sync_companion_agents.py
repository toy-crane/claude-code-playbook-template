#!/usr/bin/env python3
"""Reconcile Toycrane skill companion agents into Claude Code and Codex."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import sys
import tempfile
from dataclasses import dataclass
from pathlib import Path
from typing import Any

TOYCRANE_SOURCE = "toy-crane/skills"
SKILLS_LOCK = Path("skills-lock.json")
AGENT_LOCK = Path(".agents/toycrane-agents-lock.json")
AGENT_SYNC_MANIFEST = Path(".agent-sync/manifest.json")
NAME_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")


class SyncError(RuntimeError):
    pass


@dataclass(frozen=True)
class CompanionAgent:
    name: str
    skill: str
    claude_source: Path
    codex_source: Path

    def source_for(self, client: str) -> Path:
        return self.claude_source if client == "claude" else self.codex_source

    def target_for(self, project: Path, client: str) -> Path:
        if client == "claude":
            return project / ".claude" / "agents" / f"{self.name}.md"
        return project / ".codex" / "agents" / f"{self.name}.toml"


def read_json(path: Path, *, required: bool = True) -> dict[str, Any]:
    if not path.exists():
        if required:
            raise SyncError(f"Missing required file: {path}")
        return {}
    try:
        value = json.loads(path.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError) as error:
        raise SyncError(f"Cannot read JSON from {path}: {error}") from error
    if not isinstance(value, dict):
        raise SyncError(f"Expected a JSON object in {path}")
    return value


def atomic_write_bytes(path: Path, content: bytes) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temp_name = tempfile.mkstemp(prefix=f".{path.name}.", dir=path.parent)
    try:
        with os.fdopen(descriptor, "wb") as handle:
            handle.write(content)
        os.chmod(temp_name, 0o644)
        os.replace(temp_name, path)
    except BaseException:
        Path(temp_name).unlink(missing_ok=True)
        raise


def atomic_write_text(path: Path, content: str) -> None:
    atomic_write_bytes(path, content.encode("utf-8"))


def json_text(value: object) -> str:
    return json.dumps(value, indent=2, ensure_ascii=False) + "\n"


def require_project_local_path(project: Path, path: Path) -> None:
    resolved_path = path.resolve(strict=False)
    try:
        resolved_path.relative_to(project)
    except ValueError as error:
        raise SyncError(
            "Companion-agent path escapes project: "
            f"{path.relative_to(project).as_posix()} -> {resolved_path}"
        ) from error


def relative_source(companion_dir: Path, value: object, label: str) -> Path:
    if not isinstance(value, str) or not value:
        raise SyncError(f"Companion agent {label} must be a non-empty path")
    source = companion_dir / value
    try:
        source.resolve().relative_to(companion_dir.resolve())
    except ValueError as error:
        raise SyncError(f"Companion agent {label} escapes {companion_dir}") from error
    if not source.is_file():
        raise SyncError(f"Missing companion agent source: {source}")
    return source


def discover_agents(project: Path) -> tuple[dict[str, CompanionAgent], set[str]]:
    skills_lock = read_json(project / SKILLS_LOCK)
    if skills_lock.get("version") != 1:
        raise SyncError(f"Unsupported skills lock: {project / SKILLS_LOCK}")
    skill_entries = skills_lock.get("skills")
    if not isinstance(skill_entries, dict):
        raise SyncError(f"Expected a skills object in {project / SKILLS_LOCK}")

    discovered: dict[str, CompanionAgent] = {}
    managed_skills: set[str] = set()
    for skill_name, entry in sorted(skill_entries.items()):
        if not isinstance(entry, dict) or entry.get("source") != TOYCRANE_SOURCE:
            continue
        managed_skills.add(skill_name)
        skill_dir = project / ".agents" / "skills" / skill_name
        if not skill_dir.is_dir():
            raise SyncError(f"Missing managed skill directory: {skill_dir}")
        companion_dir = skill_dir / "companion-agents"
        manifest_path = companion_dir / "manifest.json"
        if not manifest_path.exists():
            continue
        manifest = read_json(manifest_path)
        if manifest.get("version") != 1 or not isinstance(manifest.get("agents"), list):
            raise SyncError(f"Unsupported companion manifest: {manifest_path}")
        for raw_agent in manifest["agents"]:
            if not isinstance(raw_agent, dict):
                raise SyncError(f"Invalid companion agent entry in {manifest_path}")
            name = raw_agent.get("name")
            if not isinstance(name, str) or not NAME_PATTERN.fullmatch(name):
                raise SyncError(
                    f"Invalid companion agent name in {manifest_path}: {name!r}"
                )
            if name in discovered:
                raise SyncError(
                    f"Duplicate companion agent {name!r} in {skill_name!r} and "
                    f"{discovered[name].skill!r}"
                )
            discovered[name] = CompanionAgent(
                name=name,
                skill=skill_name,
                claude_source=relative_source(
                    companion_dir, raw_agent.get("claude"), f"{name}.claude"
                ),
                codex_source=relative_source(
                    companion_dir, raw_agent.get("codex"), f"{name}.codex"
                ),
            )
    return discovered, managed_skills


def sha256(content: bytes) -> str:
    return hashlib.sha256(content).hexdigest()


def claude_agent_name(content: bytes) -> str | None:
    try:
        lines = content.decode("utf-8").splitlines()
    except UnicodeDecodeError:
        return None
    if not lines or lines[0].strip() != "---":
        return None
    try:
        closing_index = next(
            index
            for index, line in enumerate(lines[1:], start=1)
            if line.strip() == "---"
        )
    except StopIteration:
        return None
    for line in lines[1:closing_index]:
        key, separator, raw_value = line.partition(":")
        if not separator or key.strip() != "name":
            continue
        value = raw_value.strip()
        if len(value) >= 2 and value[0] == value[-1] and value[0] in {'"', "'"}:
            value = value[1:-1]
        else:
            value = value.split(" #", 1)[0].strip()
        return value if NAME_PATTERN.fullmatch(value) else None
    return None


def codex_agent_name(content: bytes) -> str | None:
    try:
        lines = content.decode("utf-8").splitlines()
    except UnicodeDecodeError:
        return None
    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue
        if stripped.startswith("["):
            return None
        match = re.fullmatch(
            r"name\s*=\s*([\"'])([a-z0-9]+(?:-[a-z0-9]+)*)\1\s*(?:#.*)?",
            stripped,
        )
        if match:
            return match.group(2)
    return None


def native_agent_name(content: bytes, client: str) -> str | None:
    return (
        claude_agent_name(content) if client == "claude" else codex_agent_name(content)
    )


def read_source_contents(
    agents: dict[str, CompanionAgent],
) -> dict[tuple[str, str], bytes]:
    contents: dict[tuple[str, str], bytes] = {}
    for name, agent in sorted(agents.items()):
        for client in ("claude", "codex"):
            source = agent.source_for(client)
            content = source.read_bytes()
            try:
                content.decode("utf-8")
            except UnicodeDecodeError as error:
                raise SyncError(
                    f"Companion agent source is not UTF-8: {source}"
                ) from error
            declared_name = native_agent_name(content, client)
            if declared_name != name:
                raise SyncError(
                    f"Companion agent name in {source} does not match manifest "
                    f"name {name!r}: {declared_name!r}"
                )
            contents[(name, client)] = content
    return contents


def expected_lock(
    project: Path,
    agents: dict[str, CompanionAgent],
    source_contents: dict[tuple[str, str], bytes] | None = None,
) -> dict[str, Any]:
    entries: dict[str, Any] = {}
    for name, agent in sorted(agents.items()):
        targets: dict[str, Any] = {}
        for client in ("claude", "codex"):
            source_content = (
                source_contents[(name, client)]
                if source_contents is not None
                else agent.source_for(client).read_bytes()
            )
            target = agent.target_for(project, client)
            targets[client] = {
                "path": target.relative_to(project).as_posix(),
                "sha256": sha256(source_content),
            }
        entries[name] = {"skill": agent.skill, "targets": targets}
    return {"version": 1, "source": TOYCRANE_SOURCE, "agents": entries}


def read_agent_lock(project: Path) -> dict[str, Any]:
    path = project / AGENT_LOCK
    lock = read_json(path, required=False)
    if not lock:
        return {"version": 1, "source": TOYCRANE_SOURCE, "agents": {}}
    if (
        lock.get("version") != 1
        or lock.get("source") != TOYCRANE_SOURCE
        or not isinstance(lock.get("agents"), dict)
    ):
        raise SyncError(f"Unsupported companion-agent lock: {path}")
    for name, entry in lock["agents"].items():
        if not isinstance(name, str) or not NAME_PATTERN.fullmatch(name):
            raise SyncError(f"Invalid managed agent name in {path}: {name!r}")
        if not isinstance(entry, dict):
            raise SyncError(f"Invalid managed agent entry in {path}: {name!r}")
    return lock


def declared_agent_names(manifest: dict[str, Any]) -> set[str]:
    names: set[str] = set()
    for key in ("shared_agents", "claude_only_agents", "codex_only_agents"):
        values = manifest.get(key, [])
        if not isinstance(values, list) or not all(
            isinstance(value, str) for value in values
        ):
            raise SyncError(f"Expected {key} array in {AGENT_SYNC_MANIFEST.as_posix()}")
        names.update(values)
    return names


def native_identity_paths(
    project: Path,
    desired_names: set[str],
) -> dict[str, set[Path]]:
    paths_by_name = {name: set() for name in desired_names}
    layouts = (
        ("claude", project / ".claude" / "agents", ".md"),
        ("codex", project / ".codex" / "agents", ".toml"),
    )
    for client, directory, suffix in layouts:
        if not os.path.lexists(directory):
            continue
        require_project_local_path(project, directory)
        if not directory.is_dir():
            raise SyncError(
                "Native agent directory is not a directory: "
                f"{directory.relative_to(project).as_posix()}"
            )
        for path in sorted(directory.glob(f"*{suffix}")):
            require_project_local_path(project, path)
            if not path.is_file():
                continue
            name = native_agent_name(path.read_bytes(), client)
            if name in paths_by_name:
                paths_by_name[name].add(path)
    return paths_by_name


def reject_unowned_collisions(
    project: Path,
    agents: dict[str, CompanionAgent],
    old_lock: dict[str, Any],
    adopted_names: set[str],
) -> set[Path]:
    owned_names = set(old_lock["agents"])
    manifest_path = project / AGENT_SYNC_MANIFEST
    manifest_names = (
        declared_agent_names(read_json(manifest_path))
        if manifest_path.exists()
        else set()
    )
    identity_paths = native_identity_paths(project, set(agents))
    collisions: list[str] = []
    adopted_alternate_paths: set[Path] = set()
    for name, agent in agents.items():
        canonical_paths = {
            agent.target_for(project, client) for client in ("claude", "codex")
        }
        alternate_paths = identity_paths[name] - canonical_paths
        paths: list[str] = []
        if alternate_paths:
            if name in adopted_names:
                adopted_alternate_paths.update(alternate_paths)
            else:
                paths.extend(
                    path.relative_to(project).as_posix()
                    for path in sorted(alternate_paths)
                )
        if name not in owned_names and name not in adopted_names:
            paths.extend(
                target.relative_to(project).as_posix()
                for target in sorted(canonical_paths)
                if os.path.lexists(target)
            )
            if name in manifest_names:
                paths.append(f"{AGENT_SYNC_MANIFEST.as_posix()}:{name}")
        if paths:
            collisions.append(f"{name}: {', '.join(paths)}")
    if collisions:
        detail = "; ".join(collisions)
        raise SyncError(
            "Unowned companion-agent collision; explicit adoption is required: "
            f"{detail}"
        )
    return adopted_alternate_paths


def desired_shared_manifest(
    manifest: dict[str, Any],
    desired_names: set[str],
    retired_names: set[str],
    desired_skills: set[str],
    retired_skills: set[str],
) -> dict[str, Any]:
    shared_skills = manifest.get("shared_skills", [])
    if not isinstance(shared_skills, list) or not all(
        isinstance(name, str) for name in shared_skills
    ):
        raise SyncError(
            f"Expected shared_skills array in {AGENT_SYNC_MANIFEST.as_posix()}"
        )
    shared_agents = manifest.get("shared_agents")
    if not isinstance(shared_agents, list) or not all(
        isinstance(name, str) for name in shared_agents
    ):
        raise SyncError(
            f"Expected shared_agents array in {AGENT_SYNC_MANIFEST.as_posix()}"
        )
    updated = dict(manifest)
    updated["shared_skills"] = sorted(
        (set(shared_skills) - retired_skills) | desired_skills
    )
    updated["shared_agents"] = sorted(
        (set(shared_agents) - retired_names) | desired_names
    )
    for key in ("claude_only_agents", "codex_only_agents"):
        values = manifest.get(key, [])
        if not isinstance(values, list) or not all(
            isinstance(name, str) for name in values
        ):
            raise SyncError(f"Expected {key} array in {AGENT_SYNC_MANIFEST.as_posix()}")
        updated[key] = [
            name for name in values if name not in desired_names | retired_names
        ]
    return updated


def check(
    project: Path,
    agents: dict[str, CompanionAgent],
    managed_skills: set[str],
    retired_skills: set[str],
) -> list[str]:
    drift: list[str] = []
    source_contents = read_source_contents(agents)
    expected = expected_lock(project, agents, source_contents)
    lock_path = project / AGENT_LOCK
    require_project_local_path(project, lock_path)
    actual_lock = read_agent_lock(project)
    retired_names = set(actual_lock["agents"]) - set(agents)
    if agents:
        if actual_lock != expected:
            drift.append(f"{AGENT_LOCK.as_posix()} does not match installed companions")
    elif lock_path.exists():
        drift.append(f"{AGENT_LOCK.as_posix()} should be retired")

    for agent in agents.values():
        for client in ("claude", "codex"):
            target = agent.target_for(project, client)
            require_project_local_path(project, target)
            expected_content = source_contents[(agent.name, client)]
            if not target.is_file() or target.read_bytes() != expected_content:
                drift.append(
                    f"{target.relative_to(project).as_posix()} is missing or stale"
                )

    identity_paths = native_identity_paths(project, set(agents))
    for name, agent in sorted(agents.items()):
        canonical_paths = {
            agent.target_for(project, client) for client in ("claude", "codex")
        }
        for path in sorted(identity_paths[name] - canonical_paths):
            drift.append(
                f"{path.relative_to(project).as_posix()} declares duplicate native "
                f"identity {name}"
            )

    manifest_path = project / AGENT_SYNC_MANIFEST
    if manifest_path.exists():
        require_project_local_path(project, manifest_path)
        manifest = read_json(manifest_path)
        expected_manifest = desired_shared_manifest(
            manifest,
            set(agents),
            retired_names,
            managed_skills,
            retired_skills,
        )
        if manifest != expected_manifest:
            drift.append(
                f"{AGENT_SYNC_MANIFEST.as_posix()} is missing managed skills or agents"
            )
    return drift


def apply(
    project: Path,
    agents: dict[str, CompanionAgent],
    managed_skills: set[str],
    retired_skills: set[str],
    adopted_names: set[str],
) -> list[str]:
    changes: list[str] = []
    require_project_local_path(project, project / AGENT_LOCK)
    for agent in agents.values():
        for client in ("claude", "codex"):
            require_project_local_path(project, agent.target_for(project, client))

    old_lock = read_agent_lock(project)
    retired_names = set(old_lock["agents"]) - set(agents)
    manifest_path = project / AGENT_SYNC_MANIFEST
    manifest: dict[str, Any] | None = None
    updated_manifest: dict[str, Any] | None = None
    if manifest_path.exists():
        require_project_local_path(project, manifest_path)
        manifest = read_json(manifest_path)
        updated_manifest = desired_shared_manifest(
            manifest,
            set(agents),
            retired_names,
            managed_skills,
            retired_skills,
        )

    source_contents = read_source_contents(agents)
    adopted_alternate_paths = reject_unowned_collisions(
        project, agents, old_lock, adopted_names
    )
    target_paths = [
        agent.target_for(project, client)
        for agent in agents.values()
        for client in ("claude", "codex")
    ]
    target_paths.extend(
        project / relative_path
        for name in retired_names
        for relative_path in (
            Path(".claude/agents") / f"{name}.md",
            Path(".codex/agents") / f"{name}.toml",
        )
    )
    target_paths.extend(adopted_alternate_paths)
    for target in target_paths:
        require_project_local_path(project, target)
        if target.is_dir() and not target.is_symlink():
            raise SyncError(
                "Companion agent target is a directory: "
                f"{target.relative_to(project).as_posix()}"
            )

    final_lock = expected_lock(project, agents, source_contents)
    recovery_entries = dict(final_lock["agents"])
    for name in retired_names:
        recovery_entries[name] = old_lock["agents"][name]
    recovery_lock = {
        "version": 1,
        "source": TOYCRANE_SOURCE,
        "agents": dict(sorted(recovery_entries.items())),
    }

    for name in sorted(retired_names):
        for relative_path in (
            Path(".claude/agents") / f"{name}.md",
            Path(".codex/agents") / f"{name}.toml",
        ):
            target = project / relative_path
            if os.path.lexists(target):
                target.unlink()
                changes.append(f"remove {relative_path.as_posix()}")

    lock_path = project / AGENT_LOCK
    wrote_recovery_lock = False
    if recovery_entries and (not lock_path.exists() or old_lock != recovery_lock):
        atomic_write_text(lock_path, json_text(recovery_lock))
        wrote_recovery_lock = True

    for target in sorted(adopted_alternate_paths):
        if os.path.lexists(target):
            target.unlink()
            changes.append(f"remove {target.relative_to(project).as_posix()}")

    for name, agent in sorted(agents.items()):
        for client in ("claude", "codex"):
            target = agent.target_for(project, client)
            content = source_contents[(name, client)]
            if (
                target.is_file()
                and not target.is_symlink()
                and target.read_bytes() == content
            ):
                continue
            atomic_write_bytes(target, content)
            changes.append(f"write {target.relative_to(project).as_posix()}")

    if updated_manifest is not None and updated_manifest != manifest:
        atomic_write_text(manifest_path, json_text(updated_manifest))
        changes.append(f"update {AGENT_SYNC_MANIFEST.as_posix()}")

    if final_lock["agents"]:
        if recovery_lock != final_lock:
            atomic_write_text(lock_path, json_text(final_lock))
            changes.append(f"write {AGENT_LOCK.as_posix()}")
        elif wrote_recovery_lock:
            changes.append(f"write {AGENT_LOCK.as_posix()}")
    elif lock_path.exists():
        lock_path.unlink()
        changes.append(f"remove {AGENT_LOCK.as_posix()}")
    return changes


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Reconcile Toycrane companion agents for Claude Code and Codex."
    )
    parser.add_argument(
        "--project",
        type=Path,
        default=Path.cwd(),
        help="Target project root (default: current directory)",
    )
    parser.add_argument(
        "--check",
        action="store_true",
        help="Report drift without changing files",
    )
    parser.add_argument(
        "--adopt",
        action="append",
        default=[],
        metavar="NAME",
        help="Explicitly adopt and replace one unowned colliding agent name",
    )
    parser.add_argument(
        "--retired-skill",
        action="append",
        default=[],
        metavar="NAME",
        help="Remove one retired Toycrane skill from an optional shared manifest",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    project = args.project.resolve()
    try:
        agents, managed_skills = discover_agents(project)
        adopted_names = set(args.adopt)
        retired_skills = set(args.retired_skill)
        invalid_retired_skills = {
            name for name in retired_skills if not NAME_PATTERN.fullmatch(name)
        }
        if invalid_retired_skills:
            raise SyncError(
                "Invalid retired skill names: "
                + ", ".join(sorted(invalid_retired_skills))
            )
        unknown_adoptions = adopted_names - set(agents)
        if unknown_adoptions:
            raise SyncError(
                "Cannot adopt unpublished companion agents: "
                + ", ".join(sorted(unknown_adoptions))
            )
        if args.check and adopted_names:
            raise SyncError("--adopt cannot be combined with --check")
        if args.check:
            drift = check(project, agents, managed_skills, retired_skills)
            if drift:
                for item in drift:
                    print(f"DRIFT {item}")
                return 1
            print("Companion agents are in sync")
            return 0

        changes = apply(
            project,
            agents,
            managed_skills,
            retired_skills,
            adopted_names,
        )
        if changes:
            for item in changes:
                print(item)
        else:
            print("Companion agents are already in sync")
        return 0
    except (SyncError, OSError, UnicodeError) as error:
        print(f"error: {error}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(main())
