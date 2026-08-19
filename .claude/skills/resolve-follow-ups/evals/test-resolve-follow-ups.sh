#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
SKILL_DIR=$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)
DISPATCHER="$SKILL_DIR/scripts/resolve-follow-ups.sh"

fail() {
  printf 'FAIL: %s\n' "$1" >&2
  exit 1
}

assert_eq() {
  local expected=$1
  local actual=$2
  local message=$3
  if [[ "$expected" != "$actual" ]]; then
    printf 'Expected:\n%s\nActual:\n%s\n' "$expected" "$actual" >&2
    fail "$message"
  fi
}

new_repo() {
  local root=$1
  git -C "$root" init -q
  git -C "$root" config user.email eval@example.com
  git -C "$root" config user.name 'Resolve Follow-ups Eval'
  mkdir -p "$root/docs/follow-ups"
}

write_follow_up() {
  local path=$1
  local title=$2
  cat >"$path" <<EOF
# $title

**Symptom**: $title happened.

**Observed evidence**: Running ./verify.sh exits 1 in the fixture.

**Suspected cause**: The fixture value may be stale.

**What was tried**: Restarting left the value unchanged.

**Proposed next step**: Run ./verify.sh and repair the fixture value.
EOF
}

commit_at() {
  local root=$1
  local date=$2
  local message=$3
  git -C "$root" add docs/follow-ups
  GIT_AUTHOR_DATE="$date" GIT_COMMITTER_DATE="$date" \
    git -C "$root" commit -qm "$message"
}

test_list_limits_candidates_and_reports_invalid_items() {
  local sandbox
  sandbox=$(mktemp -d)
  local repo="$sandbox/repo"
  local remote="$sandbox/remote.git"
  local coordinator="$sandbox/coordinator"
  local shallow="$sandbox/shallow"
  mkdir -p "$repo"
  new_repo "$repo"

  write_follow_up "$repo/docs/follow-ups/first.md" 'First symptom'
  commit_at "$repo" '2026-01-01T00:00:00Z' 'docs: record first follow-up'
  write_follow_up "$repo/docs/follow-ups/second.md" 'Second symptom'
  commit_at "$repo" '2026-01-02T00:00:00Z' 'docs: record second follow-up'
  git -C "$repo" branch -M main
  git init -q --bare "$remote"
  git -C "$remote" symbolic-ref HEAD refs/heads/main
  git -C "$repo" remote add origin "$remote"
  git -C "$repo" push -qu origin main
  git clone -q "$remote" "$coordinator"

  write_follow_up "$repo/docs/follow-ups/third.md" 'Third symptom'
  commit_at "$repo" '2026-01-03T00:00:00Z' 'docs: record third follow-up'
  write_follow_up "$repo/docs/follow-ups/fourth.md" 'Fourth symptom'
  commit_at "$repo" '2026-01-04T00:00:00Z' 'docs: record fourth follow-up'
  printf '%s\n' \
    '# Empty required fields' \
    '**Symptom**:   ' \
    '**Observed evidence**:   ' \
    '**Suspected cause**:   ' \
    '**What was tried**:   ' \
    '**Proposed next step**:   ' \
    >"$repo/docs/follow-ups/invalid.md"
  commit_at "$repo" '2026-01-05T00:00:00Z' 'docs: record invalid follow-up'
  git -C "$repo" push -qu origin main
  local remote_sha
  remote_sha=$(git -C "$repo" rev-parse HEAD)

  local actual
  actual=$("$DISPATCHER" list --repo "$coordinator" --limit 3)
  local expected=$'candidate\tdocs/follow-ups/first.md\ncandidate\tdocs/follow-ups/second.md\ncandidate\tdocs/follow-ups/third.md\ninvalid-follow-up\tdocs/follow-ups/invalid.md'
  assert_eq "$expected" "$actual" \
    'list should select the three oldest valid follow-ups and report invalid files'

  local all_items
  all_items=$("$DISPATCHER" list --repo "$coordinator")
  local expected_all=$'candidate\tdocs/follow-ups/first.md\ncandidate\tdocs/follow-ups/second.md\ncandidate\tdocs/follow-ups/third.md\ncandidate\tdocs/follow-ups/fourth.md\ninvalid-follow-up\tdocs/follow-ups/invalid.md'
  assert_eq "$expected_all" "$all_items" \
    'list should fetch the ordered remote backlog so a stale coordinator does not miss newer candidates'
  if "$DISPATCHER" identity \
    --repo "$coordinator" \
    --follow-up docs/follow-ups/invalid.md >/dev/null 2>&1; then
    fail 'identity should reject whitespace-only required follow-up fields'
  fi
  local old_second_identity old_second_path old_second_base old_second_key
  old_second_identity=$(
    "$DISPATCHER" identity \
      --repo "$coordinator" \
      --follow-up docs/follow-ups/second.md
  )
  IFS=$'\t' read -r _ old_second_path old_second_base old_second_key \
    <<<"$old_second_identity"
  local old_second_claim old_second_owner
  old_second_claim=$(
    "$DISPATCHER" claim \
      --repo "$coordinator" \
      --follow-up "$old_second_path" \
      --base-sha "$old_second_base"
  )
  IFS=$'\t' read -r _ _ old_second_owner <<<"$old_second_claim"
  "$DISPATCHER" mark \
    --repo "$coordinator" \
    --follow-up "$old_second_path" \
    --base-sha "$old_second_base" \
    --owner "$old_second_owner" \
    --outcome pull-request \
    --detail 'https://github.com/example/repo/pull/old-second' >/dev/null
  local remote_only_identity
  remote_only_identity=$(
    "$DISPATCHER" identity \
      --repo "$coordinator" \
      --follow-up docs/follow-ups/third.md
  )
  [[ "$remote_only_identity" == $'eligible\tdocs/follow-ups/third.md\t'"$remote_sha"$'\t'* ]] \
    || fail 'a remotely listed follow-up should remain actionable when it is absent from the stale checkout'

  git -C "$repo" rm -q docs/follow-ups/second.md
  commit_at "$repo" '2026-01-06T00:00:00Z' 'docs: retire second follow-up'
  write_follow_up "$repo/docs/follow-ups/second.md" 'Second symptom returned'
  commit_at "$repo" '2026-01-07T00:00:00Z' 'docs: record recurring second follow-up'
  git -C "$repo" push -qu origin main
  local recreated
  recreated=$("$DISPATCHER" list --repo "$coordinator")
  local expected_recreated=$'candidate\tdocs/follow-ups/first.md\ncandidate\tdocs/follow-ups/third.md\ncandidate\tdocs/follow-ups/fourth.md\ncandidate\tdocs/follow-ups/second.md\ninvalid-follow-up\tdocs/follow-ups/invalid.md'
  assert_eq "$expected_recreated" "$recreated" \
    'a re-created follow-up should use the latest addition that begins its current lifetime'
  local recreated_identity
  recreated_identity=$(
    "$DISPATCHER" identity \
      --repo "$coordinator" \
      --follow-up docs/follow-ups/second.md
  )
  [[ "$recreated_identity" == $'eligible\tdocs/follow-ups/second.md\t'* ]] \
    || fail 'a re-created follow-up should not inherit a prior lifetime pull-request outcome'

  git clone -q --depth 1 "file://$remote" "$shallow"
  assert_eq 'true' "$(git -C "$shallow" rev-parse --is-shallow-repository)" \
    'the shallow-history fixture should begin as a shallow clone'
  local shallow_items
  shallow_items=$("$DISPATCHER" list --repo "$shallow")
  assert_eq "$expected_recreated" "$shallow_items" \
    'list should restore enough history to preserve discovery order in a shallow clone'
  assert_eq 'false' "$(git -C "$shallow" rev-parse --is-shallow-repository)" \
    'list should unshallow the coordinator before computing discovery time'
  rm -rf "$sandbox"
}

