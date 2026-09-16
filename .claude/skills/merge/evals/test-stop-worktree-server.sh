#!/usr/bin/env bash

set -euo pipefail

task_helper=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/stop-worktree-server.sh
task_eval_root=$(mktemp -d)
task_current_worktree="$task_eval_root/current"
task_other_worktree="$task_eval_root/other"
mkdir -p "$task_current_worktree" "$task_other_worktree"
export task_current_worktree task_other_worktree
task_live_pids=()
task_passed=0

cleanup_eval_processes() {
  for task_pid in "${task_live_pids[@]}"; do
    builtin kill -KILL -- "$task_pid" 2>/dev/null || true
    wait "$task_pid" 2>/dev/null || true
  done
  find "$task_eval_root" -depth -delete 2>/dev/null || true
}
trap cleanup_eval_processes EXIT

start_eval_process() {
  sleep 300 &
  task_started_pid=$!
  task_live_pids+=("$task_started_pid")
}

start_stubborn_process() {
  bash -c 'trap "" TERM; while :; do sleep 1; done' &
  task_started_pid=$!
  task_live_pids+=("$task_started_pid")
  sleep 0.1
}

process_running() {
  task_state=$(ps -p "$1" -o stat= 2>/dev/null | awk 'NR == 1 { print $1 }')
  [ -n "$task_state" ] && [ "${task_state#Z}" = "$task_state" ]
}

assert_alive() {
  process_running "$1" || {
    printf 'expected pid %s to remain alive\n' "$1" >&2
    exit 1
  }
}

assert_stopped() {
  task_attempt=0
  while process_running "$1" && [ "$task_attempt" -lt 20 ]; do
    sleep 0.05
    task_attempt=$((task_attempt + 1))
  done
  if process_running "$1"; then
    printf 'expected pid %s to stop\n' "$1" >&2
    exit 1
  fi
  wait "$1" 2>/dev/null || true
}

expect_helper_failure() {
  if bash "$task_helper"; then
    printf 'expected helper to report failure\n' >&2
    exit 1
  fi
}

git() {
  case "$*" in
    'rev-parse --git-dir') printf '%s\n' "$task_mock_git_dir" ;;
    'rev-parse --git-common-dir') printf '%s\n' "$task_mock_common_dir" ;;
    'rev-parse --show-toplevel') printf '%s\n' "$task_mock_worktree" ;;
    *) return 1 ;;
  esac
}

portless() {
  case "${1:-}" in
    list)
      printf '%b' "$task_mock_routes"
      return "$task_mock_portless_status"
      ;;
    *) return 1 ;;
  esac
}

lsof() {
  task_requested_pid=${3:-}
  case "$task_requested_pid" in
    "$task_mock_owned_pid_one"|"$task_mock_owned_pid_two"|\
    "$task_mock_kill_failure_pid"|"$task_mock_stubborn_pid")
      printf 'p%s\nfcwd\nn%s\n' "$task_requested_pid" "$task_current_worktree"
      ;;
    "$task_mock_unrelated_pid"|"$task_mock_no_match_pid")
      printf 'p%s\nfcwd\nn%s\n' "$task_requested_pid" "$task_other_worktree"
      ;;
    "$task_mock_noinspect_pid")
      return 1
      ;;
    *)
      return 1
      ;;
  esac
}

kill() {
  if [ "${1:-}" = '-TERM' ] \
    && [ "${3:-}" = "${task_mock_kill_failure_pid:-}" ] \
    && [ -n "${task_mock_kill_failure_pid:-}" ]; then
    return 1
  fi
  builtin kill "$@"
}
export -f git portless lsof kill

task_mock_git_dir='.git'
task_mock_common_dir='.git'
task_mock_worktree="$task_current_worktree"
task_mock_routes=''
task_mock_portless_status=0
task_mock_owned_pid_one='none-owned-one'
task_mock_owned_pid_two='none-owned-two'
task_mock_unrelated_pid='none-unrelated'
task_mock_no_match_pid='none-no-match'
task_mock_noinspect_pid='none-noinspect'
task_mock_kill_failure_pid=''
task_mock_stubborn_pid='none-stubborn'
export task_mock_git_dir task_mock_common_dir task_mock_worktree
export task_mock_routes task_mock_portless_status
export task_mock_owned_pid_one task_mock_owned_pid_two task_mock_unrelated_pid
export task_mock_no_match_pid task_mock_noinspect_pid
export task_mock_kill_failure_pid task_mock_stubborn_pid

