#!/usr/bin/env bash
# Exercise remove-worktree.sh against scratch repositories and real processes.

set -euo pipefail

task_helper=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/remove-worktree.sh
task_root=$(mktemp -d)
task_root=$(cd "$task_root" && pwd -P)
task_live_pids=()
task_passed=0
task_skipped=0

cleanup_eval() {
  for task_pid in ${task_live_pids[@]+"${task_live_pids[@]}"}; do
    builtin kill -KILL -- "$task_pid" 2>/dev/null || true
  done
  rm -rf -- "$task_root"
}
trap cleanup_eval EXIT

export GIT_AUTHOR_NAME=eval GIT_AUTHOR_EMAIL=eval@example.com
export GIT_COMMITTER_NAME=eval GIT_COMMITTER_EMAIL=eval@example.com
export CODEX_HOME="$task_root/codex"
mkdir -p "$CODEX_HOME/worktrees"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  printf '%s\n' "${task_output:-}" >&2
  exit 1
}

expect_line() {
  grep -qxF -- "$1" <<<"$task_output" || fail "expected line '$1'"
}

expect_prefix() {
  grep -q "^$1" <<<"$task_output" || fail "expected a line starting '$1'"
}

reject_prefix() {
  if grep -q "^$1" <<<"$task_output"; then
    fail "unexpected line starting '$1'"
  fi
}

pass() {
  task_passed=$((task_passed + 1))
}

# Runs the helper with the main checkout as working directory.
helper() {
  task_output=$(cd "$task_main" && bash "$task_helper" "$@")
}

# A bare origin, a main checkout that ignores .wt/ like an agent host would,
# and origin/main fetched.
task_origin="$task_root/origin.git"
task_main="$task_root/main"
git init -q --bare -b main "$task_origin"
git clone -q "$task_origin" "$task_main" 2>/dev/null
git -C "$task_main" commit -q --allow-empty -m init
git -C "$task_main" push -q origin main
printf '.wt/\n' >>"$task_main/.git/info/exclude"
mkdir -p "$task_main/.wt"

add_worktree() {
  git -C "$task_main" worktree add -q "$task_main/.wt/$1" -b "$1" origin/main
  printf '%s\n' "$task_main/.wt/$1"
}

commit_in() {
  git -C "$1" commit -q --allow-empty -m "$2"
  git -C "$1" rev-parse HEAD
}

# A process whose launcher has exited: its parent becomes PID 1.
start_leftover() {
  local pid_file="$task_root/pid.$RANDOM"
  (cd "$1" && { sleep 300 >/dev/null 2>&1 & printf '%s\n' "$!" >"$pid_file"; })
  task_started_pid=$(cat "$pid_file")
  task_live_pids+=("$task_started_pid")
}

# A process launched from outside the folder by a launcher that stays alive.
start_attached() {
  local pid_file="$task_root/pid.$RANDOM"
  bash -c 'cd /; (cd "$1" && exec sleep 300) & printf "%s\n" "$!" >"$2"; wait' \
    _ "$1" "$pid_file" &
  task_live_pids+=("$!")
  disown "$!"
  while [ ! -s "$pid_file" ]; do sleep 0.05; done
  task_started_pid=$(cat "$pid_file")
  task_live_pids+=("$task_started_pid")
}

# 1. A clean, merged worktree is ready and is removed with its branch.
task_wt=$(add_worktree merged)
helper inspect "$task_wt" --base origin/main
expect_line 'verdict ready'
expect_line 'branch merged deletable'
reject_prefix holder
helper remove "$task_wt" --base origin/main
expect_line 'result removed'
expect_line 'branch deleted merged'
[ ! -e "$task_wt" ] || fail 'merged worktree folder should be gone'
pass

# 2. A squash-merged branch is deleted only when its tip equals the PR head.
task_wt=$(add_worktree squashed)
task_tip=$(commit_in "$task_wt" squashed-work)
helper remove "$task_wt" --base origin/main --pr-head "$task_tip"
expect_line 'result removed'
expect_line 'branch deleted squashed'
task_wt=$(add_worktree ahead)
commit_in "$task_wt" pushed-work >/dev/null
task_pr_head=$(git -C "$task_wt" rev-parse HEAD)
commit_in "$task_wt" unpushed-work >/dev/null
helper inspect "$task_wt" --base origin/main --pr-head "$task_pr_head"
expect_line 'branch ahead unmerged'
helper remove "$task_wt" --base origin/main --pr-head "$task_pr_head"
expect_line 'result removed'
expect_line 'branch kept ahead unmerged'
git -C "$task_main" rev-parse --verify --quiet refs/heads/ahead >/dev/null \
  || fail 'unmerged branch should remain'
pass

