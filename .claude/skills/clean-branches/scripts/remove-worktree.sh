#!/usr/bin/env bash
# Inspect or remove one Git worktree without disturbing a session or a process
# that still works inside it. Every skill that removes worktrees ships an
# identical copy of this file.
#
#   remove-worktree.sh inspect <path> [--base <ref>] [--pr-head <sha>]
#   remove-worktree.sh remove  <path>  --base <ref>  [--pr-head <sha>]
#
# Run it from the session's own working directory in a checkout of the
# repository that owns the worktree. Its own working directory and those of its
# ancestor processes count as the current session, so running it after
# changing into the target reports session-inside. The caller runs the
# project's declared cleanup commands between the two steps; this script never
# signals a process.
#
# Output, one record per line:
#   verdict session-inside|codex-managed|attached|blocked|ready
#   reason <why>                                  blocked only
#   holder attached|leftover <pid> <command>
#   branch <name> deletable|unmerged|base-branch  inspect, with --base
#   detached <sha>                                remove, session inside
#   result kept-folder|removed|left [<why>]       remove
#   branch deleted|kept <name> [<why>]            remove
#   detail <text>

set -uo pipefail

usage() {
  printf 'usage: %s inspect|remove <path> [--base <ref>] [--pr-head <sha>]\n' \
    "${0##*/}" >&2
  exit 2
}

[ $# -ge 2 ] || usage
mode=$1
target_arg=$2
shift 2
base=''
pr_head=''
while [ $# -gt 0 ]; do
  case $1 in
    --base) [ $# -ge 2 ] || usage; base=$2; shift 2 ;;
    --pr-head) [ $# -ge 2 ] || usage; pr_head=$2; shift 2 ;;
    *) usage ;;
  esac
done
case $mode in
  inspect) ;;
  remove) [ -n "$base" ] || usage ;;
  *) usage ;;
esac

git rev-parse --git-dir >/dev/null 2>&1 || {
  printf 'Run from a checkout of the repository that owns the worktree.\n' >&2
  exit 2
}
if [ -n "$base" ] && ! git rev-parse --verify --quiet "$base^{commit}" >/dev/null; then
  printf "Base '%s' does not resolve to a commit; fetch it first.\n" "$base" >&2
  exit 2
fi

canonical() { (cd "$1" 2>/dev/null && pwd -P); }

