---
name: sync-toycrane-skills
description: Reconcile the published skills and their companion custom agents from toy-crane/skills into the current Git project. Use when the user asks to install, update, refresh, reconcile, or remove retired Toycrane project skills or custom agents for Claude Code and Codex. Follow latest upstream through skills.sh, preserve project-local and third-party artifacts, and materialize only agent files whose ownership is recorded.
---

# Sync Toycrane Skills

Reconcile the target project with `https://github.com/toy-crane/skills` through
the current `skills.sh` CLI, then materialize any custom agents carried by the
installed skills for both Claude Code and Codex.

Treat `.agents/skills` as the canonical project skill copy. The CLI exposes the
same skill files to Claude Code through relative links under `.claude/skills`.
Treat `skills-lock.json` entries whose `source` is `toy-crane/skills` as
Toycrane-managed. Preserve every skill and agent without recorded Toycrane
ownership unless the user explicitly approves adopting its name.

## Reconcile the project

1. Resolve the target Git repository from the requested path or current
   directory. Read its instructions and inspect its status before changing it.
2. Inspect current upstream and installed inventories:

   ```bash
   npx -y skills@latest add toy-crane/skills --list
   npx -y skills@latest list --json
   ```

   Read the project's `skills-lock.json` when present. The upstream list is the
   current published set; ignore the source repository's own development-only
   dependencies under `.agents/skills`.
3. Classify the skill reconciliation:
   - Refresh every locked Toycrane skill that is still published.
   - Install each newly published universal skill whose name is absent locally.
   - Install a newly published skill from the `expo` group only when a
     `package.json` depends on `expo` or `react-native`.
   - Continue refreshing an already managed stack-specific skill even if the
     stack is no longer detected; stack detection gates new installation only.
   - Remove a locked Toycrane skill that is no longer published.
   - Preserve every other project-local or third-party skill.
   - Treat a published Toycrane name that exists locally without a matching
     lock entry as a collision. Show the path and ask before adopting it.
4. Apply all current managed skills and eligible new skills in one explicit
   call so stack exclusions remain excluded:

   ```bash
   npx -y skills@latest add toy-crane/skills \
     --skill <skill-name> [<skill-name> ...] \
     --agent codex claude-code \
     -y
   ```

   Re-adding refreshes managed skills and installs missing ones. Do not include
   an unapproved collision.
5. Remove retired managed skill names from the whole project:

   ```bash
   npx -y skills@latest remove <skill-name> [<skill-name> ...] -y
   ```

   Keep retirement unscoped. An agent-scoped removal can leave the canonical
   `.agents` copy and lock entry behind.

## Reconcile companion agents

Run the synchronizer from the freshly installed project copy of this skill:

```bash
python3 .agents/skills/sync-toycrane-skills/scripts/sync_companion_agents.py \
  --project <project-root> \
  [--retired-skill <retired-skill-name> ...]
```

Append one `--retired-skill` for every Toycrane-managed skill removed in the
preceding reconciliation. This lets a project-level agent manifest retire
those skill declarations after `skills-lock.json` no longer contains them.

The script scans only installed skills proven Toycrane-managed by
`skills-lock.json`. A skill declares companions in
`companion-agents/manifest.json`; the script copies its native definitions to
`.claude/agents/<name>.md` and `.codex/agents/<name>.toml`, records ownership in
`.agents/toycrane-agents-lock.json`, and reconciles both `shared_skills` and
`shared_agents` when the project already has `.agent-sync/manifest.json`.

The ownership lock authorizes later refresh and retirement of those exact
agent names. Other agent files and manifest entries remain project-owned. If
the script reports an unowned collision, show every colliding path and ask for
approval for that name. After approval, adopt only the approved names:

```bash
python3 .agents/skills/sync-toycrane-skills/scripts/sync_companion_agents.py \
  --project <project-root> \
  --adopt <approved-agent-name>
```

Repeat `--adopt` for multiple separately approved names. Never infer approval
from identical contents or an existing manifest declaration. Collision checks
use the name declared inside every native agent definition, not only its
filename. Adoption removes alternate-path native definitions of the approved
identity before writing its canonical Claude Code and Codex pair.

## Verify the result

- Rerun both skills inventory commands.
- Confirm each managed current skill exists in `.agents/skills` and in
  `skills-lock.json` with source `toy-crane/skills`.
- Confirm `.claude/skills/<name>` is a relative link to
  `../../.agents/skills/<name>` for each managed skill.
- Confirm retired managed skills are absent from the lock and both skill paths,
  while project-local skills remain unchanged.
- Run the companion check:

  ```bash
  python3 .agents/skills/sync-toycrane-skills/scripts/sync_companion_agents.py \
    --project <project-root> \
    --check
  ```

- When `.agent-sync/manifest.json` exists, run the repository's agent sync
  check after the companion check. Confirm it lists every current managed
  Toycrane skill in `shared_skills` and every companion in `shared_agents`.
- Inspect the complete Git diff and follow the repository's commit policy.
- If the current Claude Code or Codex session does not expose a newly installed
  custom agent, finish the reconciliation and report that a new session is
  needed before testing agent routing.

## Boundaries

- Keep every change project-local; never use `--global` or `-g`.
- Do not run an unscoped `skills update -p`, which may refresh unrelated
  third-party skills.
- Commit `skills-lock.json`, `.agents/toycrane-agents-lock.json` when present,
  installed skills, and managed agent files together so ownership is durable.
- Do not remove or overwrite an artifact whose lock does not prove Toycrane
  ownership without explicit approval for that name.
- Do not push unless the user asks.
