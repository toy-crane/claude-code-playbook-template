#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'triage claim: %s\n' "$1" >&2
  exit 1
}

[[ $# -gt 0 ]] || die 'expected claim, renew, verify, release, status, or recover'
action=$1
shift
repo='.'
remote='origin'
issue=''
expected=''
token=''
while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo|--remote|--issue|--expected|--token)
      [[ $# -ge 2 && -n "$2" ]] || die "missing value for $1"
      case "$1" in
        --repo) repo=$2 ;;
        --remote) remote=$2 ;;
        --issue) issue=$2 ;;
        --expected) expected=$2 ;;
        --token) token=$2 ;;
      esac
      shift 2 ;;
    *) die "unknown option: $1" ;;
  esac
done

[[ -n "$issue" && "$issue" != *$'\n'* ]] || die 'pass a stable tracker-qualified issue ID'
git -C "$repo" rev-parse --git-dir >/dev/null 2>&1 || die "not a Git repository: $repo"
git -C "$repo" remote get-url "$remote" >/dev/null 2>&1 || die "unknown remote: $remote"
issue_hash=$(printf '%s' "$issue" | git -C "$repo" hash-object --stdin)
ref="refs/heads/agent-triage/$issue_hash"

remote_oid() {
  git -C "$repo" ls-remote --refs "$remote" "$ref" \
    | awk -v name="$ref" '$2 == name { print $1; exit }'
}

token_hash() {
  printf '%s' "$1" | git -C "$repo" hash-object --stdin
}

new_token() {
  od -An -N24 -tx1 /dev/urandom | tr -d ' \n'
}

new_commit() {
  local parent=$1
  local owner_hash=$2
  local tree
  tree=$(git -C "$repo" rev-parse "$parent^{tree}")
  printf 'triage claim\n\nissue-hash=%s\nowner-hash=%s\nnonce=%s\n' \
    "$issue_hash" "$owner_hash" "$(new_token)" \
    | git -C "$repo" -c user.name='Triage Agent' \
      -c user.email='triage-agent@localhost' commit-tree "$tree" -p "$parent"
}

validate_expected() {
  [[ "$expected" =~ ^[0-9a-f]{40,64}$ ]] || die 'pass --expected claim commit SHA'
  [[ "$(remote_oid)" == "$expected" ]] || die 'claim revision changed or disappeared'
}

validate_owner() {
  [[ -n "$token" ]] || die 'pass --token returned by claim or recover'
  local message
  message=$(git -C "$repo" show -s --format=%B "$expected" 2>/dev/null) \
    || die 'claim commit unavailable in this checkout'
  [[ "$message" == *"issue-hash=$issue_hash"* ]] || die 'claim belongs to another issue'
  [[ "$message" == *"owner-hash=$(token_hash "$token")"* ]] || die 'claim token does not own this revision'
}

case "$action" in
  status)
    oid=$(remote_oid)
    [[ -n "$oid" ]] || die 'issue has no claim'
    printf '%s\n' "$oid" ;;
  claim)
    [[ -z "$expected" && -z "$token" ]] || die 'claim accepts no expected revision or token'
    token=$(new_token)
    base=$(git -C "$repo" ls-remote "$remote" HEAD | awk '$2 == "HEAD" { print $1; exit }')
    [[ "$base" =~ ^[0-9a-f]{40,64}$ ]] || die 'remote default branch commit unavailable'
    git -C "$repo" fetch --quiet "$remote" "$base" \
      || die 'cannot fetch remote default branch commit'
    git -C "$repo" cat-file -e "$base^{commit}" \
      || die 'remote default branch commit unavailable locally'
    oid=$(new_commit "$base" "$(token_hash "$token")")
    git -C "$repo" push --quiet --force-with-lease="$ref:" "$remote" "$oid:$ref" \
      || die 'another run owns this issue or the remote rejected atomic claims'
    printf '%s %s\n' "$oid" "$token" ;;
  verify)
    validate_expected
    validate_owner
    printf '%s\n' "$expected" ;;
  renew)
    validate_expected
    validate_owner
    oid=$(new_commit "$expected" "$(token_hash "$token")")
    git -C "$repo" push --quiet --force-with-lease="$ref:$expected" "$remote" "$oid:$ref" \
      || die 'claim renewal lost the race'
    printf '%s\n' "$oid" ;;
  release)
    validate_expected
    validate_owner
    git -C "$repo" push --quiet --force-with-lease="$ref:$expected" "$remote" ":$ref" \
      || die 'claim release lost the race' ;;
  recover)
    validate_expected
    [[ -z "$token" ]] || die 'recover creates a new token'
    git -C "$repo" fetch --quiet "$remote" "$ref" \
      || die 'cannot inspect claimed revision'
    claimed_at=$(git -C "$repo" show -s --format=%ct "$expected")
    now=$(date +%s)
    (( now - claimed_at >= 7200 )) || die 'claim is younger than two hours'
    token=$(new_token)
    oid=$(new_commit "$expected" "$(token_hash "$token")")
    git -C "$repo" push --quiet --force-with-lease="$ref:$expected" "$remote" "$oid:$ref" \
      || die 'claim recovery lost the race'
    printf '%s %s\n' "$oid" "$token" ;;
  *) die "unknown action: $action" ;;
esac