test_attempt_claims_are_atomic_and_terminal_state_is_immutable() {
  local sandbox
  sandbox=$(mktemp -d)
  local repo="$sandbox/repo"
  local remote="$sandbox/remote.git"
  local publisher="$sandbox/publisher"
  local worker="$sandbox/worker"
  mkdir -p "$repo"
  new_repo "$repo"
  write_follow_up "$repo/docs/follow-ups/first.md" 'First symptom'
  dd if=/dev/zero bs=1024 count=256 2>/dev/null \
    | tr '\0' x >>"$repo/docs/follow-ups/first.md"
  commit_at "$repo" '2026-01-01T00:00:00Z' 'docs: record first follow-up'
  git -C "$repo" branch -M main
  git init -q --bare "$remote"
  git -C "$remote" symbolic-ref HEAD refs/heads/main
  git -C "$repo" remote add origin "$remote"
  git -C "$repo" push -qu origin main

  git clone -q "$remote" "$publisher"
  git -C "$publisher" config user.email eval@example.com
  git -C "$publisher" config user.name 'Resolve Follow-ups Eval'
  printf 'remote update\n' >"$publisher/remote-update.txt"
  git -C "$publisher" add remote-update.txt
  GIT_AUTHOR_DATE='2026-01-02T00:00:00Z' GIT_COMMITTER_DATE='2026-01-02T00:00:00Z' \
    git -C "$publisher" commit -qm 'test: advance remote main'
  git -C "$publisher" push -qu origin main
  local remote_sha
  remote_sha=$(git -C "$publisher" rev-parse HEAD)

  local identity
  identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/first.md)
  local identity_prefix=$'eligible\tdocs/follow-ups/first.md\t'"$remote_sha"$'\t'
  [[ "$identity" == "$identity_prefix"* ]] \
    || fail 'identity should resolve an eligible follow-up against fresh remote state'
  local identity_key=${identity##*$'\t'}

  local protocol_hooks="$sandbox/protocol-hooks"
  local protocol_stderr="$sandbox/protocol-stderr"
  mkdir -p "$protocol_hooks"
  cat >"$protocol_hooks/post-checkout" <<'EOF'
#!/usr/bin/env bash
printf 'checkout hook protocol noise\n'
EOF
  chmod +x "$protocol_hooks/post-checkout"
  git -C "$repo" config core.hooksPath "$protocol_hooks"
  local prepared
  prepared=$(
    "$DISPATCHER" prepare \
      --repo "$repo" \
      --follow-up docs/follow-ups/first.md \
      --worktree "$worker" \
      --branch codex/fix-first \
      2>"$protocol_stderr"
  )
  git -C "$repo" config --unset core.hooksPath
  [[ "$prepared" == $'prepared\t'* ]] \
    || fail 'checkout-hook output should not contaminate prepare protocol stdout'
  [[ "$(grep -c '^checkout hook protocol noise$' "$protocol_stderr")" -eq 2 ]] \
    || fail 'prepare should preserve checkout-hook diagnostics on stderr'
  local status prepared_path prepared_branch base_sha attempt_key owner
  IFS=$'\t' read -r status prepared_path prepared_branch base_sha attempt_key owner <<<"$prepared"
  assert_eq 'prepared' "$status" 'prepare should create an owned worker'
  assert_eq "$worker" "$prepared_path" 'prepare should report its exact worktree'
  assert_eq 'codex/fix-first' "$prepared_branch" 'prepare should report its exact branch'
  assert_eq "$remote_sha" "$base_sha" 'prepare should use the fetched remote default branch'
  assert_eq "$identity_key" "$attempt_key" 'identity and prepare should share one attempt key'
  [[ "$owner" =~ ^[A-Za-z0-9._-]+$ ]] || fail 'prepare should return an owner token'
  assert_eq "$remote_sha" "$(git -C "$worker" rev-parse HEAD)" \
    'prepared worktree should start at the fetched remote default branch'
  local worker_root
  worker_root=$(CDPATH= cd -- "$worker" && pwd -P)

  local duplicate_worker="$sandbox/duplicate-worker"
  local duplicate
  duplicate=$(
    "$DISPATCHER" prepare \
      --repo "$repo" \
      --follow-up docs/follow-ups/first.md \
      --worktree "$duplicate_worker" \
      --branch codex/fix-first-duplicate
  )
  assert_eq $'skipped-unchanged\tdocs/follow-ups/first.md\t'"$base_sha"$'\t'"$attempt_key"$'\tclaimed\t'"$owner"$'\t'"$worker_root"$'\tcodex/fix-first' "$duplicate" \
    'a second sweep should observe the atomic claim and its bound worker instead of creating a duplicate'
  [[ ! -e "$duplicate_worker" ]] || fail 'duplicate claim should not create another worktree'
  if git -C "$repo" show-ref --verify --quiet refs/heads/codex/fix-first-duplicate; then
    fail 'duplicate claim should not create another branch'
  fi

  if "$DISPATCHER" mark \
    --repo "$repo" \
    --follow-up docs/follow-ups/first.md \
    --base-sha "$base_sha" \
    --owner not-the-owner \
    --outcome blocked \
    --detail 'wrong owner must not record this blocker' >/dev/null 2>&1; then
    fail 'mark should reject a worker that does not own the attempt claim'
  fi

  if "$DISPATCHER" mark \
    --repo "$repo" \
    --follow-up docs/follow-ups/first.md \
    --base-sha "$base_sha" \
    --owner "$owner" \
    --outcome not-reproduced >/dev/null 2>&1; then
    fail 'mark should require decisive evidence for a non-PR terminal outcome'
  fi
  if "$DISPATCHER" mark \
    --repo "$repo" \
    --follow-up docs/follow-ups/first.md \
    --base-sha "$base_sha" \
    --owner "$owner" \
    --outcome blocked \
    --detail '   ' >/dev/null 2>&1; then
    fail 'mark should reject whitespace-only terminal evidence'
  fi

  local recorded
  local not_reproduced_detail='./verify.sh exited 0 three times; retry after a captured failing run'
  recorded=$(
    "$DISPATCHER" mark \
      --repo "$repo" \
      --follow-up docs/follow-ups/first.md \
      --base-sha "$base_sha" \
      --owner "$owner" \
      --outcome not-reproduced \
      --detail "$not_reproduced_detail"
  )
  assert_eq $'recorded\t'"$attempt_key"$'\tnot-reproduced\t'"$not_reproduced_detail" "$recorded" \
    'the claim owner should record one terminal outcome with its decisive evidence'
  if "$DISPATCHER" mark \
    --repo "$repo" \
    --follow-up docs/follow-ups/first.md \
    --base-sha "$base_sha" \
    --owner "$owner" \
    --outcome blocked \
    --detail 'later conflicting blocker' >/dev/null 2>&1; then
    fail 'a terminal outcome should not be overwritten by a later result'
  fi
  local skipped
  skipped=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/first.md)
  assert_eq $'skipped-unchanged\tdocs/follow-ups/first.md\t'"$base_sha"$'\t'"$attempt_key"$'\tnot-reproduced\t'"$not_reproduced_detail"$'\towner\t'"$owner"$'\t'"$worker_root"$'\tcodex/fix-first' "$skipped" \
    'identity should expose terminal evidence and exact cleanup ownership'
  if "$DISPATCHER" clear \
    --repo "$repo" \
    --follow-up docs/follow-ups/first.md \
    --base-sha "$base_sha" >/dev/null 2>&1; then
    fail 'clear should reject a non-PR terminal outcome while its worker still exists'
  fi

  printf 'unrelated retry base\n' >"$publisher/retry-base.txt"
  git -C "$publisher" add retry-base.txt
  GIT_AUTHOR_DATE='2026-01-03T00:00:00Z' GIT_COMMITTER_DATE='2026-01-03T00:00:00Z' \
    git -C "$publisher" commit -qm 'test: advance base after non-reproduction'
  git -C "$publisher" push -qu origin main
  local pending_cleanup
  pending_cleanup=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/first.md)
  assert_eq "$skipped" "$pending_cleanup" \
    'a base advance should keep exposing terminal cleanup ownership while its worktree exists'

  "$DISPATCHER" cleanup \
    --repo "$repo" \
    --worktree "$worker" \
    --attempt-key "$attempt_key" \
    --owner "$owner" >/dev/null
  if "$DISPATCHER" clear \
    --repo "$repo" \
    --follow-up docs/follow-ups/first.md \
    --base-sha "$base_sha" >/dev/null 2>&1; then
    fail 'clear should not erase not-reproduced suppression from an unchanged attempt'
  fi
  local retry_identity
  retry_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/first.md)
  local retry_status retry_path retry_base retry_key
  IFS=$'\t' read -r retry_status retry_path retry_base retry_key <<<"$retry_identity"
  assert_eq 'eligible' "$retry_status" \
    'a non-PR terminal outcome should become eligible only after the remote base changes'
  base_sha=$retry_base
  attempt_key=$retry_key

  local claim_one="$sandbox/claim-one"
  local claim_two="$sandbox/claim-two"
  "$DISPATCHER" claim \
    --repo "$repo" \
    --follow-up docs/follow-ups/first.md \
    --base-sha "$base_sha" >"$claim_one" &
  local claim_one_pid=$!
  "$DISPATCHER" claim \
    --repo "$repo" \
    --follow-up docs/follow-ups/first.md \
    --base-sha "$base_sha" >"$claim_two" &
  local claim_two_pid=$!
  wait "$claim_one_pid"
  wait "$claim_two_pid"

  local claimed skipped_claim
  if [[ "$(sed -n '1s/\t.*//p' "$claim_one")" == 'claimed' ]]; then
    claimed=$(<"$claim_one")
    skipped_claim=$(<"$claim_two")
  else
    claimed=$(<"$claim_two")
    skipped_claim=$(<"$claim_one")
  fi
  local claim_status claim_key second_owner
  IFS=$'\t' read -r claim_status claim_key second_owner <<<"$claimed"
  assert_eq 'claimed' "$claim_status" 'exactly one overlapping native worker should claim the attempt'
  assert_eq "$attempt_key" "$claim_key" 'claim should reserve the requested attempt identity'
  assert_eq $'skipped-unchanged\tdocs/follow-ups/first.md\t'"$base_sha"$'\t'"$attempt_key"$'\tclaimed\t'"$second_owner" "$skipped_claim" \
    'the overlapping native worker should observe the winning owner token'

  local native_worker="$sandbox/native-worker"
  git -C "$repo" worktree add -q -b codex/native-first "$native_worker" "$base_sha"
  local bound
  bound=$(
    "$DISPATCHER" bind \
      --repo "$repo" \
      --attempt-key "$attempt_key" \
      --owner "$second_owner" \
      --worktree "$native_worker" \
      --branch codex/native-first
  )
  local native_root
  native_root=$(CDPATH= cd -- "$native_worker" && pwd -P)
  assert_eq $'bound\t'"$attempt_key"$'\t'"$native_root"$'\tcodex/native-first' "$bound" \
    'a native runtime worktree should be bound to the exact winning claim'
  "$DISPATCHER" cleanup \
    --repo "$repo" \
    --worktree "$native_worker" \
    --attempt-key "$attempt_key" \
    --owner "$second_owner" >/dev/null

  printf 'unrelated active base\n' >"$publisher/active-base.txt"
  git -C "$publisher" add active-base.txt
  GIT_AUTHOR_DATE='2026-01-04T00:00:00Z' GIT_COMMITTER_DATE='2026-01-04T00:00:00Z' \
    git -C "$publisher" commit -qm 'test: advance base while attempt is active'
  git -C "$publisher" push -qu origin main
  local active_after_advance
  active_after_advance=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/first.md)
  assert_eq $'skipped-unchanged\tdocs/follow-ups/first.md\t'"$base_sha"$'\t'"$attempt_key"$'\tclaimed\t'"$second_owner"$'\t'"$native_root"$'\tcodex/native-first' "$active_after_advance" \
    'an unchanged active attempt should remain suppressed when unrelated work advances the base'

  local pull_request_url='https://github.com/example/repo/pull/123'
  "$DISPATCHER" mark \
    --repo "$repo" \
    --follow-up docs/follow-ups/first.md \
    --base-sha "$base_sha" \
    --owner "$second_owner" \
    --outcome pull-request \
    --detail "$pull_request_url" >/dev/null
  local skipped_pr
  skipped_pr=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/first.md)
  assert_eq $'skipped-unchanged\tdocs/follow-ups/first.md\t'"$base_sha"$'\t'"$attempt_key"$'\tpull-request\t'"$pull_request_url"$'\towner\t'"$second_owner"$'\t'"$native_root"$'\tcodex/native-first' "$skipped_pr" \
    'an unchanged pull request should retain suppression and cleanup ownership across base advancement'
  local clear_one="$sandbox/clear-one"
  local clear_two="$sandbox/clear-two"
  "$DISPATCHER" clear \
    --repo "$repo" \
    --follow-up docs/follow-ups/first.md \
    --base-sha "$base_sha" >"$clear_one" 2>&1 &
  local clear_one_pid=$!
  "$DISPATCHER" clear \
    --repo "$repo" \
    --follow-up docs/follow-ups/first.md \
    --base-sha "$base_sha" >"$clear_two" 2>&1 &
  local clear_two_pid=$!
  local clear_one_status=0 clear_two_status=0
  wait "$clear_one_pid" || clear_one_status=$?
  wait "$clear_two_pid" || clear_two_status=$?
  [[ "$clear_one_status" -ne "$clear_two_status" ]] \
    || fail 'exactly one concurrent clear should own terminal-state teardown'
  local cleared
  if [[ "$clear_one_status" -eq 0 ]]; then
    cleared=$(<"$clear_one")
  else
    cleared=$(<"$clear_two")
  fi
  assert_eq $'cleared\t'"$attempt_key" "$cleared" \
    'the winning clear should remove only the exact closed pull-request attempt'

  local post_clear_claim
  post_clear_claim=$(
    "$DISPATCHER" claim \
      --repo "$repo" \
      --follow-up docs/follow-ups/first.md \
      --base-sha "$base_sha"
  )
  local post_clear_status post_clear_key post_clear_owner
  IFS=$'\t' read -r post_clear_status post_clear_key post_clear_owner <<<"$post_clear_claim"
  assert_eq 'claimed' "$post_clear_status" \
    'a fresh claim should survive after concurrent clear teardown finishes'
  local stale_guard
  stale_guard=$(printf '999999999\nstale-test-guard\n' | git -C "$repo" hash-object -w --stdin)
  git -C "$repo" update-ref \
    "refs/resolve-follow-ups/guards/$post_clear_key" "$stale_guard"
  "$DISPATCHER" recover \
    --repo "$repo" \
    --attempt-key "$post_clear_key" \
    --owner "$post_clear_owner" >/dev/null
  if git -C "$repo" show-ref --verify --quiet \
    "refs/resolve-follow-ups/guards/$post_clear_key"; then
    fail 'recovery should reclaim a guard whose creating process no longer exists'
  fi

  printf '\nAdditional current evidence.\n' >>"$publisher/docs/follow-ups/first.md"
  git -C "$publisher" add docs/follow-ups/first.md
  GIT_AUTHOR_DATE='2026-01-05T00:00:00Z' GIT_COMMITTER_DATE='2026-01-05T00:00:00Z' \
    git -C "$publisher" commit -qm 'docs: add current reproduction evidence'
  git -C "$publisher" push -qu origin main
  local changed_sha
  changed_sha=$(git -C "$publisher" rev-parse HEAD)
  local changed_worker="$sandbox/changed-worker"
  local changed
  changed=$(
    "$DISPATCHER" prepare \
      --repo "$repo" \
      --follow-up docs/follow-ups/first.md \
      --worktree "$changed_worker" \
      --branch codex/fix-first-changed
  )
  local changed_status changed_path changed_branch changed_base changed_key changed_owner
  IFS=$'\t' read -r changed_status changed_path changed_branch changed_base changed_key changed_owner <<<"$changed"
  assert_eq 'prepared' "$changed_status" 'a changed remote base should create a fresh attempt'
  assert_eq "$changed_sha" "$changed_base" 'fresh attempt should use the changed remote base'
  [[ "$changed_key" != "$attempt_key" ]] || fail 'changed base should produce a new attempt identity'
  "$DISPATCHER" cleanup \
    --repo "$repo" \
    --worktree "$changed_worker" \
    --attempt-key "$changed_key" \
    --owner "$changed_owner" >/dev/null

  rm -rf "$sandbox"
}

