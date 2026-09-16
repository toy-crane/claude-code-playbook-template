---
name: update-project-skills
description: Update every skill installed in the current Git project to its latest published version through skills.sh, from toy-crane/skills and every other source, then reconcile the Toycrane set by installing newly published skills that fit the project's stack, retiring unpublished ones, and materializing their companion custom agents for Claude Code and Codex. Use when the user asks to update, upgrade, refresh, or sync the skills or custom agents installed in a project. Third-party skills are refreshed in place only; project-local skills and agents stay untouched.
---

# Update Project Skills

Bring every skill installed in the target project to its latest published
version through the current `skills.sh` CLI, then reconcile the Toycrane set
from `https://github.com/toy-crane/skills` and materialize the custom agents
carried by its installed skills for both Claude Code and Codex.

이 프로젝트는 `Copy to all agents` 방식을 사용한다. Codex의 `.agents/skills`와
Claude Code의 `.claude/skills`에 내용이 같은 실제 복사본을 유지한다.
설치와 갱신에는 항상 `--agent codex claude-code --copy`를 지정한다.
`skills-lock.json` records every skill the CLI installed and its source. Treat
entries whose `source` is `toy-crane/skills` as Toycrane-managed and every
other entry as third-party. Skills and agents without a lock entry are
project-local; preserve them unless the user explicitly approves adopting a
name.

## Run the CLI

Every command below runs the current published CLI as `<runner> skills@latest`.
Take `<runner>` from the target project's package manager: `bunx` for bun,
`pnpm dlx` for pnpm, `npx -y` otherwise. npm aborts `npx` with
`EBADDEVENGINES` before the CLI starts when `package.json` pins another
package manager through `devEngines`.

## Update every installed skill

1. Resolve the target Git repository from the requested path or current
   directory. Read its instructions and inspect its status before changing it.
2. Inspect the installed and upstream inventories:

   ```bash
   <runner> skills@latest list --json
   <runner> skills@latest add toy-crane/skills --list
   ```

   Read the project's `skills-lock.json`. The upstream list is the current
   published Toycrane set; ignore the source repository's own development-only
   dependencies under `.agents/skills`.
3. `skills-lock.json`에 기록된 모든 소스의 설치된 스킬을 복사 방식으로 갱신한다.
   각 소스의 공개 목록과 잠긴 이름을 비교하고, 현재 공개되어 있는 설치된 이름만
   명시하여 재설치한다. 같은 소스와 ref의 스킬은 원본 경로가 모호하지 않을 때 묶는다.

   ```bash
   <runner> skills@latest add <original-source> \
     --skill <installed-skill-name> [<installed-skill-name> ...] \
     --agent codex claude-code --copy -y
   ```

   `original-source`는 lock의 `sourceUrl` 또는 `source`를 사용하며, 기록된
   `skillPath`와 `ref`가 있으면 해당 경로와 ref를 보존하는 소스로 지정한다.
   원본을 특정할 수 없는 항목은 추측하여 재설치하지 말고 건너뛴 이유를 보고한다.
   소스에서 사라진 스킬은 보고하고, Toycrane 스킬만 아래의 정리 절차를 적용한다.
   설치된 항목 갱신에 `--all`이나 `--skill '*'`를 사용하지 않는다.

   `skills update -p -y`는 내부 재설치에서 복사 방식을 보존하지 않으므로
   사용하지 않는다. 현재 CLI의 `update`는 `--copy`도 처리하지 않는다.
   이 스킬 자체가 갱신되어도 프로젝트 `AGENTS.md`의 복사 정책을 계속 따른다.

## Reconcile the Toycrane set

Classify the published Toycrane list against the lock:

- Install each newly published universal skill whose name is absent locally.
- Install a newly published skill from the `expo` group only when a
  `package.json` depends on `expo` or `react-native`. Stack detection gates
  new installation only; an already managed stack-specific skill keeps being
  updated even if the stack is no longer detected.
- Treat a published Toycrane name that exists locally without a matching lock
  entry as a collision. Show the path and ask before adopting it.
- Retire each locked Toycrane skill that is no longer published.

Install the new skills in one explicit call so stack exclusions and unapproved
collisions stay excluded, then remove retired names from the whole project:

```bash
<runner> skills@latest add toy-crane/skills \
  --skill <new-skill-name> [<new-skill-name> ...] \
  --agent codex claude-code \
  --copy -y
<runner> skills@latest remove <retired-skill-name> [<retired-skill-name> ...] -y
```

Keep retirement unscoped. An agent-scoped removal can leave the canonical
`.agents` copy and lock entry behind.

## Reconcile companion agents

Run the synchronizer from the freshly updated project copy of this skill:

```bash
python3 .agents/skills/update-project-skills/scripts/sync_companion_agents.py \
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
python3 .agents/skills/update-project-skills/scripts/sync_companion_agents.py \
  --project <project-root> \
  --adopt <approved-agent-name>
```

Repeat `--adopt` for multiple separately approved names. Never infer approval
from identical contents or an existing manifest declaration. Collision checks
use the name declared inside every native agent definition, not only its
filename. Adoption removes alternate-path native definitions of the approved
identity before writing its canonical Claude Code and Codex pair.

## Verify the result

- Rerun `<runner> skills@latest list --json`.
- Confirm each current Toycrane skill exists in `.agents/skills` and in
  `skills-lock.json` with source `toy-crane/skills`.
- `.agents/skills/<name>`과 `.claude/skills/<name>`이 symlink가 아닌 실제
  디렉터리이고, 두 복사본의 파일 목록과 내용이 같은지 확인한다.
- Confirm retired Toycrane skills are absent from the lock and both skill
  paths, third-party lock entries still name their original sources, and
  project-local skills remain unchanged.
- Run the companion check:

  ```bash
  python3 .agents/skills/update-project-skills/scripts/sync_companion_agents.py \
    --project <project-root> \
    --check
  ```

- When `.agent-sync/manifest.json` exists, run the repository's agent sync
  check after the companion check. Confirm it lists every current managed
  Toycrane skill in `shared_skills` and every companion in `shared_agents`.
- Inspect the complete Git diff. Report, per skill, whether it changed and how
  much (`git diff --stat` is enough), followed by the entries the update
  skipped and the upstream deletions it warned about. Then follow the
  repository's commit policy.
- If the current Claude Code or Codex session does not expose a newly installed
  custom agent, finish the update and report that a new session is needed
  before testing agent routing.

## Boundaries

- Keep every change project-local; never use `--global` or `-g`.
- Third-party skills change only through the in-place update. Installing a new
  third-party skill or removing one that disappeared upstream waits for the
  user's request naming it.
- Commit `skills-lock.json`, `.agents/toycrane-agents-lock.json` when present,
  updated skills, and managed agent files together so ownership stays durable.
- Do not remove or overwrite an artifact whose lock does not prove Toycrane
  ownership without explicit approval for that name.
- Do not push unless the user asks.