# is_within <path> <dir>: the path is the directory or lies below it.
is_within() {
  [ "$1" = "$2" ] && return 0
  case $1 in "$2"/*) return 0 ;; esac
  return 1
}

target=$(canonical "$target_arg") || target=''

main_path=''
registered=0
branch=''
locked=0
linked_paths=()
linked_parents=()
while IFS=$'\037' read -r entry_path entry_branch entry_locked; do
  [ -n "$entry_path" ] || continue
  entry_real=$(canonical "$entry_path") || entry_real=$entry_path
  if [ -z "$main_path" ]; then
    main_path=$entry_real
  else
    linked_paths+=("$entry_real")
    linked_parents+=("$(dirname -- "$entry_real")")
  fi
  if [ -n "$target" ] && [ "$entry_real" = "$target" ]; then
    registered=1
    branch=$entry_branch
    locked=$entry_locked
  fi
done < <(git worktree list --porcelain | awk '
  /^worktree / { if (path != "") print path "\037" ref "\037" lock
                 path = substr($0, 10); ref = ""; lock = 0; next }
  /^branch /   { ref = substr($0, 8); sub(/^refs\/heads\//, "", ref); next }
  /^locked/    { lock = 1; next }
  END          { if (path != "") print path "\037" ref "\037" lock }')

# Reasons that rule out the path whatever runs inside it.
guard_reason() {
  [ "$target" = "$main_path" ] && { echo main-checkout; return; }
  is_within "$main_path" "$target" && { echo contains-main-checkout; return; }
  for linked in ${linked_paths[@]+"${linked_paths[@]}"}; do
    if [ "$linked" != "$target" ] && is_within "$linked" "$target"; then
      echo contains-worktree
      return
    fi
  done
}

# Reasons that keep a path the current session does not work inside.
state_reason() {
  if [ "$registered" = 1 ]; then
    [ "$locked" = 1 ] && { echo locked; return; }
    local status
    status=$(git -C "$target" status --porcelain 2>/dev/null) || {
      echo unreadable
      return
    }
    [ -z "$status" ] || echo dirty
    return
  fi
  local parent found=0
  parent=$(dirname -- "$target")
  for linked_parent in ${linked_parents[@]+"${linked_parents[@]}"}; do
    [ "$linked_parent" = "$parent" ] && found=1
  done
  if [ "$found" = 0 ] || [ "$parent" = "$main_path" ] \
    || ! is_within "$parent" "$main_path"; then
    echo not-a-worktree-folder
    return
  fi
  git -C "$main_path" check-ignore --quiet -- "${target#"$main_path"/}" \
    || { echo not-ignored; return; }
  if [ -e "$target/.git" ] || [ -L "$target/.git" ]; then
    echo unverifiable-git
  fi
}

process_cwds() {
  if command -v lsof >/dev/null 2>&1; then
    # lsof exits nonzero when it cannot read some process; an empty listing is
    # the failure that matters, and the caller checks for it.
    { lsof -w -n -P -d cwd -Fpn 2>/dev/null || true; } \
      | awk '/^p/ { pid = substr($0, 2) } /^n/ { print pid "\t" substr($0, 2) }'
  elif [ -d /proc/self ]; then
    for entry in /proc/[0-9]*; do
      dir=$(readlink "$entry/cwd" 2>/dev/null) \
        && printf '%s\t%s\n' "${entry#/proc/}" "$dir"
    done
  fi
}

# lsof escapes some characters in the names it prints: a backslash always,
# and every non-ASCII byte outside a UTF-8 locale. The main script holds the
# target open on descriptor 9 while classifying, so lsof can show its own
# rendering of the target to match its listing against.
plain_path() {
  case $1 in *\\*) return 1 ;; esac
  ! printf '%s' "$1" | LC_ALL=C grep -q '[^ -~]'
}

target_as_listed() {
  local name=''
  if ! command -v lsof >/dev/null 2>&1; then
    printf '%s\n' "$target"
    return
  fi
  name=$({ lsof -w -n -P -a -p "$$" -d 9 -Fn 2>/dev/null || true; } \
    | sed -n 's/^n//p' | head -n 1)
  if [ -n "$name" ]; then
    printf '%s\n' "$name"
  elif plain_path "$target"; then
    printf '%s\n' "$target"
  else
    return 1
  fi
}

# Prints "session" when this command or an ancestor works inside the target,
# otherwise one "attached|leftover <pid>" line per other process inside it. A
# process is left over when the outermost process launching it from inside the
# target has been reparented to PID 1; otherwise its launcher is still alive.
classify_processes() {
  local table cwds listed
  listed=$(target_as_listed) || return 1
  table=$(ps -A -o pid= -o ppid= 2>/dev/null) || return 1
  cwds=$(process_cwds) || return 1
  [ -n "$table" ] && [ -n "$cwds" ] || return 1
  REMOVE_WORKTREE_TARGET=$listed REMOVE_WORKTREE_SELF=$$ awk '
    BEGIN {
      target = ENVIRON["REMOVE_WORKTREE_TARGET"]
      self = ENVIRON["REMOVE_WORKTREE_SELF"] + 0
    }
    function inside(dir) {
      return dir == target || substr(dir, 1, length(target) + 1) == target "/"
    }
    function below_self(pid,  hops) {
      for (hops = 0; pid > 1 && hops < 4096; hops++) {
        if (pid == self) return 1
        pid = parent[pid]
      }
      return 0
    }
    FNR == NR { parent[$1] = $2; next }
    { tab = index($0, "\t"); cwd[substr($0, 1, tab - 1)] = substr($0, tab + 1) }
    END {
      for (pid = self; pid > 1 && hops++ < 4096; pid = parent[pid]) chain[pid] = 1
      for (pid in chain) if ((pid in cwd) && inside(cwd[pid])) { print "session"; exit }
      for (pid in cwd) {
        if (!inside(cwd[pid]) || (pid in chain) || below_self(pid)) continue
        top = pid
        for (hops = 0; hops < 4096; hops++) {
          up = parent[top]
          if (up == "" || up <= 1 || !(up in cwd) || !inside(cwd[up])) break
          top = up
        }
        print (parent[top] == 1 ? "leftover" : "attached"), pid
      }
    }' <(printf '%s\n' "$table") <(printf '%s\n' "$cwds")
}

base_branch_name() {
  local short
  short=$(git rev-parse --abbrev-ref "$base" 2>/dev/null) || short=$base
  if git show-ref --verify --quiet "refs/remotes/$short"; then
    short=${short#*/}
  fi
  printf '%s\n' "$short"
}