test_merge_restored_follow_up_starts_a_new_lifetime() {
  local sandbox
  sandbox=$(mktemp -d)
  local repo="$sandbox/repo"
  local remote="$sandbox/remote.git"
  local coordinator="$sandbox/coordinator"
  mkdir -p "$repo"
  new_repo "$repo"
  printf '*.md diff=follow-up-text\n' >"$repo/.gitattributes"
  git -C "$repo" add .gitattributes
  write_follow_up "$repo/docs/follow-ups/first.md" 'Merge-restored symptom'
  commit_at "$repo" '2026-01-01T00:00:00Z' 'docs: record merge-restored follow-up'
  git -C "$repo" branch -M main
  local original_base
  original_base=$(git -C "$repo" rev-parse HEAD)
  git -C "$repo" branch restore-source
  git init -q --bare "$remote"
  git -C "$remote" symbolic-ref HEAD refs/heads/main
  git -C "$repo" remote add origin "$remote"
  git -C "$repo" push -qu origin main
  git clone -q "$remote" "$coordinator"

  local old_identity old_path old_base old_key old_claim old_owner
  old_identity=$(
    "$DISPATCHER" identity \
      --repo "$coordinator" \
      --follow-up docs/follow-ups/first.md
  )
  IFS=$'\t' read -r _ old_path old_base old_key <<<"$old_identity"
  old_claim=$(
    "$DISPATCHER" claim \
      --repo "$coordinator" \
      --follow-up "$old_path" \
      --base-sha "$old_base"
  )
  IFS=$'\t' read -r _ _ old_owner <<<"$old_claim"
  "$DISPATCHER" mark \
    --repo "$coordinator" \
    --follow-up "$old_path" \
    --base-sha "$old_base" \
    --owner "$old_owner" \
    --outcome pull-request \
    --detail 'https://github.com/example/repo/pull/merge-restored' >/dev/null

  git -C "$repo" rm -q docs/follow-ups/first.md
  git -C "$repo" commit -qm 'docs: retire merge-restored follow-up'
  git -C "$repo" switch -q restore-source
  printf '\nSide-branch investigation preserved this item.\n' \
    >>"$repo/docs/follow-ups/first.md"
  git -C "$repo" add docs/follow-ups/first.md
  git -C "$repo" commit -qm 'docs: investigate follow-up on side branch'
  git -C "$repo" switch -q main
  if git -C "$repo" merge --no-ff --no-commit restore-source >/dev/null 2>&1; then
    fail 'merge-restoration fixture should require an explicit delete/modify resolution'
  fi
  git -C "$repo" checkout "$original_base" -- docs/follow-ups/first.md
  git -C "$repo" add docs/follow-ups/first.md
  git -C "$repo" commit -qm 'docs: restore follow-up through merge'
  local nonce
  for nonce in $(seq 1 100); do
    git -C "$repo" commit --allow-empty -qm "test: advance restored history $nonce"
  done
  local restored_base
  restored_base=$(git -C "$repo" rev-parse HEAD)
  git -C "$repo" push -qu origin main

  local wrapper_dir="$sandbox/bin"
  local git_calls="$sandbox/git-calls"
  local real_git
  mkdir -p "$wrapper_dir"
  real_git=$(command -v git)
  : >"$git_calls"
  cat >"$wrapper_dir/git" <<'EOF'
#!/usr/bin/env bash
printf x >>"$GIT_CALLS"
exec "$REAL_GIT" "$@"
EOF
  chmod +x "$wrapper_dir/git"
  local restored_identity
  git -C "$coordinator" config \
    diff.follow-up-text.textconv /definitely/missing/follow-up-textconv
  restored_identity=$(
    REAL_GIT="$real_git" GIT_CALLS="$git_calls" PATH="$wrapper_dir:$PATH" \
      "$DISPATCHER" identity \
      --repo "$coordinator" \
      --follow-up docs/follow-ups/first.md
  )
  [[ "$restored_identity" == $'eligible\tdocs/follow-ups/first.md\t'"$restored_base"$'\t'* ]] \
    || fail 'a follow-up restored against the default-branch parent should begin a fresh lifetime'
  [[ "$(wc -c <"$git_calls" | tr -d ' ')" -lt 50 ]] \
    || fail 'lifetime lookup should use batched history queries instead of one Git process per commit'

  rm -rf "$sandbox"
}

