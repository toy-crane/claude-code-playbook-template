#!/usr/bin/env bash
# Stop only active Portless route processes whose working directory belongs to
# the current linked worktree. Other runners are left to the invoking agent.

set -uo pipefail

command -v portless >/dev/null 2>&1 || exit 0
command -v ps >/dev/null 2>&1 || {
  printf 'Could not inspect development-server process state because ps is unavailable.\n' >&2
  exit 1
}

task_git_dir=$(git rev-parse --git-dir 2>/dev/null) || exit 0
task_common_dir=$(git rev-parse --git-common-dir 2>/dev/null) || exit 0
[ "$task_git_dir" = "$task_common_dir" ] && exit 0

task_worktree=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
task_worktree=$(cd "$task_worktree" 2>/dev/null && pwd -P) || exit 0

task_process_cwd() {
  task_pid=$1
  if command -v lsof >/dev/null 2>&1; then
    task_found_cwd=$(lsof -a -p "$task_pid" -d cwd -Fn 2>/dev/null \
      | sed -n 's/^n//p' \
      | head -n 1) || task_found_cwd=''
    if [ -n "$task_found_cwd" ]; then
      printf '%s\n' "$task_found_cwd"
      return 0
    fi
  fi
  if [ -e "/proc/$task_pid/cwd" ]; then
    readlink "/proc/$task_pid/cwd" 2>/dev/null
    return
  fi
  return 1
}

task_pid_running() {
  task_state=$(ps -p "$1" -o stat= 2>/dev/null | awk 'NR == 1 { print $1 }')
  [ -n "$task_state" ] && [ "${task_state#Z}" = "$task_state" ]
}

task_routes=$(portless list 2>&1) || {
  printf 'Could not inspect active Portless routes:\n%s\n' "$task_routes" >&2
  exit 1
}
task_route_pids=$(printf '%s\n' "$task_routes" \
  | sed $'s/\x1b\\[[0-9;]*m//g' \
  | grep -oE 'pid [1-9][0-9]*' \
  | awk '{print $2}' \
  | sort -u)
[ -z "$task_route_pids" ] && exit 0

task_owned_pids=''
task_inspection_failed=0
for task_pid in $task_route_pids; do
  task_pid_running "$task_pid" || continue
  task_cwd=$(task_process_cwd "$task_pid") || task_cwd=''
  if [ -z "$task_cwd" ]; then
    printf 'Could not verify the working directory for active Portless pid %s.\n' \
      "$task_pid" >&2
    task_inspection_failed=1
    continue
  fi
  task_cwd=$(cd "$task_cwd" 2>/dev/null && pwd -P) || {
    printf 'Could not resolve the working directory for active Portless pid %s.\n' \
      "$task_pid" >&2
    task_inspection_failed=1
    continue
  }
  case "$task_cwd" in
    "$task_worktree"|"$task_worktree"/*)
      task_owned_pids="$task_owned_pids $task_pid"
      ;;
  esac
done

[ "$task_inspection_failed" -eq 0 ] || exit 1
[ -n "$task_owned_pids" ] || exit 0

printf "Stopping development server(s) owned by worktree '%s':\n" "$task_worktree"
task_stop_failed=0
for task_pid in $task_owned_pids; do
  printf '  - pid %s\n' "$task_pid"
  if ! kill -TERM -- "$task_pid" 2>/dev/null && task_pid_running "$task_pid"; then
    printf 'Failed to send TERM to Portless pid %s.\n' "$task_pid" >&2
    task_stop_failed=1
    continue
  fi

  task_attempt=0
  while task_pid_running "$task_pid" && [ "$task_attempt" -lt 50 ]; do
    sleep 0.1
    task_attempt=$((task_attempt + 1))
  done
  if task_pid_running "$task_pid"; then
    printf 'Portless pid %s did not exit after TERM.\n' "$task_pid" >&2
    task_stop_failed=1
  fi
done

[ "$task_stop_failed" -eq 0 ]
