---
name: update-project-skills
description: Update every skill installed in the current Git project to its latest published version through skills.sh, from toy-crane/skills and every other source, then reconcile the Toycrane set by installing newly published skills that fit the project's stack, retiring unpublished ones, materializing their companion custom agents for Claude Code and Codex, and updating installed Toycrane Claude Code mods while offering new ones. Use when the user asks to update, upgrade, refresh, or sync the skills or custom agents installed in a project. Third-party skills are refreshed in place only; project-local skills and agents stay untouched.
---

# Update Project Skills

Bring every skill installed in the target project to its latest published
version through the current `skills.sh` CLI, then reconcile the Toycrane set
from `https://github.com/toy-crane/skills` and materialize the custom agents
carried by its installed skills for both Claude Code and Codex.

Treat `.agents/skills` as the canonical project skill copy. The CLI exposes the
same skill files to Claude Code through relative links under `.claude/skills`.
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
3. Find the skills the update will move. The CLI (1.8 and later) reinstalls any
   locked skill whose canonical copy `.agents/skills/<name>` is missing, as a
   copy there plus a relative link at `.claude/skills/<name>`, replacing a real
   folder that was installed only for Claude Code. Content stays identical.
   List every lock entry whose `.agents/skills/<name>` does not exist and whose
   `.claude/skills/<name>` is a real folder. Before updating, tell the user
   which names will move, and if any, carry them into the final report. Such a
   skill may have been kept Claude-only on purpose, and after the move Codex
   and other universal clients see it too. Never decide that alone. Offer
   these choices and recommend the first:

   - Accept the move. Nothing is lost, Claude Code still resolves the skill
     through the link, and the skill now follows the same layout as every other
     one.
   - Keep it where it is for now: name the other skills in the update call
     (`update <name> [<name> ...] -p -y`) and leave this one out. Say that it
     stays stale until the user chooses. Offer this only for third-party
     skills. A Toycrane-managed skill needs its `.agents/skills` copy for the
     companion synchronizer and the final verification, so for those the
     choice is the first or the third.
   - Accept the move, then have the user decide whether to hide it from Codex
     again. The CLI has no Claude-only placement for an existing lock entry, so
     this means removing the skill and reinstalling it with `--agent
     claude-code`, which is a separate request.

   Wait for the answer before running the update when any skill will move.
4. Update every locked skill in place, from every source, in one project-scoped
   call:

   ```bash
   <runner> skills@latest update -p -y
   ```

   The CLI refreshes each lock entry that records a `skillPath`, one clone per
   source, and reinstalls it for the current client plus the universal
   `.agents` copy; existing `.claude/skills` links keep resolving because they
   are relative. The first run from a CLI that writes lock version 2 also
   upgrades `skills-lock.json` from version 1 and rewrites every
   `computedHash`, since the hash now covers the files installed into
   `.agents/skills/<name>`. Expect that whole-lock diff and report it as a
   format change, not as skill changes. Carry three parts of its output into
   the final report: the
   per-skill results, the entries it cannot update in place because they were
   installed before `skillPath` tracking (with the reinstall hint it prints),
   and the skills it reports as deleted upstream. Leave those last two groups
   as reported; whether to reinstall or remove them is the user's call.

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
  -y
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

## Reconcile Toycrane mods

A mod is a Claude Code plugin from the `toycrane` marketplace other than
`toycrane-skills`. It hooks tool calls or the interface, so installing one
stays the user's choice. Skip this section when the `claude` CLI is not on
`PATH`.

1. Refresh the marketplace, adding it first when it is missing, then read the
   published mods and the installed ones:

   ```bash
   claude plugin marketplace update toycrane \
     || claude plugin marketplace add toy-crane/skills
   claude plugin list --available --json
   ```

   A mod counts as installed for this project when its `<name>@toycrane`
   entry has `user` scope, or `project` or `local` scope with a
   `projectPath` equal to the project root.
2. Update each installed mod at the scope its entry records, since older
   Claude Code versions default an update to `user` scope:

   ```bash
   claude plugin update <mod-name>@toycrane --scope <entry-scope> -y
   ```

3. List each published mod that is not installed with its marketplace
   description, and ask which to install. Install only the names the user
   picks, at `local` scope so the choice stays with this checkout and is not
   committed for teammates:

   ```bash
   claude plugin install <mod-name>@toycrane --scope local -y
   ```

   Never uninstall a mod, even one no longer published; report it instead.

Mod changes take effect in a new Claude Code session.

## Verify the result

- Rerun `<runner> skills@latest list --json`.
- Confirm each current Toycrane skill exists in `.agents/skills` and in
  `skills-lock.json` with source `toy-crane/skills`, and that
  `.claude/skills/<name>` is a relative link to `../../.agents/skills/<name>`.
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
  much (`git diff --stat` is enough), followed by the skills moved into
  `.agents/skills` with the user's choice about each, the lock version and hash
  rewrite when it happened, the entries the update skipped and the upstream
  deletions it warned about. Then follow the
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