test_cleanup_preserves_a_racing_untracked_write() {
  local sandbox
  sandbox=$(mktemp -d)
  local repo="$sandbox/repo"
  local remote="$sandbox/remote.git"
  local worker="$sandbox/worker"
  local wrapper_dir="$sandbox/bin"
  mkdir -p "$repo" "$wrapper_dir"
  new_repo "$repo"
  write_follow_up "$repo/docs/follow-ups/first.md" 'Cleanup race symptom'
  commit_at "$repo" '2026-01-01T00:00:00Z' 'docs: record cleanup race follow-up'
  git -C "$repo" branch -M main
  git init -q --bare "$remote"
  git -C "$remote" symbolic-ref HEAD refs/heads/main
  git -C "$repo" remote add origin "$remote"
  git -C "$repo" push -qu origin main

  local prepared prep_status prep_path prep_branch prep_base attempt_key owner
  prepared=$(
    "$DISPATCHER" prepare \
      --repo "$repo" \
      --follow-up docs/follow-ups/first.md \
      --worktree "$worker" \
      --branch codex/cleanup-race
  )
  IFS=$'\t' read -r \
    prep_status prep_path prep_branch prep_base attempt_key owner <<<"$prepared"

  local real_git
  real_git=$(command -v git)
  cat >"$wrapper_dir/git" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *' worktree remove '* ]]; then
  printf 'racing write\n' >"$RACE_WORKTREE/race.txt"
fi
exec "$REAL_GIT" "$@"
EOF
  chmod +x "$wrapper_dir/git"
  if REAL_GIT="$real_git" RACE_WORKTREE="$worker" PATH="$wrapper_dir:$PATH" \
    "$DISPATCHER" cleanup \
      --repo "$repo" \
      --worktree "$worker" \
      --attempt-key "$attempt_key" \
      --owner "$owner" >/dev/null 2>&1; then
    fail 'cleanup should let Git preserve a write racing the final removal'
  fi
  [[ -f "$worker/race.txt" ]] \
    || fail 'cleanup should preserve the untracked file that raced its final removal'
  git -C "$worker" clean -fdq
  "$DISPATCHER" cleanup \
    --repo "$repo" \
    --worktree "$worker" \
    --attempt-key "$attempt_key" \
    --owner "$owner" >/dev/null
  [[ ! -e "$worker" ]] || fail 'cleanup should succeed after the racing write is reconciled'

  rm -rf "$sandbox"
}

test_reftable_submodule_cleanup_uses_matching_shadow_metadata() {
  if ! git init -h 2>&1 | grep -q -- '--ref-format'; then
    return 0
  fi

  local sandbox
  sandbox=$(mktemp -d)
  local repo="$sandbox/repo"
  local submodule_repo="$sandbox/submodule-repo"
  local remote="$sandbox/remote.git"
  local worker="$sandbox/worker"
  mkdir -p "$repo/docs/follow-ups" "$submodule_repo"
  git -C "$repo" init -q --object-format=sha256 --ref-format=reftable
  git -C "$repo" config user.email eval@example.com
  git -C "$repo" config user.name 'Resolve Follow-ups Eval'
  git -C "$submodule_repo" init -q
  git -C "$submodule_repo" config user.email eval@example.com
  git -C "$submodule_repo" config user.name 'Resolve Follow-ups Eval'
  printf 'submodule fixture\n' >"$submodule_repo/fixture.txt"
  git -C "$submodule_repo" add fixture.txt
  git -C "$submodule_repo" commit -qm 'test: add submodule fixture'
  write_follow_up "$repo/docs/follow-ups/first.md" 'Reftable cleanup symptom'
  git -C "$repo" -c protocol.file.allow=always submodule add -q \
    "$submodule_repo" fixture-submodule
  git -C "$repo" add .
  git -C "$repo" commit -qm 'test: record reftable cleanup fixture'
  git -C "$repo" branch -M main
  git init -q --bare --object-format=sha256 "$remote"
  git -C "$remote" symbolic-ref HEAD refs/heads/main
  git -C "$repo" remote add origin "$remote"
  git -C "$repo" push -qu origin main

  local prepared prep_status prep_path prep_branch prep_base attempt_key owner
  prepared=$(
    "$DISPATCHER" prepare \
      --repo "$repo" \
      --follow-up docs/follow-ups/first.md \
      --worktree "$worker" \
      --branch codex/reftable-cleanup
  )
  IFS=$'\t' read -r \
    prep_status prep_path prep_branch prep_base attempt_key owner <<<"$prepared"
  git -C "$worker" -c protocol.file.allow=always submodule update --init -q
  "$DISPATCHER" cleanup \
    --repo "$repo" \
    --worktree "$worker" \
    --attempt-key "$attempt_key" \
    --owner "$owner" >/dev/null
  [[ ! -e "$worker" ]] \
    || fail 'submodule cleanup should support a reftable-backed superproject'

  rm -rf "$sandbox"
}

test_cleanup_requires_exact_attempt_ownership() {
  local sandbox
  sandbox=$(mktemp -d)
  local repo="$sandbox/repo"
  local remote="$sandbox/remote.git"
  mkdir -p "$repo"
  new_repo "$repo"
  write_follow_up "$repo/docs/follow-ups/first.md" 'First symptom'
  write_follow_up "$repo/docs/follow-ups/second.md" 'Second symptom'
  write_follow_up "$repo/docs/follow-ups/third.md" 'Third symptom'
  write_follow_up "$repo/docs/follow-ups/fourth.md" 'Fourth symptom'
  write_follow_up "$repo/docs/follow-ups/fifth.md" 'Fifth symptom'
  write_follow_up "$repo/docs/follow-ups/sixth.md" 'Sixth symptom'
  write_follow_up "$repo/docs/follow-ups/seventh.md" 'Seventh symptom'
  local submodule_repo="$sandbox/submodule-repo"
  mkdir -p "$submodule_repo"
  git -C "$submodule_repo" init -q
  git -C "$submodule_repo" config user.email eval@example.com
  git -C "$submodule_repo" config user.name 'Resolve Follow-ups Eval'
  printf 'submodule fixture\n' >"$submodule_repo/fixture.txt"
  git -C "$submodule_repo" add fixture.txt
  git -C "$submodule_repo" commit -qm 'test: add submodule fixture'
  git -C "$repo" -c protocol.file.allow=always submodule add -q \
    "$submodule_repo" fixture-submodule
  commit_at "$repo" '2026-01-01T00:00:00Z' 'docs: record cleanup follow-ups'
  git -C "$repo" branch -M main
  git init -q --bare "$remote"
  git -C "$remote" symbolic-ref HEAD refs/heads/main
  git -C "$repo" remote add origin "$remote"
  git -C "$repo" push -qu origin main

  local first_worker="$sandbox/first-worker"
  local first
  first=$(
    "$DISPATCHER" prepare \
      --repo "$repo" \
      --follow-up docs/follow-ups/first.md \
      --worktree "$first_worker" \
      --branch codex/fix-first
  )
  local s1 p1 b1 base1 key1 owner1
  IFS=$'\t' read -r s1 p1 b1 base1 key1 owner1 <<<"$first"

  local second_worker="$sandbox/second-worker"
  local second
  second=$(
    "$DISPATCHER" prepare \
      --repo "$repo" \
      --follow-up docs/follow-ups/second.md \
      --worktree "$second_worker" \
      --branch codex/fix-second
  )
  local s2 p2 b2 base2 key2 owner2
  IFS=$'\t' read -r s2 p2 b2 base2 key2 owner2 <<<"$second"
  local second_root
  second_root=$(CDPATH= cd -- "$second_worker" && pwd -P)

  if "$DISPATCHER" cleanup \
    --repo "$repo" \
    --worktree "$second_worker" \
    --attempt-key "$key1" \
    --owner "$owner1" >/dev/null 2>&1; then
    fail 'cleanup should refuse another worker even when it shares the same base SHA'
  fi
  [[ -d "$second_worker" ]] || fail 'ownership mismatch should preserve the other worker'

  if "$DISPATCHER" recover \
    --repo "$repo" \
    --attempt-key "$key2" \
    --owner "$owner2" >/dev/null 2>&1; then
    fail 'recover should refuse an attempt whose bound worker still exists'
  fi

  git -C "$repo" remote set-url origin "$sandbox/unavailable.git"
  git -C "$second_worker" -c protocol.file.allow=always submodule update --init -q
  git -C "$repo" config submodule.fixture-submodule.update rebase
  local shared_submodule_url
  shared_submodule_url=$(git -C "$repo" config --get submodule.fixture-submodule.url)
  [[ -z "$(git -C "$second_worker" status --porcelain --ignore-submodules=none)" ]] \
    || fail 'initialized submodule cleanup fixture should remain clean'
  "$DISPATCHER" cleanup \
    --repo "$repo" \
    --worktree "$second_worker" \
    --attempt-key "$key2" \
    --owner "$owner2" >/dev/null
  [[ ! -e "$second_worker" ]] \
    || fail 'owned no-change cleanup should not depend on remote availability'
  assert_eq "$shared_submodule_url" \
    "$(git -C "$repo" config --get submodule.fixture-submodule.url)" \
    'worker cleanup should preserve the repository-wide submodule URL'
  assert_eq 'rebase' \
    "$(git -C "$repo" config --get submodule.fixture-submodule.update)" \
    'worker cleanup should preserve custom repository-wide submodule settings'
  [[ -f "$repo/fixture-submodule/fixture.txt" ]] \
    || fail 'worker cleanup should not deinitialize the primary checkout submodule'
  git -C "$repo" remote set-url origin "$remote"
  local abandoned
  abandoned=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/second.md)
  assert_eq $'skipped-unchanged\tdocs/follow-ups/second.md\t'"$base2"$'\t'"$key2"$'\tclaimed\t'"$owner2"$'\t'"$second_root"$'\tcodex/fix-second' "$abandoned" \
    'identity should expose enough bound-worker state to recover an interrupted attempt'
  if "$DISPATCHER" recover \
    --repo "$repo" \
    --attempt-key "$key2" \
    --owner not-the-owner >/dev/null 2>&1; then
    fail 'recover should reject a worker that does not own the abandoned claim'
  fi
  local recover_one="$sandbox/recover-one"
  local recover_two="$sandbox/recover-two"
  "$DISPATCHER" recover \
    --repo "$repo" \
    --attempt-key "$key2" \
    --owner "$owner2" >"$recover_one" 2>&1 &
  local recover_one_pid=$!
  "$DISPATCHER" recover \
    --repo "$repo" \
    --attempt-key "$key2" \
    --owner "$owner2" >"$recover_two" 2>&1 &
  local recover_two_pid=$!
  local recover_one_status=0 recover_two_status=0
  wait "$recover_one_pid" || recover_one_status=$?
  wait "$recover_two_pid" || recover_two_status=$?
  [[ "$recover_one_status" -ne "$recover_two_status" ]] \
    || fail 'exactly one concurrent recover should own active-state teardown'
  local recovered
  if [[ "$recover_one_status" -eq 0 ]]; then
    recovered=$(<"$recover_one")
  else
    recovered=$(<"$recover_two")
  fi
  assert_eq $'recovered\t'"$key2" "$recovered" \
    'the winning recover should release the interrupted claim after its worker is gone'
  local recovered_identity
  recovered_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/second.md)
  [[ "$recovered_identity" == $'eligible\tdocs/follow-ups/second.md\t'* ]] \
    || fail 'a recovered interrupted claim should become eligible again'

  local unavailable_output
  git -C "$repo" remote set-url origin "$sandbox/unavailable.git"
  if unavailable_output=$(
    "$DISPATCHER" prepare \
      --repo "$repo" \
      --follow-up docs/follow-ups/third.md \
      --worktree "$sandbox/unavailable-worker" \
      --branch codex/unavailable-base 2>&1
  ); then
    fail 'prepare should stop when the remote default branch cannot be resolved'
  fi
  [[ "$unavailable_output" == *'cannot resolve the default branch for remote: origin'* ]] \
    || fail 'prepare should report the unavailable remote as an explicit base blocker'
  [[ ! -e "$sandbox/unavailable-worker" ]] \
    || fail 'remote-base failure should not create a worktree'
  git -C "$repo" remote set-url origin "$remote"

  local fetch_failure_bin="$sandbox/fetch-failure-bin"
  local real_git
  real_git=$(command -v git)
  mkdir -p "$fetch_failure_bin"
  cat >"$fetch_failure_bin/git" <<EOF