# A normal checkout is outside the helper's authority.
start_eval_process
task_normal_pid=$task_started_pid
task_mock_routes="https://cart.app.localhost pid $task_normal_pid\n"
export task_mock_routes
bash "$task_helper"
assert_alive "$task_normal_pid"
task_passed=$((task_passed + 1))

# Route protocol, DNS-label length, and duplicate branch prefixes do not affect
# ownership: only process cwd inside the current worktree qualifies.
start_eval_process
task_owned_pid_one=$task_started_pid
start_eval_process
task_owned_pid_two=$task_started_pid
start_eval_process
task_unrelated_pid=$task_started_pid
task_mock_git_dir='.git/worktrees/current'
task_mock_owned_pid_one=$task_owned_pid_one
task_mock_owned_pid_two=$task_owned_pid_two
task_mock_unrelated_pid=$task_unrelated_pid
task_long_label=$(printf 'a%.0s' {1..56})-a1b2c3
test "${#task_long_label}" -eq 63
task_mock_routes="\033[32mhttps://auth.web.localhost\033[0m pid $task_owned_pid_one\nhttp://auth.api.localhost pid $task_unrelated_pid\nhttp://$task_long_label.web.test pid $task_owned_pid_two\nhttps://auth.web.localhost pid $task_owned_pid_one\n"
export task_mock_git_dir task_mock_owned_pid_one task_mock_owned_pid_two
export task_mock_unrelated_pid task_mock_routes
bash "$task_helper"
assert_stopped "$task_owned_pid_one"
assert_stopped "$task_owned_pid_two"
assert_alive "$task_unrelated_pid"
task_passed=$((task_passed + 1))

# A linked worktree with no route owned by its cwd is a safe no-op.
start_eval_process
task_no_match_pid=$task_started_pid
task_mock_no_match_pid=$task_no_match_pid
task_mock_routes="http://auth.other.test pid $task_no_match_pid\n"
export task_mock_no_match_pid task_mock_routes
bash "$task_helper"
assert_alive "$task_no_match_pid"
task_passed=$((task_passed + 1))

# Active routes whose cwd cannot be verified block cleanup.
start_eval_process
task_noinspect_pid=$task_started_pid
task_mock_noinspect_pid=$task_noinspect_pid
task_mock_routes="https://unknown.app.localhost pid $task_noinspect_pid\n"
export task_mock_noinspect_pid task_mock_routes
expect_helper_failure
assert_alive "$task_noinspect_pid"
task_passed=$((task_passed + 1))

# A failed TERM is reported while the server remains available for recovery.
start_eval_process
task_kill_failure_pid=$task_started_pid
task_mock_kill_failure_pid=$task_kill_failure_pid
task_mock_routes="https://owned.app.localhost pid $task_kill_failure_pid\n"
export task_mock_kill_failure_pid task_mock_routes
expect_helper_failure
assert_alive "$task_kill_failure_pid"
task_mock_kill_failure_pid=''
export task_mock_kill_failure_pid
task_passed=$((task_passed + 1))

# Accepting TERM is insufficient: a process that remains running is a failure.
start_stubborn_process
task_stubborn_pid=$task_started_pid
task_mock_stubborn_pid=$task_stubborn_pid
task_mock_routes="http://owned.app.localhost pid $task_stubborn_pid\n"
export task_mock_stubborn_pid task_mock_routes
expect_helper_failure
assert_alive "$task_stubborn_pid"
task_passed=$((task_passed + 1))

# Failure to query Portless state is not a successful no-op.
task_mock_routes='portless state unavailable\n'
task_mock_portless_status=1
export task_mock_routes task_mock_portless_status
expect_helper_failure
task_passed=$((task_passed + 1))

printf 'stop-worktree-server evals passed: %s\n' "$task_passed"
