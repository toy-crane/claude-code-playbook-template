import json
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "sync_companion_agents.py"
CLAUDE_AGENT = "---\nname: expo-smoke-runner\n---\nclaude agent\n"


class SyncCompanionAgentsTest(unittest.TestCase):
    def setUp(self) -> None:
        self.temp_dir = tempfile.TemporaryDirectory()
        self.project = Path(self.temp_dir.name)

    def tearDown(self) -> None:
        self.temp_dir.cleanup()

    def write_text(self, relative_path: str, content: str) -> None:
        path = self.project / relative_path
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content, encoding="utf-8")

    def write_json(self, relative_path: str, value: object) -> None:
        self.write_text(relative_path, json.dumps(value, indent=2) + "\n")

    def add_managed_companion_skill(self) -> None:
        self.write_json(
            "skills-lock.json",
            {
                "version": 1,
                "skills": {
                    "expo-smoke-test": {
                        "source": "toy-crane/skills",
                        "sourceType": "github",
                    }
                },
            },
        )
        self.write_json(
            ".agents/skills/expo-smoke-test/companion-agents/manifest.json",
            {
                "version": 1,
                "agents": [
                    {
                        "name": "expo-smoke-runner",
                        "claude": "claude/expo-smoke-runner.md",
                        "codex": "codex/expo-smoke-runner.toml",
                    }
                ],
            },
        )
        self.write_text(
            ".agents/skills/expo-smoke-test/companion-agents/claude/expo-smoke-runner.md",
            CLAUDE_AGENT,
        )
        self.write_text(
            ".agents/skills/expo-smoke-test/companion-agents/codex/expo-smoke-runner.toml",
            'name = "expo-smoke-runner"\n',
        )

    def run_sync(self, *args: str) -> subprocess.CompletedProcess[str]:
        return subprocess.run(
            [sys.executable, str(SCRIPT), "--project", str(self.project), *args],
            check=False,
            capture_output=True,
            text=True,
        )

    def test_installs_both_native_agent_formats_and_updates_shared_manifest(
        self,
    ) -> None:
        self.add_managed_companion_skill()
        self.write_json(
            ".agent-sync/manifest.json",
            {
                "shared_skills": ["local-skill"],
                "shared_agents": ["local-reviewer"],
                "claude_only_agents": [],
                "codex_only_agents": [],
                "custom_field": {"preserved": True},
            },
        )

        result = self.run_sync()

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            (self.project / ".claude/agents/expo-smoke-runner.md").read_text(),
            CLAUDE_AGENT,
        )
        self.assertEqual(
            (self.project / ".codex/agents/expo-smoke-runner.toml").read_text(),
            'name = "expo-smoke-runner"\n',
        )

        agent_lock = json.loads(
            (self.project / ".agents/toycrane-agents-lock.json").read_text()
        )
        self.assertEqual(agent_lock["version"], 1)
        self.assertEqual(agent_lock["source"], "toy-crane/skills")
        self.assertEqual(
            agent_lock["agents"]["expo-smoke-runner"]["skill"],
            "expo-smoke-test",
        )

        shared_manifest = json.loads(
            (self.project / ".agent-sync/manifest.json").read_text()
        )
        self.assertEqual(
            shared_manifest["shared_agents"],
            ["expo-smoke-runner", "local-reviewer"],
        )
        self.assertEqual(shared_manifest["custom_field"], {"preserved": True})

        check_result = self.run_sync("--check")
        self.assertEqual(check_result.returncode, 0, check_result.stderr)
        self.assertIn("Companion agents are in sync", check_result.stdout)

    def test_refuses_an_unowned_name_collision_without_partial_writes(self) -> None:
        self.add_managed_companion_skill()
        self.write_text(
            ".claude/agents/expo-smoke-runner.md",
            "project-owned agent\n",
        )

        result = self.run_sync()

        self.assertEqual(result.returncode, 2)
        self.assertIn("collision", result.stderr.lower())
        self.assertEqual(
            (self.project / ".claude/agents/expo-smoke-runner.md").read_text(),
            "project-owned agent\n",
        )
        self.assertFalse(
            (self.project / ".codex/agents/expo-smoke-runner.toml").exists()
        )
        self.assertFalse((self.project / ".agents/toycrane-agents-lock.json").exists())

    def test_explicit_adoption_replaces_a_collision_and_declares_it_shared(
        self,
    ) -> None:
        self.add_managed_companion_skill()
        self.write_text(
            ".claude/agents/expo-smoke-runner.md",
            "old claude agent\n",
        )
        self.write_text(
            ".codex/agents/expo-smoke-runner.toml",
            "old codex agent\n",
        )
        self.write_json(
            ".agent-sync/manifest.json",
            {
                "shared_agents": ["local-reviewer"],
                "claude_only_agents": ["expo-smoke-runner"],
                "codex_only_agents": [],
            },
        )

        result = self.run_sync("--adopt", "expo-smoke-runner")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(
            (self.project / ".claude/agents/expo-smoke-runner.md").read_text(),
            CLAUDE_AGENT,
        )
        self.assertEqual(
            (self.project / ".codex/agents/expo-smoke-runner.toml").read_text(),
            'name = "expo-smoke-runner"\n',
        )
        shared_manifest = json.loads(
            (self.project / ".agent-sync/manifest.json").read_text()
        )
        self.assertEqual(
            shared_manifest["shared_agents"],
            ["expo-smoke-runner", "local-reviewer"],
        )
        self.assertEqual(shared_manifest["claude_only_agents"], [])

    def test_retires_only_previously_managed_agents(self) -> None:
        self.add_managed_companion_skill()
        self.write_json(
            ".agent-sync/manifest.json",
            {
                "shared_skills": ["local-skill"],
                "shared_agents": ["local-reviewer"],
                "claude_only_agents": [],
                "codex_only_agents": [],
            },
        )
        first_result = self.run_sync()
        self.assertEqual(first_result.returncode, 0, first_result.stderr)
        self.write_text(".claude/agents/local-reviewer.md", "local claude agent\n")
        self.write_text(".codex/agents/local-reviewer.toml", "local codex agent\n")
        self.write_json("skills-lock.json", {"version": 1, "skills": {}})
        shutil.rmtree(self.project / ".agents/skills/expo-smoke-test")

        result = self.run_sync("--retired-skill", "expo-smoke-test")

        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertFalse(
            (self.project / ".claude/agents/expo-smoke-runner.md").exists()
        )
        self.assertFalse(
            (self.project / ".codex/agents/expo-smoke-runner.toml").exists()
        )
        self.assertFalse((self.project / ".agents/toycrane-agents-lock.json").exists())
        self.assertEqual(
            (self.project / ".claude/agents/local-reviewer.md").read_text(),
            "local claude agent\n",
        )
        self.assertEqual(
            (self.project / ".codex/agents/local-reviewer.toml").read_text(),
            "local codex agent\n",
        )
        shared_manifest = json.loads(
            (self.project / ".agent-sync/manifest.json").read_text()
        )
        self.assertEqual(shared_manifest["shared_skills"], ["local-skill"])
        self.assertEqual(shared_manifest["shared_agents"], ["local-reviewer"])

        check_result = self.run_sync("--check")
        self.assertEqual(check_result.returncode, 0, check_result.stderr)

    def test_check_reports_drift_and_apply_refreshes_managed_agents(self) -> None:
        self.add_managed_companion_skill()
        first_result = self.run_sync()
        self.assertEqual(first_result.returncode, 0, first_result.stderr)
        self.write_text(
            ".agents/skills/expo-smoke-test/companion-agents/claude/expo-smoke-runner.md",
            "---\nname: expo-smoke-runner\n---\nclaude agent v2\n",
        )

        check_result = self.run_sync("--check")

        self.assertEqual(check_result.returncode, 1)
        self.assertIn(
            ".claude/agents/expo-smoke-runner.md is missing or stale",
            check_result.stdout,
        )

        apply_result = self.run_sync()
        self.assertEqual(apply_result.returncode, 0, apply_result.stderr)
        self.assertEqual(
            (self.project / ".claude/agents/expo-smoke-runner.md").read_text(),
            "---\nname: expo-smoke-runner\n---\nclaude agent v2\n",
        )

    def test_invalid_shared_manifest_fails_before_any_write(self) -> None:
        self.add_managed_companion_skill()
        self.write_json(
            ".agent-sync/manifest.json",
            {
                "claude_only_agents": [],
                "codex_only_agents": [],
            },
        )

        result = self.run_sync()

        self.assertEqual(result.returncode, 2)
        self.assertIn("shared_agents", result.stderr)
        self.assertFalse(
            (self.project / ".claude/agents/expo-smoke-runner.md").exists()
        )
        self.assertFalse(
            (self.project / ".codex/agents/expo-smoke-runner.toml").exists()
        )
        self.assertFalse((self.project / ".agents/toycrane-agents-lock.json").exists())

    def test_missing_managed_skill_fails_without_retiring_its_agent(self) -> None:
        self.add_managed_companion_skill()
        first_result = self.run_sync()
        self.assertEqual(first_result.returncode, 0, first_result.stderr)
        shutil.rmtree(self.project / ".agents/skills/expo-smoke-test")

        result = self.run_sync()

        self.assertEqual(result.returncode, 2)
        self.assertIn("Missing managed skill directory", result.stderr)
        self.assertTrue(
            (self.project / ".claude/agents/expo-smoke-runner.md").is_file()
        )
        self.assertTrue(
            (self.project / ".codex/agents/expo-smoke-runner.toml").is_file()
        )
        self.assertTrue((self.project / ".agents/toycrane-agents-lock.json").is_file())

    def test_rejects_agent_directory_symlinks_that_escape_the_project(self) -> None:
        self.add_managed_companion_skill()
        with tempfile.TemporaryDirectory() as outside_directory:
            claude_directory = self.project / ".claude"
            claude_directory.mkdir(parents=True)
            (claude_directory / "agents").symlink_to(
                outside_directory,
                target_is_directory=True,
            )

            result = self.run_sync()

            self.assertEqual(result.returncode, 2)
            self.assertIn("escapes project", result.stderr)
            self.assertFalse(
                (Path(outside_directory) / "expo-smoke-runner.md").exists()
            )
            self.assertFalse(
                (self.project / ".codex/agents/expo-smoke-runner.toml").exists()
            )
            self.assertFalse(
                (self.project / ".agents/toycrane-agents-lock.json").exists()
            )

    def test_declares_current_managed_skills_in_the_shared_manifest(self) -> None:
        self.add_managed_companion_skill()
        self.write_json(
            ".agent-sync/manifest.json",
            {
                "shared_skills": ["local-skill"],
                "shared_agents": ["local-reviewer"],
                "claude_only_agents": [],
                "codex_only_agents": [],
            },
        )

        result = self.run_sync()

        self.assertEqual(result.returncode, 0, result.stderr)
        shared_manifest = json.loads(
            (self.project / ".agent-sync/manifest.json").read_text()
        )
        self.assertEqual(
            shared_manifest["shared_skills"],
            ["expo-smoke-test", "local-skill"],
        )

    def test_partial_write_failure_is_owned_and_recovers_without_adoption(self) -> None:
        self.add_managed_companion_skill()
        codex_agents = self.project / ".codex/agents"
        codex_agents.mkdir(parents=True)
        codex_agents.chmod(0o500)
        try:
            failed_result = self.run_sync()
        finally:
            codex_agents.chmod(0o700)

        self.assertEqual(failed_result.returncode, 2)
        self.assertTrue(
            (self.project / ".claude/agents/expo-smoke-runner.md").is_file()
        )
        recovery_lock = json.loads(
            (self.project / ".agents/toycrane-agents-lock.json").read_text()
        )
        self.assertIn("expo-smoke-runner", recovery_lock["agents"])

        recovered_result = self.run_sync()

        self.assertEqual(recovered_result.returncode, 0, recovered_result.stderr)
        self.assertTrue(
            (self.project / ".codex/agents/expo-smoke-runner.toml").is_file()
        )
        check_result = self.run_sync("--check")
        self.assertEqual(check_result.returncode, 0, check_result.stderr)

    def test_native_name_collision_requires_adoption_and_removes_alternate_path(
        self,
    ) -> None:
        self.add_managed_companion_skill()
        claude_alternate = self.project / ".claude/agents/local-name.md"
        codex_alternate = self.project / ".codex/agents/local-name.toml"
        self.write_text(
            ".claude/agents/local-name.md",
            "---\nname: expo-smoke-runner\n---\nproject-owned agent\n",
        )
        self.write_text(
            ".codex/agents/local-name.toml",
            'name = "expo-smoke-runner"\ndeveloper_instructions = "project owned"\n',
        )

        collision_result = self.run_sync()

        self.assertEqual(collision_result.returncode, 2)
        self.assertIn("local-name.md", collision_result.stderr)
        self.assertIn("local-name.toml", collision_result.stderr)
        self.assertTrue(claude_alternate.is_file())
        self.assertTrue(codex_alternate.is_file())
        self.assertFalse(
            (self.project / ".claude/agents/expo-smoke-runner.md").exists()
        )

        adopted_result = self.run_sync("--adopt", "expo-smoke-runner")

        self.assertEqual(adopted_result.returncode, 0, adopted_result.stderr)
        self.assertFalse(claude_alternate.exists())
        self.assertFalse(codex_alternate.exists())
        self.assertEqual(
            (self.project / ".claude/agents/expo-smoke-runner.md").read_text(),
            CLAUDE_AGENT,
        )

    def test_rejects_a_bundled_native_name_that_differs_from_the_manifest(
        self,
    ) -> None:
        self.add_managed_companion_skill()
        self.write_text(
            ".agents/skills/expo-smoke-test/companion-agents/claude/expo-smoke-runner.md",
            "---\nname: wrong-runner\n---\nwrong agent\n",
        )

        result = self.run_sync()

        self.assertEqual(result.returncode, 2)
        self.assertIn("does not match manifest", result.stderr)
        self.assertFalse(
            (self.project / ".claude/agents/expo-smoke-runner.md").exists()
        )
        self.assertFalse(
            (self.project / ".codex/agents/expo-smoke-runner.toml").exists()
        )
        self.assertFalse((self.project / ".agents/toycrane-agents-lock.json").exists())

    def test_check_reports_an_alternate_path_with_a_duplicate_native_name(
        self,
    ) -> None:
        self.add_managed_companion_skill()
        first_result = self.run_sync()
        self.assertEqual(first_result.returncode, 0, first_result.stderr)
        self.write_text(
            ".claude/agents/local-name.md",
            "---\nname: expo-smoke-runner\n---\nproject-owned agent\n",
        )

        result = self.run_sync("--check")

        self.assertEqual(result.returncode, 1)
        self.assertIn("local-name.md", result.stdout)
        self.assertIn("duplicate native identity", result.stdout)

    def test_rejects_an_unknown_skills_lock_version_without_retiring_agents(
        self,
    ) -> None:
        self.add_managed_companion_skill()
        first_result = self.run_sync()
        self.assertEqual(first_result.returncode, 0, first_result.stderr)
        original_lock = (
            self.project / ".agents/toycrane-agents-lock.json"
        ).read_bytes()
        self.write_json("skills-lock.json", {"version": 2, "skills": {}})

        result = self.run_sync()

        self.assertEqual(result.returncode, 2)
        self.assertIn("Unsupported skills lock", result.stderr)
        self.assertTrue(
            (self.project / ".claude/agents/expo-smoke-runner.md").is_file()
        )
        self.assertTrue(
            (self.project / ".codex/agents/expo-smoke-runner.toml").is_file()
        )
        self.assertEqual(
            (self.project / ".agents/toycrane-agents-lock.json").read_bytes(),
            original_lock,
        )


if __name__ == "__main__":
    unittest.main()