#!/usr/bin/env bash
for arg in "\$@"; do
  if [[ "\$arg" == fetch ]]; then
    printf 'injected fetch failure\n' >&2
    exit 41
  fi
done
exec "$real_git" "\$@"
EOF
  chmod +x "$fetch_failure_bin/git"
  local fetch_failure_output
  if fetch_failure_output=$(
    PATH="$fetch_failure_bin:$PATH" "$DISPATCHER" list --repo "$repo" 2>&1
  ); then
    fail 'list should stop instead of using a stale tracking ref after fetch fails'
  fi
  [[ "$fetch_failure_output" == *'cannot fetch remote default branch: origin/main'* ]] \
    || fail 'a remote fetch failure should be reported as an explicit fresh-base blocker'

  if "$DISPATCHER" prepare \
    --repo "$repo" \
    --follow-up docs/follow-ups/third.md \
    --worktree "$sandbox/detached-marker-worker" \
    --branch '(detached)' >/dev/null 2>&1; then
    fail 'prepare should reserve the detached-worktree marker for internal state only'
  fi
  local worktree_failure_bin="$sandbox/worktree-failure-bin"
  mkdir -p "$worktree_failure_bin"
  cat >"$worktree_failure_bin/git" <<EOF
#!/usr/bin/env bash
previous=''
for arg in "\$@"; do
  if [[ "\$previous" == worktree && "\$arg" == add ]]; then
    printf 'injected worktree creation failure\n' >&2
    exit 42
  fi
  previous="\$arg"
done
exec "$real_git" "\$@"
EOF
  chmod +x "$worktree_failure_bin/git"
  local failed_worker="$sandbox/failed-create-worker"
  if PATH="$worktree_failure_bin:$PATH" "$DISPATCHER" prepare \
    --repo "$repo" \
    --follow-up docs/follow-ups/third.md \
    --worktree "$failed_worker" \
    --branch codex/failed-create >/dev/null 2>&1; then
    fail 'prepare should fail when git worktree creation fails'
  fi
  [[ ! -e "$failed_worker" ]] \
    || fail 'failed worktree creation should not leave a checkout path'
  if git -C "$repo" show-ref --verify --quiet refs/heads/codex/failed-create; then
    fail 'failed worktree creation should not leave a local branch that blocks retries'
  fi
  local third_identity
  third_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/third.md)
  [[ "$third_identity" == $'eligible\tdocs/follow-ups/third.md\t'* ]] \
    || fail 'failed worktree creation should release its attempt claim'

  local hooks="$sandbox/hooks"
  mkdir -p "$hooks"
  cat >"$hooks/post-checkout" <<'EOF'
#!/usr/bin/env bash
printf 'generated by checkout hook\n' >generated-by-hook.txt
EOF
  chmod +x "$hooks/post-checkout"
  git -C "$repo" config core.hooksPath "$hooks"
  git -C "$repo" config status.showUntrackedFiles no
  local dirty_worker="$sandbox/dirty-worker"
  local dirty_output
  if dirty_output=$(
    "$DISPATCHER" prepare \
      --repo "$repo" \
      --follow-up docs/follow-ups/fourth.md \
      --worktree "$dirty_worker" \
      --branch codex/dirty-prepared 2>&1
  ); then
    fail 'prepare should reject a worktree dirtied by a checkout hook'
  fi
  git -C "$repo" config --unset core.hooksPath
  git -C "$repo" config --unset status.showUntrackedFiles
  [[ "$dirty_output" == *'worker worktree is dirty after branch setup'* ]] \
    || fail 'dirty prepare should report the failed cleanliness gate'
  local dirty_key dirty_owner
  dirty_key=$(sed -n 's/.*attempt-key \([0-9a-f]*\) owner .*/\1/p' <<<"$dirty_output")
  dirty_owner=$(sed -n 's/.* owner \([A-Za-z0-9._-]*\) requires owned cleanup.*/\1/p' <<<"$dirty_output")
  [[ -n "$dirty_key" && -n "$dirty_owner" ]] \
    || fail 'dirty prepare should expose the exact recovery ownership'
  local dirty_identity
  dirty_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/fourth.md)
  local dirty_status dirty_path dirty_base
  IFS=$'\t' read -r dirty_status dirty_path dirty_base _ <<<"$dirty_identity"
  [[ "$dirty_identity" == $'skipped-unchanged\tdocs/follow-ups/fourth.md\t'*$'\tblocked\tworker worktree is dirty after branch setup\towner\t'* ]] \
    || fail 'dirty prepare should become a terminal blocker instead of dispatching contaminated changes'
  git -C "$dirty_worker" clean -fdq
  "$DISPATCHER" cleanup \
    --repo "$repo" \
    --worktree "$dirty_worker" \
    --attempt-key "$dirty_key" \
    --owner "$dirty_owner" >/dev/null
  if "$DISPATCHER" clear \
    --repo "$repo" \
    --follow-up "$dirty_path" \
    --base-sha "$dirty_base" >/dev/null 2>&1; then
    fail 'clear should preserve a blocked result until the follow-up content or base changes'
  fi

  local fifth_identity
  fifth_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/fifth.md)
  local fifth_status fifth_path fifth_base fifth_key
  IFS=$'\t' read -r fifth_status fifth_path fifth_base fifth_key <<<"$fifth_identity"
  local fifth_claim
  fifth_claim=$(
    "$DISPATCHER" claim \
      --repo "$repo" \
      --follow-up "$fifth_path" \
      --base-sha "$fifth_base"
  )
  local fifth_claim_status fifth_claim_key fifth_owner
  IFS=$'\t' read -r fifth_claim_status fifth_claim_key fifth_owner <<<"$fifth_claim"
  local delimited_native="$sandbox/delimited"$'\t'worker
  git -C "$repo" worktree add -q -b codex/delimited-native \
    "$delimited_native" "$fifth_base"
  if "$DISPATCHER" bind \
    --repo "$repo" \
    --attempt-key "$fifth_key" \
    --owner "$fifth_owner" \
    --worktree "$delimited_native" \
    --branch codex/delimited-native >/dev/null 2>&1; then
    fail 'bind should reject a canonical worktree path containing a protocol delimiter'
  fi
  git -C "$repo" worktree remove "$delimited_native"
  local dirty_native="$sandbox/dirty-native"
  git -C "$repo" config core.hooksPath "$hooks"
  git -C "$repo" worktree add -q -b codex/dirty-native "$dirty_native" "$fifth_base"
  git -C "$repo" config --unset core.hooksPath
  if "$DISPATCHER" bind \
    --repo "$repo" \
    --attempt-key "$fifth_key" \
    --owner "$fifth_owner" \
    --worktree "$dirty_native" \
    --branch codex/dirty-native >/dev/null 2>&1; then
    fail 'bind should reject a native worktree dirtied by a checkout hook'
  fi
  git -C "$dirty_native" clean -fdq
  git -C "$repo" worktree remove "$dirty_native"
  "$DISPATCHER" recover \
    --repo "$repo" \
    --attempt-key "$fifth_key" \
    --owner "$fifth_owner" >/dev/null

  cat >"$hooks/post-checkout" <<'EOF'