# 2b. A detached worktree has no branch to delete; a locked one stays.
git -C "$task_main" worktree add -q "$task_main/.wt/detached" --detach origin/main
helper inspect "$task_main/.wt/detached" --base origin/main
expect_line 'verdict ready'
reject_prefix branch
helper remove "$task_main/.wt/detached" --base origin/main
expect_line 'result removed'
reject_prefix branch
git -C "$task_main" worktree add -q "$task_main/.wt/detached-locked" --detach origin/main
git -C "$task_main" worktree lock "$task_main/.wt/detached-locked"
helper remove "$task_main/.wt/detached-locked" --base origin/main
expect_line 'result left locked'
pass

# 3. Uncommitted changes, including untracked files, keep the worktree.
task_wt=$(add_worktree dirty)
printf 'draft\n' >"$task_wt/notes.txt"
helper inspect "$task_wt" --base origin/main
expect_line 'verdict blocked'
expect_line 'reason dirty'
helper remove "$task_wt" --base origin/main
expect_line 'result left dirty'
[ -d "$task_wt" ] || fail 'dirty worktree should remain'
pass

# 4. A locked worktree stays.
task_wt=$(add_worktree locked)
git -C "$task_main" worktree lock "$task_wt"
helper remove "$task_wt" --base origin/main
expect_line 'result left locked'
pass

# 5. A left-over process lets cleanup commands run but blocks removal until it
#    is gone; the helper never stops it.
task_wt=$(add_worktree leftover)
start_leftover "$task_wt"
task_leftover_pid=$task_started_pid
sleep 0.2
if [ "$(ps -o ppid= -p "$task_leftover_pid" | tr -d ' ')" = 1 ]; then
  helper inspect "$task_wt" --base origin/main
  expect_line 'verdict ready'
  expect_prefix "holder leftover $task_leftover_pid "
  helper remove "$task_wt" --base origin/main
  expect_line 'result left holders'
  [ -d "$task_wt" ] || fail 'folder with a left-over process should remain'
  ps -p "$task_leftover_pid" >/dev/null || fail 'helper must not stop processes'
  builtin kill "$task_leftover_pid"
  while ps -p "$task_leftover_pid" >/dev/null 2>&1; do sleep 0.05; done
  helper remove "$task_wt" --base origin/main
  expect_line 'result removed'
  pass
else
  printf 'skip: orphaned processes are not reparented to PID 1 here\n'
  task_skipped=$((task_skipped + 1))
fi

# 6. A process whose launcher is alive marks the worktree attached.
task_wt=$(add_worktree attached)
start_attached "$task_wt"
task_attached_pid=$task_started_pid
helper inspect "$task_wt" --base origin/main
expect_line 'verdict attached'
expect_prefix "holder attached $task_attached_pid "
helper remove "$task_wt" --base origin/main
expect_line 'result left holders'
[ -d "$task_wt" ] || fail 'attached worktree should remain'
ps -p "$task_attached_pid" >/dev/null || fail 'helper must not stop processes'
task_wt="$task_main/.wt/back\\tslash"
git -C "$task_main" worktree add -q "$task_wt" -b backslash origin/main
start_attached "$task_wt"
helper inspect "$task_wt"
expect_line 'verdict attached'
task_wt="$task_main/.wt/한글 작업"
git -C "$task_main" worktree add -q "$task_wt" -b hangul origin/main
start_attached "$task_wt"
task_output=$(cd "$task_main" && LC_ALL=C bash "$task_helper" inspect "$task_wt")
expect_line 'verdict attached'
pass

# 7. The current session inside the worktree keeps the folder: HEAD detaches
#    at the base and only the branch is deleted.
task_wt=$(add_worktree inside)
task_output=$(cd "$task_wt" && bash "$task_helper" inspect "$task_wt")
expect_line 'verdict session-inside'
task_output=$(cd "$task_wt" && bash "$task_helper" remove "$task_wt" --base origin/main)
expect_line "detached $(git -C "$task_main" rev-parse origin/main)"
expect_line 'result kept-folder'
expect_line 'branch deleted inside'
[ -d "$task_wt" ] || fail 'session worktree folder should remain'
git -C "$task_wt" symbolic-ref -q HEAD >/dev/null && fail 'HEAD should be detached'
pass

# 7b. Inside a worktree whose branch has unpushed commits, HEAD still detaches
#     but the branch stays; a base-branch worktree is not detached at all.
task_wt=$(add_worktree inside-ahead)
commit_in "$task_wt" unpushed-work >/dev/null
task_output=$(cd "$task_wt" && bash "$task_helper" remove "$task_wt" --base origin/main)
expect_line 'result kept-folder'
expect_line 'branch kept inside-ahead unmerged'
git -C "$task_main" rev-parse --verify --quiet refs/heads/inside-ahead >/dev/null \
  || fail 'unmerged branch should remain'