branch_state() {
  local tip head
  [ "$branch" = "$(base_branch_name)" ] && { echo base-branch; return; }
  tip=$(git rev-parse --verify --quiet "refs/heads/$branch^{commit}") \
    || { echo missing; return; }
  if [ -n "$pr_head" ]; then
    head=$(git rev-parse --verify --quiet "$pr_head^{commit}") || head=$pr_head
    [ "$tip" = "$head" ] && { echo deletable; return; }
  fi
  if git merge-base --is-ancestor "$tip" "$base" 2>/dev/null; then
    echo deletable
  else
    echo unmerged
  fi
}

print_holders() {
  local kind pid command
  for holder in ${holders[@]+"${holders[@]}"}; do
    kind=${holder%% *}
    pid=${holder#* }
    command=$(ps -p "$pid" -o args= 2>/dev/null) || continue
    printf 'holder %s %s %s\n' "$kind" "$pid" "$command"
  done
}

print_detail() {
  sed 's/^/detail /' <<<"$1"
}

delete_branch() {
  [ -n "$branch" ] || return 0
  local state output
  state=$(branch_state)
  if [ "$state" != deletable ]; then
    printf 'branch kept %s %s\n' "$branch" "$state"
    return
  fi
  if output=$(git branch -D "$branch" 2>&1); then
    printf 'branch deleted %s\n' "$branch"
  else
    printf 'branch kept %s git-refused\n' "$branch"
    print_detail "$output"
  fi
}

verdict=''
reason=''
holders=()
if [ -n "$target" ] && [ -r "$target" ] && [ -x "$target" ]; then
  exec 9<"$target"
fi
if [ -z "$target" ]; then
  verdict=blocked
  reason=missing
else
  reason=$(guard_reason)
  if [ -n "$reason" ]; then
    verdict=blocked
  elif ! processes=$(classify_processes); then
    verdict=blocked
    reason=inspection-failed
  elif [ "$processes" = session ]; then
    verdict=session-inside
  else
    while read -r kind pid; do
      [ -n "$kind" ] || continue
      ps -p "$pid" >/dev/null 2>&1 && holders+=("$kind $pid")
    done <<<"$processes"
    codex_root=${CODEX_HOME:-$HOME/.codex}/worktrees
    codex_root=$(canonical "$codex_root") || codex_root=${CODEX_HOME:-$HOME/.codex}/worktrees
    if is_within "$target" "$codex_root"; then
      verdict=codex-managed
    else
      reason=$(state_reason)
      if [ -n "$reason" ]; then
        verdict=blocked
      else
        verdict=ready
        for holder in ${holders[@]+"${holders[@]}"}; do
          [ "${holder%% *}" = attached ] && verdict=attached
        done
      fi
    fi
  fi
fi

exec 9<&-

if [ "$mode" = inspect ]; then
  printf 'verdict %s\n' "$verdict"
  [ -n "$reason" ] && printf 'reason %s\n' "$reason"
  print_holders
  if [ -n "$branch" ] && [ -n "$base" ]; then
    printf 'branch %s %s\n' "$branch" "$(branch_state)"
  fi
  exit 0
fi

case $verdict in
  session-inside)
    if [ "$registered" = 1 ] && [ -n "$branch" ] \
      && [ "$(branch_state)" != base-branch ]; then
      if ! output=$(git -C "$target" switch --quiet --detach "$base" 2>&1); then
        printf 'result left detach-failed\n'
        print_detail "$output"
        exit 0
      fi
      printf 'detached %s\n' "$(git -C "$target" rev-parse HEAD)"
    fi
    printf 'result kept-folder\n'
    delete_branch
    ;;
  ready)
    if [ ${#holders[@]} -gt 0 ]; then
      printf 'result left holders\n'
      print_holders
    elif [ "$registered" = 1 ]; then
      if output=$(git -C "$main_path" worktree remove "$target" 2>&1); then
        printf 'result removed\n'
        delete_branch
      else
        printf 'result left git-refused\n'
        print_detail "$output"
      fi
    elif output=$(rm -rf -- "$target" 2>&1); then
      printf 'result removed\n'
    else
      printf 'result left remove-failed\n'
      print_detail "$output"
    fi
    ;;
  attached)
    printf 'result left holders\n'
    print_holders
    ;;
  *)
    printf 'result left %s\n' "${reason:-$verdict}"
    ;;
esac