#!/usr/bin/env bash
git branch codex/hook-conflict HEAD >/dev/null 2>&1 || true
EOF
  chmod +x "$hooks/post-checkout"
  git -C "$repo" config core.hooksPath "$hooks"
  local raced_worker="$sandbox/raced-worker"
  if "$DISPATCHER" prepare \
    --repo "$repo" \
    --follow-up docs/follow-ups/third.md \
    --worktree "$raced_worker" \
    --branch codex/hook-conflict >/dev/null 2>&1; then
    fail 'prepare should stop when another process creates the branch during worktree setup'
  fi
  git -C "$repo" config --unset core.hooksPath
  [[ ! -e "$raced_worker" ]] \
    || fail 'post-creation setup failure should remove only the unbound worktree it created'
  git -C "$repo" show-ref --verify --quiet refs/heads/codex/hook-conflict \
    || fail 'prepare should preserve a branch created by another process during setup'
  third_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/third.md)
  [[ "$third_identity" == $'eligible\tdocs/follow-ups/third.md\t'* ]] \
    || fail 'safe post-creation failure should release the attempt claim for retry'

  local hook_count="$sandbox/post-checkout-count"
  cat >"$hooks/post-checkout" <<EOF
#!/usr/bin/env bash
count=0
if [[ -f "$hook_count" ]]; then
  count=\$(sed -n '1p' "$hook_count")
fi
count=\$((count + 1))
printf '%s\n' "\$count" >"$hook_count"
if [[ "\$count" -eq 2 ]]; then
  git -c user.email=eval@example.com -c user.name='Resolve Follow-ups Eval' \\
    commit --allow-empty -qm 'test: mutate head after branch switch'
fi
EOF
  chmod +x "$hooks/post-checkout"
  git -C "$repo" config core.hooksPath "$hooks"
  local switched_worker="$sandbox/switched-worker"
  if "$DISPATCHER" prepare \
    --repo "$repo" \
    --follow-up docs/follow-ups/third.md \
    --worktree "$switched_worker" \
    --branch codex/post-switch-mismatch >/dev/null 2>&1; then
    fail 'prepare should revalidate HEAD after switching to the worker branch'
  fi
  git -C "$repo" config --unset core.hooksPath
  [[ ! -e "$switched_worker" ]] \
    || fail 'a clean post-switch mismatch should remove its unbound worktree'
  if git -C "$repo" show-ref --verify --quiet refs/heads/codex/post-switch-mismatch; then
    fail 'a safely removed post-switch mismatch should delete only the branch created by prepare'
  fi
  third_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/third.md)
  [[ "$third_identity" == $'eligible\tdocs/follow-ups/third.md\t'* ]] \
    || fail 'a safely removed post-switch mismatch should release its claim'

  local failed_switch_count="$sandbox/failed-switch-count"
  cat >"$hooks/post-checkout" <<EOF
#!/usr/bin/env bash
count=0
if [[ -f "$failed_switch_count" ]]; then
  count=\$(sed -n '1p' "$failed_switch_count")
fi
count=\$((count + 1))
printf '%s\n' "\$count" >"$failed_switch_count"
if [[ "\$count" -eq 2 ]]; then
  git -c user.email=eval@example.com -c user.name='Resolve Follow-ups Eval' \\
    commit --allow-empty -qm 'test: fail after mutating switched branch'
  exit 1
fi
EOF
  chmod +x "$hooks/post-checkout"
  git -C "$repo" config core.hooksPath "$hooks"
  local failed_switch_worker="$sandbox/failed-switch-worker"
  if "$DISPATCHER" prepare \
    --repo "$repo" \
    --follow-up docs/follow-ups/third.md \
    --worktree "$failed_switch_worker" \
    --branch codex/failed-switch >/dev/null 2>&1; then
    fail 'prepare should stop when branch setup changes HEAD and reports failure'
  fi
  git -C "$repo" config --unset core.hooksPath
  [[ ! -e "$failed_switch_worker" ]] \
    || fail 'failed branch setup should remove its clean unbound worktree'
  if git -C "$repo" show-ref --verify --quiet refs/heads/codex/failed-switch; then
    fail 'failed branch setup should delete the branch created by prepare with a head CAS'
  fi
  third_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/third.md)
  [[ "$third_identity" == $'eligible\tdocs/follow-ups/third.md\t'* ]] \
    || fail 'failed branch setup should release its claim after safe cleanup'

  cat >"$hooks/post-checkout" <<'EOF'
#!/usr/bin/env bash
git -c user.email=eval@example.com -c user.name='Resolve Follow-ups Eval' \
  commit --allow-empty -qm 'test: mutate prepared head'
printf 'hook dirtied worker\n' >post-checkout-dirty.txt
EOF
  chmod +x "$hooks/post-checkout"
  git -C "$repo" config core.hooksPath "$hooks"
  local mismatched_worker="$sandbox/mismatched-worker"
  local mismatch_output
  if mismatch_output=$(
    "$DISPATCHER" prepare \
      --repo "$repo" \
      --follow-up docs/follow-ups/third.md \
      --worktree "$mismatched_worker" \
      --branch codex/hook-mismatch 2>&1
  ); then
    fail 'prepare should stop when a creation hook changes the verified base'
  fi
  git -C "$repo" config --unset core.hooksPath
  [[ "$mismatch_output" == *'attempt-key '* && "$mismatch_output" == *'owner '* ]] \
    || fail 'an unsafe post-creation failure should expose recovery ownership in its error'
  third_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/third.md)
  [[ "$third_identity" == $'skipped-unchanged\tdocs/follow-ups/third.md\t'*$'\tblocked\t'* ]] \
    || fail 'an unremovable post-creation failure should become terminal instead of remaining claimed'

  git -C "$first_worker" config user.email eval@example.com
  git -C "$first_worker" config user.name 'Resolve Follow-ups Eval'
  printf 'verified fix\n' >"$first_worker/fix.txt"
  git -C "$first_worker" add fix.txt
  git -C "$first_worker" commit -qm 'fix: resolve first symptom'
  if "$DISPATCHER" cleanup \
    --repo "$repo" \
    --worktree "$first_worker" \
    --attempt-key "$key1" \
    --owner "$owner1" >/dev/null 2>&1; then
    fail 'cleanup should refuse an owned worker whose changed HEAD is not published'
  fi
  git -C "$first_worker" push -qu origin codex/fix-first
  local first_head
  first_head=$(git -C "$first_worker" rev-parse HEAD)
  local cleaned
  cleaned=$(
    "$DISPATCHER" cleanup \
      --repo "$repo" \
      --worktree "$first_worker" \
      --attempt-key "$key1" \
      --owner "$owner1"
  )
  assert_eq $'cleaned\t'"$first_worker"$'\tcodex/fix-first\t'"$first_head" "$cleaned" \
    'cleanup should remove the exact owned worker after its changed HEAD is published'
  [[ ! -e "$first_worker" ]] || fail 'successful cleanup should remove the owned worktree'
  assert_eq "$first_head" "$(git -C "$repo" rev-parse refs/heads/codex/fix-first)" \
    'cleanup should retain the local branch instead of racing another checkout to delete it'

  if "$DISPATCHER" recover \
    --repo "$repo" \
    --attempt-key "$key1" \
    --owner "$owner1" >/dev/null 2>&1; then
    fail 'recover should refuse a published worker branch before its pull request is reconciled'
  fi
  "$DISPATCHER" mark \
    --repo "$repo" \
    --follow-up docs/follow-ups/first.md \
    --base-sha "$base1" \
    --owner "$owner1" \
    --outcome pull-request \
    --detail 'https://github.com/example/repo/pull/456' >/dev/null

  local corrupt_count="$sandbox/corrupt-post-checkout-count"
  cat >"$hooks/post-checkout" <<EOF
#!/usr/bin/env bash
count=0
if [[ -f "$corrupt_count" ]]; then
  count=\$(sed -n '1p' "$corrupt_count")
fi
count=\$((count + 1))
printf '%s\n' "\$count" >"$corrupt_count"
if [[ "\$count" -eq 2 ]]; then
  printf 'corrupt index' >"\$(git rev-parse --git-path index)"