git -C "$task_main" push -q origin origin/main:refs/heads/stable
git -C "$task_main" fetch -q origin
git -C "$task_main" worktree add -q "$task_main/.wt/stable" -b stable origin/stable
task_output=$(cd "$task_main/.wt/stable" \
  && bash "$task_helper" remove "$task_main/.wt/stable" --base origin/stable)
reject_prefix detached
expect_line 'result kept-folder'
expect_line 'branch kept stable base-branch'
[ "$(git -C "$task_main/.wt/stable" symbolic-ref --short HEAD)" = stable ] \
  || fail 'base-branch worktree should stay on its branch'
pass

# 8. An ancestor working inside counts as the current session even when the
#    helper itself runs elsewhere.
task_wt=$(add_worktree ancestor)
task_output=$(cd "$task_wt" && bash -c 'cd "$1" && bash "$2" inspect "$3"' \
  _ "$task_main" "$task_helper" "$task_wt"; true)
expect_line 'verdict session-inside'
pass

# 9. Codex-managed worktrees are left to Codex unless the session is inside.
mkdir -p "$CODEX_HOME/worktrees/ab12"
git -C "$task_main" worktree add -q "$CODEX_HOME/worktrees/ab12/repo" --detach origin/main
helper inspect "$CODEX_HOME/worktrees/ab12/repo"
expect_line 'verdict codex-managed'
helper remove "$CODEX_HOME/worktrees/ab12/repo" --base origin/main
expect_line 'result left codex-managed'
[ -d "$CODEX_HOME/worktrees/ab12/repo" ] || fail 'Codex worktree should remain'
task_output=$(cd "$CODEX_HOME/worktrees/ab12/repo" \
  && bash "$task_helper" inspect "$CODEX_HOME/worktrees/ab12/repo")
expect_line 'verdict session-inside'
pass

# 10. An unregistered folder without .git inside an ignored worktree folder is
#     removed; one with .git, outside the main checkout, or not ignored stays.
mkdir -p "$task_main/.wt/orphan/supabase/templates"
helper inspect "$task_main/.wt/orphan"
expect_line 'verdict ready'
helper remove "$task_main/.wt/orphan" --base origin/main
expect_line 'result removed'
[ ! -e "$task_main/.wt/orphan" ] || fail 'orphan folder should be gone'
mkdir -p "$task_main/.wt/orphan-git"
printf 'gitdir: %s/.git/worktrees/gone\n' "$task_main" >"$task_main/.wt/orphan-git/.git"
helper remove "$task_main/.wt/orphan-git" --base origin/main
expect_line 'result left unverifiable-git'
mkdir -p "$task_main/.wt/orphan-link"
ln -s "$task_main/.git/worktrees/gone" "$task_main/.wt/orphan-link/.git"
helper remove "$task_main/.wt/orphan-link" --base origin/main
expect_line 'result left unverifiable-git'
git -C "$task_main" worktree add -q "$task_root/sibling" -b sibling origin/main
mkdir -p "$task_root/notes"
helper inspect "$task_root/notes"
expect_line 'reason not-a-worktree-folder'
mkdir -p "$task_main/shared"
git -C "$task_main" worktree add -q "$task_main/shared/wt" -b shared origin/main
mkdir -p "$task_main/shared/keep"
helper inspect "$task_main/shared/keep"
expect_line 'reason not-ignored'
pass

# 11. The main checkout and folders holding worktrees are never removed.
helper remove "$task_main" --base origin/main
expect_line 'result left main-checkout'
helper remove "$task_main/.wt" --base origin/main
expect_line 'result left contains-worktree'
helper remove "$task_root" --base origin/main
expect_line 'result left contains-main-checkout'
[ -d "$task_main/.wt" ] || fail 'worktree folder should remain'
pass

# 12. The base branch itself is never deleted.
git -C "$task_main" push -q origin origin/main:refs/heads/release
git -C "$task_main" fetch -q origin
git -C "$task_main" worktree add -q "$task_main/.wt/release" -b release origin/release
helper remove "$task_main/.wt/release" --base origin/release
expect_line 'result removed'
expect_line 'branch kept release base-branch'
pass

# 13. Without a way to read process working directories nothing is removed.
if [ ! -d /proc/self ]; then
  task_bin="$task_root/bin"
  mkdir -p "$task_bin"
  for task_tool in bash git ps awk sed dirname rm cat; do
    ln -s "$(command -v "$task_tool")" "$task_bin/$task_tool"
  done
  task_wt=$(add_worktree blind)
  task_output=$(cd "$task_main" && PATH="$task_bin" bash "$task_helper" remove "$task_wt" --base origin/main)
  expect_line 'result left inspection-failed'
  [ -d "$task_wt" ] || fail 'worktree should remain when processes cannot be read'
  pass
else
  printf 'skip: /proc provides working directories without lsof\n'
  task_skipped=$((task_skipped + 1))
fi

printf 'remove-worktree evals passed: %s, skipped: %s\n' "$task_passed" "$task_skipped"