fi
EOF
  chmod +x "$hooks/post-checkout"
  git -C "$repo" config core.hooksPath "$hooks"
  local corrupt_worker="$sandbox/corrupt-worker"
  local corrupt_output
  if corrupt_output=$(
    "$DISPATCHER" prepare \
      --repo "$repo" \
      --follow-up docs/follow-ups/sixth.md \
      --worktree "$corrupt_worker" \
      --branch codex/corrupt-status 2>&1
  ); then
    fail 'prepare should reject a worker whose clean status cannot be inspected'
  fi
  git -C "$repo" config --unset core.hooksPath
  [[ "$corrupt_output" == *'cannot inspect worker worktree after branch setup'* ]] \
    || fail 'status inspection failure should be an explicit preparation blocker'
  local corrupt_identity
  corrupt_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/sixth.md)
  [[ "$corrupt_identity" == $'skipped-unchanged\tdocs/follow-ups/sixth.md\t'*$'\tblocked\tcannot inspect worker worktree after branch setup\towner\t'* ]] \
    || fail 'an unverifiable worker should never be reported as prepared'

  local missing_worker="$sandbox/missing-worker"
  local missing_prepared
  missing_prepared=$(
    "$DISPATCHER" prepare \
      --repo "$repo" \
      --follow-up docs/follow-ups/seventh.md \
      --worktree "$missing_worker" \
      --branch codex/missing-worker
  )
  local missing_status missing_path missing_branch missing_base missing_key missing_owner
  IFS=$'\t' read -r missing_status missing_path missing_branch missing_base \
    missing_key missing_owner <<<"$missing_prepared"
  local common_dir missing_state
  common_dir=$(git -C "$repo" rev-parse --git-common-dir)
  if [[ "$common_dir" != /* ]]; then
    common_dir="$repo/$common_dir"
  fi
  missing_state="$common_dir/resolve-follow-ups/attempts/$missing_key"
  local missing_root
  missing_root=$(CDPATH= cd -- "$missing_path" && pwd -P)
  printf '%s\n%s\n%s\n' "$missing_root" "$missing_branch" prepare \
    >"$missing_state/target"
  rm "$missing_state/binding"
  git -C "$repo" update-ref -d "refs/heads/$missing_branch" "$missing_base"
  rm -rf "$missing_worker"
  git -C "$repo" worktree list --porcelain \
    | grep -Fqx "worktree $missing_root" \
    || fail 'missing-path recovery fixture should retain its Git worktree registration'
  "$DISPATCHER" recover \
    --repo "$repo" \
    --attempt-key "$missing_key" \
    --owner "$missing_owner" >/dev/null
  if git -C "$repo" worktree list --porcelain \
    | grep -Fqx "worktree $missing_root"; then
    fail 'recover should prune the exact missing worktree registration before retry'
  fi
  local missing_retry
  missing_retry=$(
    "$DISPATCHER" identity \
      --repo "$repo" \
      --follow-up docs/follow-ups/seventh.md
  )
  [[ "$missing_retry" == $'eligible\tdocs/follow-ups/seventh.md\t'* ]] \
    || fail 'a missing registered target should become eligible after recovery'

  rm -rf "$sandbox"
}

test_rewritten_history_ignores_pruned_non_pr_attempts() {
  local sandbox
  sandbox=$(mktemp -d)
  local repo="$sandbox/repo"
  local remote="$sandbox/remote.git"
  local publisher="$sandbox/publisher"
  mkdir -p "$repo"
  new_repo "$repo"
  write_follow_up "$repo/docs/follow-ups/first.md" 'Rewritten-history symptom'
  commit_at "$repo" '2026-01-01T00:00:00Z' 'docs: record rewrite follow-up'
  git -C "$repo" branch -M main
  git init -q --bare "$remote"
  git -C "$remote" symbolic-ref HEAD refs/heads/main
  git -C "$repo" remote add origin "$remote"
  git -C "$repo" push -qu origin main
  local old_base
  old_base=$(git -C "$repo" rev-parse HEAD)

  local old_identity old_path old_key old_claim old_owner
  old_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/first.md)
  IFS=$'\t' read -r _ old_path _ old_key <<<"$old_identity"
  old_claim=$(
    "$DISPATCHER" claim \
      --repo "$repo" \
      --follow-up "$old_path" \
      --base-sha "$old_base"
  )
  IFS=$'\t' read -r _ _ old_owner <<<"$old_claim"
  "$DISPATCHER" mark \
    --repo "$repo" \
    --follow-up "$old_path" \
    --base-sha "$old_base" \
    --owner "$old_owner" \
    --outcome not-reproduced \
    --detail 'old base did not reproduce' >/dev/null

  git clone -q "$remote" "$publisher"
  git -C "$publisher" config user.email eval@example.com
  git -C "$publisher" config user.name 'Resolve Follow-ups Eval'
  git -C "$publisher" checkout -q --orphan rewritten
  git -C "$publisher" rm -qr --cached .
  printf '1\n' >"$publisher/rewrite-generation.txt"
  git -C "$publisher" add .
  git -C "$publisher" commit -qm 'test: rewrite default branch'
  local new_base new_blob new_key nonce
  for nonce in $(seq 1 100); do
    printf '%s\n' "$nonce" >"$publisher/rewrite-generation.txt"
    git -C "$publisher" add rewrite-generation.txt
    git -C "$publisher" commit -q --amend --no-edit
    new_base=$(git -C "$publisher" rev-parse HEAD)
    new_blob=$(git -C "$publisher" rev-parse "$new_base:$old_path")
    new_key=$(printf '%s\n%s\n%s\n' "$old_path" "$new_base" "$new_blob" \
      | git -C "$publisher" hash-object --stdin)
    [[ "$old_key" < "$new_key" ]] && break
  done
  [[ "$old_key" < "$new_key" ]] \
    || fail 'rewrite fixture could not order the stale claim before the current claim'
  git -C "$publisher" branch -M main
  git -C "$publisher" push -qf origin main

  local new_identity new_path new_claim new_owner
  new_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/first.md)
  IFS=$'\t' read -r _ new_path new_base new_key <<<"$new_identity"
  new_claim=$(
    "$DISPATCHER" claim \
      --repo "$repo" \
      --follow-up "$new_path" \
      --base-sha "$new_base"
  )
  IFS=$'\t' read -r _ _ new_owner <<<"$new_claim"
  "$DISPATCHER" mark \
    --repo "$repo" \
    --follow-up "$new_path" \
    --base-sha "$new_base" \
    --owner "$new_owner" \
    --outcome not-reproduced \
    --detail 'rewritten base did not reproduce' >/dev/null

  git -C "$repo" update-ref refs/heads/main "$new_base"
  git -C "$repo" reflog expire --expire=now --expire-unreachable=now --all
  git -C "$repo" gc --prune=now --quiet
  if git -C "$repo" cat-file -e "$old_base^{commit}" 2>/dev/null; then
    fail 'rewrite fixture should prune the stale attempt base before identity lookup'
  fi
  local current_identity
  current_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/first.md)
  assert_eq $'skipped-unchanged\t'"$new_path"$'\t'"$new_base"$'\t'"$new_key"$'\tnot-reproduced\trewritten base did not reproduce\towner\t'"$new_owner" \
    "$current_identity" \
    'identity should ignore an obsolete non-PR claim whose rewritten base was pruned'

  rm -rf "$sandbox"
}

test_coordination_failures_remain_owned_and_recoverable() {
  local sandbox
  sandbox=$(mktemp -d)
  local repo="$sandbox/repo"
  local remote="$sandbox/remote.git"
  local hooks="$sandbox/hooks"
  mkdir -p "$repo" "$hooks"
  new_repo "$repo"
  write_follow_up "$repo/docs/follow-ups/first.md" 'First coordination symptom'
  write_follow_up "$repo/docs/follow-ups/second.md" 'Second coordination symptom'
  write_follow_up "$repo/docs/follow-ups/third.md" 'Third coordination symptom'
  write_follow_up "$repo/docs/follow-ups/fourth.md" 'Fourth coordination symptom'
  write_follow_up "$repo/docs/follow-ups/fifth.md" 'Fifth coordination symptom'
  commit_at "$repo" '2026-01-01T00:00:00Z' 'docs: record coordination follow-ups'
  git -C "$repo" branch -M main
  git init -q --bare "$remote"
  git -C "$remote" symbolic-ref HEAD refs/heads/main
  git -C "$repo" remote add origin "$remote"
  git -C "$repo" push -qu origin main
  local base_sha
  base_sha=$(git -C "$repo" rev-parse HEAD)

  local shared_worker="$sandbox/shared-worker"
  local fourth_identity fifth_identity fourth_key fifth_key
  fourth_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/fourth.md)
  fifth_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/fifth.md)
  IFS=$'\t' read -r _ _ _ fourth_key <<<"$fourth_identity"
  IFS=$'\t' read -r _ _ _ fifth_key <<<"$fifth_identity"
  local fourth_claim fifth_claim fourth_owner fifth_owner
  fourth_claim=$(
    "$DISPATCHER" claim \
      --repo "$repo" \
      --follow-up docs/follow-ups/fourth.md \
      --base-sha "$base_sha"
  )
  fifth_claim=$(
    "$DISPATCHER" claim \
      --repo "$repo" \
      --follow-up docs/follow-ups/fifth.md \
      --base-sha "$base_sha"
  )
  IFS=$'\t' read -r _ _ fourth_owner <<<"$fourth_claim"
  IFS=$'\t' read -r _ _ fifth_owner <<<"$fifth_claim"
  git -C "$repo" worktree add -q -b codex/shared-worker "$shared_worker" "$base_sha"
  local failing_git_dir="$sandbox/failing-git"
  local real_git
  real_git=$(command -v git)
  mkdir -p "$failing_git_dir"
  cat >"$failing_git_dir/git" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *' hash-object -w --stdin '* ]]; then
  exit 91
fi
exec "$REAL_GIT" "$@"
EOF
  chmod +x "$failing_git_dir/git"
  if REAL_GIT="$real_git" PATH="$failing_git_dir:$PATH" "$DISPATCHER" bind \
    --repo "$repo" \
    --attempt-key "$fourth_key" \
    --owner "$fourth_owner" \
    --worktree "$shared_worker" \
    --branch codex/shared-worker >/dev/null 2>&1; then
    fail 'bind interruption fixture should stop after persisting its target'
  fi
  local fourth_interrupted
  fourth_interrupted=$(
    "$DISPATCHER" identity \
      --repo "$repo" \
      --follow-up docs/follow-ups/fourth.md
  )
  [[ "$fourth_interrupted" == *$'\tclaimed\t'"$fourth_owner"$'\t'* ]] \
    || fail 'interrupted bind should retain exact target ownership'
  "$DISPATCHER" bind \
    --repo "$repo" \
    --attempt-key "$fifth_key" \
    --owner "$fifth_owner" \
    --worktree "$shared_worker" \
    --branch codex/shared-worker >/dev/null
  if "$DISPATCHER" cleanup \
    --repo "$repo" \
    --worktree "$shared_worker" \
    --attempt-key "$fourth_key" \
    --owner "$fourth_owner" >/dev/null 2>&1; then
    fail 'abandoned target cleanup should not remove a checkout reserved by another attempt'
  fi
  [[ -d "$shared_worker" ]] \
    || fail 'reservation mismatch must be detected before destructive worktree removal'
  "$DISPATCHER" cleanup \
    --repo "$repo" \
    --worktree "$shared_worker" \
    --attempt-key "$fifth_key" \
    --owner "$fifth_owner" >/dev/null
  "$DISPATCHER" recover \
    --repo "$repo" \
    --attempt-key "$fifth_key" \
    --owner "$fifth_owner" >/dev/null
  "$DISPATCHER" recover \
    --repo "$repo" \
    --attempt-key "$fourth_key" \
    --owner "$fourth_owner" >/dev/null

  git -C "$repo" update-ref refs/resolve-follow-ups/content "$base_sha"
  local reservation_output
  if reservation_output=$(
    "$DISPATCHER" claim \
      --repo "$repo" \
      --follow-up docs/follow-ups/first.md \
      --base-sha "$base_sha" 2>&1
  ); then
    fail 'a conflicting coordination ref should fail instead of spinning forever'
  fi
  [[ "$reservation_output" == *'cannot reserve follow-up content after bounded retries'* ]] \
    || fail 'persistent content-ref failure should report its bounded reservation blocker'
  local reservation_key reservation_owner
  reservation_key=$(sed -n 's/.*attempt-key \([0-9a-f]*\) owner .*/\1/p' <<<"$reservation_output")
  reservation_owner=$(sed -n 's/.* owner \([A-Za-z0-9._-]*\) can be recovered.*/\1/p' <<<"$reservation_output")
  [[ -n "$reservation_key" && -n "$reservation_owner" ]] \
    || fail 'reservation failure should retain exact recoverable ownership'
  git -C "$repo" update-ref -d refs/resolve-follow-ups/content "$base_sha"
  "$DISPATCHER" recover \
    --repo "$repo" \
    --attempt-key "$reservation_key" \
    --owner "$reservation_owner" >/dev/null

  cat >"$hooks/post-checkout" <<'EOF'
#!/usr/bin/env bash
printf 'left by failed checkout hook\n' >partial-hook-output.txt
exit 1
EOF
  chmod +x "$hooks/post-checkout"
  git -C "$repo" config core.hooksPath "$hooks"
  local partial_worker="$sandbox/partial-worker"
  local partial_output
  if partial_output=$(
    "$DISPATCHER" prepare \
      --repo "$repo" \
      --follow-up docs/follow-ups/second.md \
      --worktree "$partial_worker" \
      --branch codex/partial-worker 2>&1
  ); then
    fail 'partial worktree creation should never be reported as prepared'
  fi
  git -C "$repo" config --unset core.hooksPath
  [[ "$partial_output" == *'failed to create worker worktree'* ]] \
    || fail 'partial worktree creation should retain its explicit failure evidence'
  local partial_key partial_owner
  partial_key=$(sed -n 's/.*attempt-key \([0-9a-f]*\) owner .*/\1/p' <<<"$partial_output")
  partial_owner=$(sed -n 's/.* owner \([A-Za-z0-9._-]*\) requires owned cleanup.*/\1/p' <<<"$partial_output")
  [[ -n "$partial_key" && -n "$partial_owner" ]] \
    || fail 'a leaked partial checkout should remain bound to exact recovery ownership'
  [[ -d "$partial_worker" ]] || fail 'the partial-checkout fixture should leave its registered worker'
  local partial_identity
  partial_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/second.md)
  [[ "$partial_identity" == $'skipped-unchanged\tdocs/follow-ups/second.md\t'*$'\tblocked\tfailed to create worker worktree:'*$'\towner\t'* ]] \
    || fail 'a partial checkout should suppress duplicate attempts until owned cleanup'
  git -C "$partial_worker" clean -fdq
  local partial_cleaned
  partial_cleaned=$(
    "$DISPATCHER" cleanup \
      --repo "$repo" \
      --worktree "$partial_worker" \
      --attempt-key "$partial_key" \
      --owner "$partial_owner"
  )
  [[ "$partial_cleaned" == $'cleaned\t'*$'\t(detached)\t'"$base_sha" ]] \
    || fail 'owned cleanup should remove a clean partial detached worktree at its base'

  cat >"$hooks/post-checkout" <<'EOF'
#!/usr/bin/env bash
sleep 3
EOF
  chmod +x "$hooks/post-checkout"
  git -C "$repo" config core.hooksPath "$hooks"
  local interrupted_worker="$sandbox/interrupted-worker"
  local interrupted_log="$sandbox/interrupted-prepare.log"
  "$DISPATCHER" prepare \
    --repo "$repo" \
    --follow-up docs/follow-ups/third.md \
    --worktree "$interrupted_worker" \
    --branch codex/interrupted-worker >"$interrupted_log" 2>&1 &
  local interrupted_pid=$!
  local wait_count
  for wait_count in $(seq 1 100); do
    [[ -d "$interrupted_worker" ]] && break
    sleep 0.05
  done
  [[ -d "$interrupted_worker" ]] \
    || fail 'interrupted prepare fixture should reach worktree creation'
  kill -9 "$interrupted_pid" 2>/dev/null || true
  wait "$interrupted_pid" 2>/dev/null || true
  sleep 4
  git -C "$repo" config --unset core.hooksPath

  local interrupted_identity
  interrupted_identity=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/third.md)
  local interrupted_status interrupted_path interrupted_base interrupted_key
  local interrupted_state interrupted_owner interrupted_target interrupted_branch
  IFS=$'\t' read -r interrupted_status interrupted_path interrupted_base interrupted_key \
    interrupted_state interrupted_owner interrupted_target interrupted_branch \
    <<<"$interrupted_identity"
  assert_eq 'claimed' "$interrupted_state" \
    'interrupted prepare should retain active ownership instead of launching a duplicate'
  assert_eq 'codex/interrupted-worker' "$interrupted_branch" \
    'interrupted prepare should retain its planned branch for cleanup'
  assert_eq "$interrupted_base" "$(git -C "$interrupted_worker" rev-parse HEAD)" \
    'interrupted prepare fixture should leave the exact claimed checkout'
  local interrupted_cleaned
  interrupted_cleaned=$(
    "$DISPATCHER" cleanup \
      --repo "$repo" \
      --worktree "$interrupted_target" \
      --attempt-key "$interrupted_key" \
      --owner "$interrupted_owner"
  )
  [[ "$interrupted_cleaned" == $'cleaned\t'*$'\t(detached)\t'"$interrupted_base" ]] \
    || fail 'cleanup should remove the persisted detached target from interrupted prepare'
  "$DISPATCHER" recover \
    --repo "$repo" \
    --attempt-key "$interrupted_key" \
    --owner "$interrupted_owner" >/dev/null
  local interrupted_retry
  interrupted_retry=$("$DISPATCHER" identity --repo "$repo" --follow-up docs/follow-ups/third.md)
  [[ "$interrupted_retry" == $'eligible\tdocs/follow-ups/third.md\t'* ]] \
    || fail 'interrupted prepare should become eligible after exact cleanup and recovery'

  rm -rf "$sandbox"
}

test_list_limits_candidates_and_reports_invalid_items
test_attempt_claims_are_atomic_and_terminal_state_is_immutable
test_merge_restored_follow_up_starts_a_new_lifetime
test_cleanup_preserves_a_racing_untracked_write
test_reftable_submodule_cleanup_uses_matching_shadow_metadata
test_cleanup_requires_exact_attempt_ownership
test_coordination_failures_remain_owned_and_recoverable
test_rewritten_history_ignores_pruned_non_pr_attempts
printf 'PASS: resolve-follow-ups dispatcher\n'
