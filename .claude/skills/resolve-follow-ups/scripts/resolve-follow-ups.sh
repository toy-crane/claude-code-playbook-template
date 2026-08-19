#!/usr/bin/env bash
set -euo pipefail

die() {
  printf 'resolve-follow-ups: %s\n' "$1" >&2
  exit 64
}

usage() {
  cat >&2 <<'EOF'
Usage:
  resolve-follow-ups.sh list --repo PATH [--limit COUNT] [--remote NAME]
  resolve-follow-ups.sh identity --repo PATH --follow-up PATH [--remote NAME]
  resolve-follow-ups.sh claim --repo PATH --follow-up PATH --base-sha SHA
  resolve-follow-ups.sh bind --repo PATH --attempt-key KEY --owner TOKEN --worktree PATH --branch NAME
  resolve-follow-ups.sh prepare --repo PATH --follow-up PATH --worktree PATH --branch NAME [--remote NAME]
  resolve-follow-ups.sh mark --repo PATH --follow-up PATH --base-sha SHA --owner TOKEN --outcome OUTCOME --detail TEXT
  resolve-follow-ups.sh recover --repo PATH --attempt-key KEY --owner TOKEN [--remote NAME]
  resolve-follow-ups.sh clear --repo PATH --follow-up PATH --base-sha SHA
  resolve-follow-ups.sh cleanup --repo PATH --worktree PATH --attempt-key KEY --owner TOKEN [--remote NAME]
EOF
  exit 64
}

require_value() {
  local flag=$1
  local value=${2-}
  [[ -n "$value" ]] || die "$flag requires a value"
}

validate_follow_up() {
  local path=$1
  local field
  for field in 'Symptom' 'Observed evidence' 'Suspected cause' 'What was tried' 'Proposed next step'; do
    grep -Eq "^\\*\\*${field}\\*\\*:[[:space:]]*[^[:space:]]" "$path" || return 1
  done
}

repo_root_for() {
  local repo=$1
  local root
  root=$(git -C "$repo" rev-parse --show-toplevel 2>/dev/null) \
    || die "not a Git repository: $repo"
  (CDPATH= cd -- "$root" && pwd -P)
}

relative_follow_up_path() {
  local repo_root=$1
  local follow_up=$2
  if [[ "$follow_up" == docs/follow-ups/*.md ]]; then
    local leaf=${follow_up#docs/follow-ups/}
    [[ -n "$leaf" && "$leaf" != */* && "$leaf" != *$'\t'* && "$leaf" != *$'\n'* ]] \
      || die 'follow-up must be a Markdown file directly under docs/follow-ups/'
    printf 'docs/follow-ups/%s\n' "$leaf"
    return 0
  fi

  local candidate
  case "$follow_up" in
    /*) candidate=$follow_up ;;
    *) candidate="$repo_root/$follow_up" ;;
  esac

  [[ -f "$candidate" ]] || die "follow-up does not exist: $follow_up"
  local parent
  parent=$(CDPATH= cd -- "$(dirname -- "$candidate")" && pwd -P)
  [[ "$parent" == "$repo_root/docs/follow-ups" ]] \
    || die 'follow-up must be a Markdown file directly under docs/follow-ups/'
  [[ "$candidate" == *.md ]] || die 'follow-up must use the .md extension'
  local relative="docs/follow-ups/$(basename -- "$candidate")"
  [[ "$relative" != *$'\t'* && "$relative" != *$'\n'* ]] \
    || die 'follow-up path cannot contain a tab or newline'
  printf '%s\n' "$relative"
}

remote_default_branch() {
  local repo_root=$1
  local remote=$2
  local branch
  branch=$(
    git -C "$repo_root" ls-remote --symref "$remote" HEAD 2>/dev/null \
      | awk '$1 == "ref:" && $2 ~ /^refs\/heads\// { sub(/^refs\/heads\//, "", $2); print $2; exit }'
  )
  [[ -n "$branch" ]] || die "cannot resolve the default branch for remote: $remote"
  printf '%s\n' "$branch"
}

remote_base() {
  local repo_root=$1
  local remote=$2
  local default_branch
  default_branch=$(remote_default_branch "$repo_root" "$remote")
  local fetch_args=(--prune)
  if [[ "$(git -C "$repo_root" rev-parse --is-shallow-repository)" == true ]]; then
    fetch_args+=(--unshallow)
  fi
  if ! git -C "$repo_root" fetch "${fetch_args[@]}" "$remote" \
    "+refs/heads/$default_branch:refs/remotes/$remote/$default_branch" >/dev/null; then
    die "cannot fetch remote default branch: $remote/$default_branch"
  fi
  local base_sha
  base_sha=$(git -C "$repo_root" rev-parse "refs/remotes/$remote/$default_branch^{commit}")
  printf '%s\t%s\n' "$default_branch" "$base_sha"
}

git_common_dir() {
  local repo_root=$1
  local common
  common=$(git -C "$repo_root" rev-parse --git-common-dir)
  case "$common" in
    /*) (CDPATH= cd -- "$common" && pwd -P) ;;
    *) (CDPATH= cd -- "$repo_root/$common" && pwd -P) ;;
  esac
}

attempt_key_at_base() {
  local repo_root=$1
  local relative=$2
  local base_sha=$3
  git -C "$repo_root" cat-file -e "$base_sha:$relative" 2>/dev/null \
    || die "follow-up is not present at base SHA: $relative"
  local blob_sha
  blob_sha=$(git -C "$repo_root" rev-parse "$base_sha:$relative")
  printf '%s\n%s\n%s\n' "$relative" "$base_sha" "$blob_sha" \
    | git -C "$repo_root" hash-object --stdin
}

validate_attempt_key() {
  local attempt_key=$1
  [[ "$attempt_key" =~ ^[0-9a-f]{40,64}$ ]] \
    || die 'attempt key must be the full hexadecimal key returned by claim or prepare'
}

validate_owner() {
  local owner=$1
  [[ "$owner" =~ ^[A-Za-z0-9._-]+$ ]] \
    || die 'owner must be the token returned by claim or prepare'
}

attempts_dir_for() {
  local repo_root=$1
  printf '%s/resolve-follow-ups/attempts\n' "$(git_common_dir "$repo_root")"
}

claim_file_for() {
  local repo_root=$1
  local attempt_key=$2
  validate_attempt_key "$attempt_key"
  printf '%s/%s.claim\n' "$(attempts_dir_for "$repo_root")" "$attempt_key"
}

state_dir_for() {
  local repo_root=$1
  local attempt_key=$2
  validate_attempt_key "$attempt_key"
  printf '%s/%s\n' "$(attempts_dir_for "$repo_root")" "$attempt_key"
}

follow_up_lifetime_at_base() {
  local repo_root=$1
  local relative=$2
  local base_sha=$3
  git -C "$repo_root" log \
    --no-patch \
    --first-parent \
    --diff-merges=first-parent \
    --diff-filter=A \
    --format=%H \
    "$base_sha" -- "$relative" \
    | sed -n '1p'
}

content_key_at_base() {
  local repo_root=$1
  local relative=$2
  local base_sha=$3
  local blob_sha lifetime_sha
  blob_sha=$(git -C "$repo_root" rev-parse "$base_sha:$relative" 2>/dev/null) \
    || die "cannot resolve follow-up content at base SHA: $relative"
  lifetime_sha=$(follow_up_lifetime_at_base "$repo_root" "$relative" "$base_sha")
  [[ -n "$lifetime_sha" ]] \
    || die "cannot resolve follow-up lifetime at base SHA: $relative"
  printf '%s\n%s\n%s\n' "$relative" "$lifetime_sha" "$blob_sha" \
    | git -C "$repo_root" hash-object --stdin
}

content_ref_at_base() {
  local repo_root=$1
  local relative=$2
  local base_sha=$3
  printf 'refs/resolve-follow-ups/content/%s\n' \
    "$(content_key_at_base "$repo_root" "$relative" "$base_sha")"
}

zero_oid_for() {
  local oid=$1
  printf '%*s' "${#oid}" '' | tr ' ' 0
}

claim_guard_ref_for() {
  local attempt_key=$1
  validate_attempt_key "$attempt_key"
  printf 'refs/resolve-follow-ups/guards/%s\n' "$attempt_key"
}

CLAIM_GUARD_OID=''

acquire_claim_guard() {
  local repo_root=$1
  local attempt_key=$2
  local guard_ref
  guard_ref=$(claim_guard_ref_for "$attempt_key")
  local process_started
  process_started=$(ps -p "$$" -o lstart= 2>/dev/null | sed -n '1p')
  [[ -n "$process_started" ]] || die 'cannot read dispatcher process identity for attempt guard'
  local guard_oid
  guard_oid=$(
    printf '%s\n%s\n%s.%s.%s\n' \
      "$$" "$process_started" "$$" "$RANDOM" "$RANDOM" \
      | git -C "$repo_root" hash-object -w --stdin
  )
  local zero_oid
  zero_oid=$(zero_oid_for "$guard_oid")

  local guard_attempt=0
  while true; do
    guard_attempt=$((guard_attempt + 1))
    if [[ "$guard_attempt" -gt 20 ]]; then
      die "cannot acquire attempt guard after bounded retries: $attempt_key"
    fi
    local current_oid
    current_oid=$(git -C "$repo_root" rev-parse --verify "$guard_ref" 2>/dev/null || true)
    if [[ -z "$current_oid" ]]; then
      if git -C "$repo_root" update-ref "$guard_ref" "$guard_oid" "$zero_oid" 2>/dev/null; then
        CLAIM_GUARD_OID=$guard_oid
        return 0
      fi
      continue
    fi

    local guard_record guard_pid guard_started
    guard_record=$(git -C "$repo_root" cat-file blob "$current_oid" 2>/dev/null) \
      || die "cannot inspect attempt guard: $attempt_key"
    guard_pid=$(sed -n '1p' <<<"$guard_record")
    guard_started=$(sed -n '2p' <<<"$guard_record")
    if [[ "$guard_pid" =~ ^[0-9]+$ ]] && kill -0 "$guard_pid" 2>/dev/null; then
      local current_started
      current_started=$(ps -p "$guard_pid" -o lstart= 2>/dev/null | sed -n '1p')
      if [[ -z "$guard_started" || -z "$current_started" || "$current_started" == "$guard_started" ]]; then
        return 1
      fi
    fi
    git -C "$repo_root" update-ref -d "$guard_ref" "$current_oid" 2>/dev/null || true
  done
}

release_claim_guard() {
  local repo_root=$1
  local attempt_key=$2
  local guard_oid=$3
  local guard_ref
  guard_ref=$(claim_guard_ref_for "$attempt_key")
  git -C "$repo_root" update-ref -d "$guard_ref" "$guard_oid" 2>/dev/null \
    || die "attempt guard changed before release: $attempt_key"
}

claim_field() {
  local claim_file=$1
  local line=$2
  sed -n "${line}p" "$claim_file"
}

assert_claim_identity() {
  local claim_file=$1
  local relative=$2
  local base_sha=$3
  [[ -f "$claim_file" ]] || die "attempt identity is not claimed: ${claim_file##*/}"
  [[ "$(claim_field "$claim_file" 2)" == "$base_sha" ]] \
    || die 'attempt claim base does not match the requested identity'
  [[ "$(claim_field "$claim_file" 3)" == "$relative" ]] \
    || die 'attempt claim follow-up does not match the requested identity'
}

assert_claim_owner() {
  local claim_file=$1
  local owner=$2
  validate_owner "$owner"
  [[ -f "$claim_file" ]] || die "attempt identity is not claimed: ${claim_file##*/}"
  [[ "$(claim_field "$claim_file" 1)" == "$owner" ]] \
    || die 'attempt claim belongs to another worker'
}

print_attempt_state() {
  local repo_root=$1
  local relative=$2
  local base_sha=$3
  local attempt_key=$4
  local claim_file
  claim_file=$(claim_file_for "$repo_root" "$attempt_key")
  assert_claim_identity "$claim_file" "$relative" "$base_sha"

  local state_dir
  state_dir=$(state_dir_for "$repo_root" "$attempt_key")
  local outcome_file="$state_dir/outcome"
  if [[ -f "$outcome_file" ]]; then
    local outcome
    local detail
    local owner
    outcome=$(sed -n '1p' "$outcome_file")
    detail=$(sed -n '2p' "$outcome_file")
    owner=$(claim_field "$claim_file" 1)
    printf 'skipped-unchanged\t%s\t%s\t%s\t%s' \
      "$relative" "$base_sha" "$attempt_key" "$outcome"
    if [[ -n "$detail" ]]; then
      printf '\t%s' "$detail"
    fi
    printf '\towner\t%s' "$owner"
    local terminal_coordinates=''
    if [[ -f "$state_dir/binding" ]]; then
      terminal_coordinates="$state_dir/binding"
    elif [[ -f "$state_dir/target" ]]; then
      terminal_coordinates="$state_dir/target"
    fi
    if [[ -n "$terminal_coordinates" ]]; then
      printf '\t%s\t%s' \
        "$(sed -n '1p' "$terminal_coordinates")" \
        "$(sed -n '2p' "$terminal_coordinates")"
    fi
    printf '\n'
    return 0
  fi

  local binding_file="$state_dir/binding"
  if [[ -f "$binding_file" ]]; then
    printf 'skipped-unchanged\t%s\t%s\t%s\tclaimed\t%s\t%s\t%s\n' \
      "$relative" "$base_sha" "$attempt_key" "$(claim_field "$claim_file" 1)" \
      "$(sed -n '1p' "$binding_file")" "$(sed -n '2p' "$binding_file")"
    return 0
  fi

  local target_file="$state_dir/target"
  if [[ -f "$target_file" ]]; then
    printf 'skipped-unchanged\t%s\t%s\t%s\tclaimed\t%s\t%s\t%s\n' \
      "$relative" "$base_sha" "$attempt_key" "$(claim_field "$claim_file" 1)" \
      "$(sed -n '1p' "$target_file")" "$(sed -n '2p' "$target_file")"
    return 0
  fi

  printf 'skipped-unchanged\t%s\t%s\t%s\tclaimed\t%s\n' \
    "$relative" "$base_sha" "$attempt_key" "$(claim_field "$claim_file" 1)"
}

find_suppressing_attempt() {
  local repo_root=$1
  local relative=$2
  local base_sha=$3
  local current_blob current_lifetime
  current_blob=$(git -C "$repo_root" rev-parse "$base_sha:$relative")
  current_lifetime=$(follow_up_lifetime_at_base "$repo_root" "$relative" "$base_sha")
  [[ -n "$current_lifetime" ]] \
    || die "cannot resolve current follow-up lifetime: $relative"
  local attempts_dir
  attempts_dir=$(attempts_dir_for "$repo_root")
  [[ -d "$attempts_dir" ]] || return 1

  local claim_file
  for claim_file in "$attempts_dir"/*.claim; do
    [[ -f "$claim_file" ]] || continue
    local claimed_base claimed_relative claimed_blob claimed_lifetime
    local attempt_key outcome_file outcome
    claimed_base=$(claim_field "$claim_file" 2)
    claimed_relative=$(claim_field "$claim_file" 3)
    [[ "$claimed_relative" == "$relative" ]] || continue
    claimed_lifetime=$(
      follow_up_lifetime_at_base "$repo_root" "$relative" "$claimed_base" 2>/dev/null \
        || true
    )
    if [[ -z "$claimed_lifetime" ]]; then
      continue
    fi
    if [[ "$claimed_lifetime" != "$current_lifetime" ]]; then
      local stale_content_ref
      stale_content_ref=$(content_ref_at_base "$repo_root" "$relative" "$claimed_base")
      git -C "$repo_root" update-ref -d \
        "$stale_content_ref" "$claimed_base" 2>/dev/null || true
      continue
    fi
    attempt_key=${claim_file##*/}
    attempt_key=${attempt_key%.claim}
    outcome_file="$(state_dir_for "$repo_root" "$attempt_key")/outcome"
    if [[ -f "$outcome_file" ]]; then
      outcome=$(sed -n '1p' "$outcome_file")
      if [[ "$outcome" != pull-request && "$claimed_base" != "$base_sha" ]]; then
        local cleanup_coordinates=''
        if [[ -f "$(state_dir_for "$repo_root" "$attempt_key")/binding" ]]; then
          cleanup_coordinates="$(state_dir_for "$repo_root" "$attempt_key")/binding"
        elif [[ -f "$(state_dir_for "$repo_root" "$attempt_key")/target" ]]; then
          cleanup_coordinates="$(state_dir_for "$repo_root" "$attempt_key")/target"
        fi
        if [[ -n "$cleanup_coordinates" ]]; then
          local outstanding_worktree
          outstanding_worktree=$(sed -n '1p' "$cleanup_coordinates")
          if [[ -e "$outstanding_worktree" || -L "$outstanding_worktree" ]]; then
            print_attempt_state "$repo_root" "$relative" "$claimed_base" "$attempt_key"
            return 0
          fi
        fi
        continue
      fi
    fi
    claimed_blob=$(git -C "$repo_root" rev-parse "$claimed_base:$relative" 2>/dev/null) \
      || die "cannot verify existing follow-up claim: ${claim_file##*/}"
    [[ "$claimed_blob" == "$current_blob" ]] || continue
    print_attempt_state "$repo_root" "$relative" "$claimed_base" "$attempt_key"
    return 0
  done
  return 1
}

resolve_attempt() {
  local repo=$1
  local follow_up=$2
  local remote=$3
  local repo_root
  repo_root=$(repo_root_for "$repo")
  local relative
  relative=$(relative_follow_up_path "$repo_root" "$follow_up")
  local remote_state
  remote_state=$(remote_base "$repo_root" "$remote")
  local default_branch base_sha
  IFS=$'\t' read -r default_branch base_sha <<<"$remote_state"
  git -C "$repo_root" cat-file -e "$base_sha:$relative" 2>/dev/null \
    || die "follow-up is not present on $remote/$default_branch: $relative"

  local field
  for field in 'Symptom' 'Observed evidence' 'Suspected cause' 'What was tried' 'Proposed next step'; do
    grep -Eq "^\\*\\*${field}\\*\\*:[[:space:]]*[^[:space:]]" \
      < <(git -C "$repo_root" show "$base_sha:$relative") \
      || die "follow-up on $remote/$default_branch is missing: $field"
  done

  if find_suppressing_attempt "$repo_root" "$relative" "$base_sha"; then
    return 0
  fi
  local attempt_key
  attempt_key=$(attempt_key_at_base "$repo_root" "$relative" "$base_sha")
  printf 'eligible\t%s\t%s\t%s\n' "$relative" "$base_sha" "$attempt_key"
}

reserve_content_claim() {
  local repo_root=$1
  local relative=$2
  local base_sha=$3
  local attempt_key=$4
  local owner=$5
  local content_ref
  content_ref=$(content_ref_at_base "$repo_root" "$relative" "$base_sha")
  local zero_oid
  zero_oid=$(zero_oid_for "$base_sha")

  local reservation_attempt=0
  while true; do
    reservation_attempt=$((reservation_attempt + 1))
    if [[ "$reservation_attempt" -gt 20 ]]; then
      die "cannot reserve follow-up content after bounded retries; attempt-key $attempt_key owner $owner can be recovered"
    fi
    local reserved_base
    reserved_base=$(git -C "$repo_root" rev-parse --verify "$content_ref^{commit}" 2>/dev/null || true)
    if [[ -z "$reserved_base" ]]; then
      if git -C "$repo_root" update-ref "$content_ref" "$base_sha" "$zero_oid" 2>/dev/null; then
        return 0
      fi
      continue
    fi
    if [[ "$reserved_base" == "$base_sha" ]]; then
      return 0
    fi

    local reserved_key reserved_claim reserved_state outcome
    reserved_key=$(attempt_key_at_base "$repo_root" "$relative" "$reserved_base")
    reserved_claim=$(claim_file_for "$repo_root" "$reserved_key")
    if [[ ! -f "$reserved_claim" ]]; then
      git -C "$repo_root" update-ref -d "$content_ref" "$reserved_base" 2>/dev/null || true
      continue
    fi
    reserved_state=$(state_dir_for "$repo_root" "$reserved_key")
    if [[ ! -f "$reserved_state/outcome" ]]; then
      release_claim "$repo_root" "$attempt_key" "$owner"
      print_attempt_state "$repo_root" "$relative" "$reserved_base" "$reserved_key"
      return 1
    fi
    outcome=$(sed -n '1p' "$reserved_state/outcome")
    if [[ "$outcome" == pull-request ]]; then
      release_claim "$repo_root" "$attempt_key" "$owner"
      print_attempt_state "$repo_root" "$relative" "$reserved_base" "$reserved_key"
      return 1
    fi
    if git -C "$repo_root" update-ref "$content_ref" "$base_sha" "$reserved_base" 2>/dev/null; then
      return 0
    fi
  done
}

create_claim() {
  local repo_root=$1
  local relative=$2
  local base_sha=$3
  local attempt_key=$4
  local attempts_dir
  attempts_dir=$(attempts_dir_for "$repo_root")
  mkdir -p "$attempts_dir"
  local claim_file
  claim_file=$(claim_file_for "$repo_root" "$attempt_key")

  local temp_file
  temp_file=$(mktemp "$attempts_dir/.claim.XXXXXX")
  local owner=${temp_file##*/}
  owner=${owner#.claim.}
  validate_owner "$owner"
  printf '%s\n%s\n%s\n' "$owner" "$base_sha" "$relative" >"$temp_file"

  if ln "$temp_file" "$claim_file" 2>/dev/null; then
    rm "$temp_file"
    mkdir -p "$(state_dir_for "$repo_root" "$attempt_key")"
    if ! reserve_content_claim "$repo_root" "$relative" "$base_sha" "$attempt_key" "$owner"; then
      return 0
    fi
    printf 'claimed\t%s\t%s\n' "$attempt_key" "$owner"
    return 0
  fi

  rm "$temp_file"
  print_attempt_state "$repo_root" "$relative" "$base_sha" "$attempt_key"
}

release_claim() {
  local repo_root=$1
  local attempt_key=$2
  local owner=$3
  local claim_file
  claim_file=$(claim_file_for "$repo_root" "$attempt_key")
  assert_claim_owner "$claim_file" "$owner"
  local state_dir
  state_dir=$(state_dir_for "$repo_root" "$attempt_key")
  [[ ! -e "$state_dir/target" && ! -e "$state_dir/binding" && ! -e "$state_dir/outcome" ]] \
    || die 'cannot release a claim after targeting, binding, or terminal outcome'
  local base_sha relative content_ref
  base_sha=$(claim_field "$claim_file" 2)
  relative=$(claim_field "$claim_file" 3)
  content_ref=$(content_ref_at_base "$repo_root" "$relative" "$base_sha")
  git -C "$repo_root" update-ref -d "$content_ref" "$base_sha" 2>/dev/null || true
  rmdir "$state_dir" 2>/dev/null || true
  rm "$claim_file"
}

identity_attempt() {
  local repo=''
  local follow_up=''
  local remote=origin

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo|--follow-up|--remote)
        require_value "$1" "${2-}"
        case "$1" in
          --repo) repo=$2 ;;
          --follow-up) follow_up=$2 ;;
          --remote) remote=$2 ;;
        esac
        shift 2
        ;;
      *) die "unknown identity option: $1" ;;
    esac
  done

  [[ -n "$repo" ]] || die 'identity requires --repo'
  [[ -n "$follow_up" ]] || die 'identity requires --follow-up'
  resolve_attempt "$repo" "$follow_up" "$remote"
}

claim_attempt() {
  local repo=''
  local follow_up=''
  local base_sha=''

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo|--follow-up|--base-sha)
        require_value "$1" "${2-}"
        case "$1" in
          --repo) repo=$2 ;;
          --follow-up) follow_up=$2 ;;
          --base-sha) base_sha=$2 ;;
        esac
        shift 2
        ;;
      *) die "unknown claim option: $1" ;;
    esac
  done

  [[ -n "$repo" ]] || die 'claim requires --repo'
  [[ -n "$follow_up" ]] || die 'claim requires --follow-up'
  [[ -n "$base_sha" ]] || die 'claim requires --base-sha'
  local repo_root
  repo_root=$(repo_root_for "$repo")
  local relative
  relative=$(relative_follow_up_path "$repo_root" "$follow_up")
  local resolved_base
  resolved_base=$(git -C "$repo_root" rev-parse "$base_sha^{commit}" 2>/dev/null) \
    || die "base SHA is not a commit: $base_sha"
  [[ "$resolved_base" == "$base_sha" ]] \
    || die 'claim requires the full resolved base SHA returned by identity'
  local attempt_key
  attempt_key=$(attempt_key_at_base "$repo_root" "$relative" "$base_sha")
  create_claim "$repo_root" "$relative" "$base_sha" "$attempt_key"
}

list_follow_ups() {
  local repo=''
  local limit=0
  local remote=origin

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo)
        require_value "$1" "${2-}"
        repo=$2
        shift 2
        ;;
      --limit)
        require_value "$1" "${2-}"
        limit=$2
        shift 2
        ;;
      --remote)
        require_value "$1" "${2-}"
        remote=$2
        shift 2
        ;;
      *) die "unknown list option: $1" ;;
    esac
  done

  [[ -n "$repo" ]] || die 'list requires --repo'
  [[ "$limit" =~ ^[0-9]+$ ]] || die '--limit must be a non-negative integer'

  local repo_root
  repo_root=$(repo_root_for "$repo")
  local remote_state
  remote_state=$(remote_base "$repo_root" "$remote")
  local _default_branch base_sha
  IFS=$'\t' read -r _default_branch base_sha <<<"$remote_state"

  local temp_dir
  temp_dir=$(mktemp -d)
  local candidates="$temp_dir/candidates"
  local invalid="$temp_dir/invalid"
  local item="$temp_dir/item"
  : >"$candidates"
  : >"$invalid"

  local relative
  while IFS= read -r -d '' relative; do
    local leaf=${relative#docs/follow-ups/}
    [[ "$leaf" != */* && "$leaf" == *.md ]] || continue
    [[ "$relative" != *$'\t'* && "$relative" != *$'\n'* ]] \
      || die "follow-up path contains a tab or newline: $relative"
    git -C "$repo_root" show "$base_sha:$relative" >"$item"
    if validate_follow_up "$item"; then
      local discovered_at lifetime_sha
      lifetime_sha=$(follow_up_lifetime_at_base "$repo_root" "$relative" "$base_sha")
      discovered_at=$(git -C "$repo_root" show -s --format=%ct "$lifetime_sha")
      [[ -n "$discovered_at" ]] || discovered_at=0
      printf '%020d\t%s\n' "$discovered_at" "$relative" >>"$candidates"
    else
      printf '%s\n' "$relative" >>"$invalid"
    fi
  done < <(git -C "$repo_root" ls-tree -r -z --name-only "$base_sha" -- docs/follow-ups)

  sort -k1,1 -k2,2 "$candidates" \
    | awk -F '\t' -v limit="$limit" 'limit == 0 || NR <= limit { print "candidate\t" $2 }'
  sort "$invalid" | sed 's/^/invalid-follow-up\t/'
  rm -rf "$temp_dir"
}

write_binding() {
  local repo_root=$1
  local attempt_key=$2
  local owner=$3
  local worker_root=$4
  local branch=$5
  local claim_file
  claim_file=$(claim_file_for "$repo_root" "$attempt_key")
  assert_claim_owner "$claim_file" "$owner"
  local state_dir
  state_dir=$(state_dir_for "$repo_root" "$attempt_key")
  mkdir -p "$state_dir"
  local binding_file="$state_dir/binding"
  local attempts_dir
  attempts_dir=$(attempts_dir_for "$repo_root")
  local temp_file
  temp_file=$(mktemp "$attempts_dir/.binding.XXXXXX")
  printf '%s\n%s\n' "$worker_root" "$branch" >"$temp_file"
  if ln "$temp_file" "$binding_file" 2>/dev/null; then
    rm "$temp_file"
    return 0
  fi
  if cmp -s "$temp_file" "$binding_file"; then
    rm "$temp_file"
    return 0
  fi
  rm "$temp_file"
  return 1
}

write_target() {
  local repo_root=$1
  local attempt_key=$2
  local owner=$3
  local worktree=$4
  local branch=$5
  local target_mode=$6
  case "$target_mode" in
    bind|prepare) ;;
    *) die 'worktree target mode must be bind or prepare' ;;
  esac
  local claim_file
  claim_file=$(claim_file_for "$repo_root" "$attempt_key")
  assert_claim_owner "$claim_file" "$owner"
  local state_dir
  state_dir=$(state_dir_for "$repo_root" "$attempt_key")
  mkdir -p "$state_dir"
  local target_file="$state_dir/target"
  local attempts_dir
  attempts_dir=$(attempts_dir_for "$repo_root")
  local temp_file
  temp_file=$(mktemp "$attempts_dir/.target.XXXXXX")
  printf '%s\n%s\n%s\n' "$worktree" "$branch" "$target_mode" >"$temp_file"
  if ln "$temp_file" "$target_file" 2>/dev/null; then
    rm "$temp_file"
    return 0
  fi
  if cmp -s "$temp_file" "$target_file"; then
    rm "$temp_file"
    return 0
  fi
  rm "$temp_file"
  return 1
}

worktree_reservation_ref_for() {
  local repo_root=$1
  local worktree=$2
  local coordinate_key
  coordinate_key=$(printf '%s\n' "$worktree" | git -C "$repo_root" hash-object --stdin)
  printf 'refs/resolve-follow-ups/worktrees/%s\n' "$coordinate_key"
}

worktree_reservation_oid() {
  local repo_root=$1
  local attempt_key=$2
  local owner=$3
  local worktree=$4
  local write=${5-false}
  local hash_args=(hash-object --stdin)
  if [[ "$write" == true ]]; then
    hash_args=(hash-object -w --stdin)
  fi
  printf '%s\n%s\n%s\n' "$attempt_key" "$owner" "$worktree" \
    | git -C "$repo_root" "${hash_args[@]}"
}

WORKTREE_RESERVATION_CREATED=false

reserve_worktree() {
  local repo_root=$1
  local attempt_key=$2
  local owner=$3
  local worktree=$4
  local reservation_ref
  reservation_ref=$(worktree_reservation_ref_for "$repo_root" "$worktree")
  local reservation_oid
  reservation_oid=$(worktree_reservation_oid \
    "$repo_root" "$attempt_key" "$owner" "$worktree" true)
  local zero_oid
  zero_oid=$(zero_oid_for "$reservation_oid")
  WORKTREE_RESERVATION_CREATED=false

  local reservation_attempt=0
  while true; do
    reservation_attempt=$((reservation_attempt + 1))
    if [[ "$reservation_attempt" -gt 20 ]]; then
      die "cannot reserve worker coordinate after bounded retries: $worktree"
    fi
    local current_oid
    current_oid=$(git -C "$repo_root" rev-parse --verify "$reservation_ref" 2>/dev/null || true)
    if [[ -z "$current_oid" ]]; then
      if git -C "$repo_root" update-ref \
        "$reservation_ref" "$reservation_oid" "$zero_oid" 2>/dev/null; then
        WORKTREE_RESERVATION_CREATED=true
        return 0
      fi
      continue
    fi
    if [[ "$current_oid" == "$reservation_oid" ]]; then
      return 0
    fi

    local reserved_record reserved_key reserved_claim
    reserved_record=$(git -C "$repo_root" cat-file blob "$current_oid" 2>/dev/null) \
      || die "cannot inspect worker coordinate reservation: $worktree"
    reserved_key=$(sed -n '1p' <<<"$reserved_record")
    if [[ ! "$reserved_key" =~ ^[0-9a-f]{40,64}$ ]]; then
      die "worker coordinate reservation is malformed: $worktree"
    fi
    reserved_claim=$(claim_file_for "$repo_root" "$reserved_key")
    if [[ -f "$reserved_claim" ]]; then
      return 1
    fi
    git -C "$repo_root" update-ref -d \
      "$reservation_ref" "$current_oid" 2>/dev/null || true
  done
}

release_worktree_reservation() {
  local repo_root=$1
  local attempt_key=$2
  local owner=$3
  local worktree=$4
  local reservation_ref expected_oid
  reservation_ref=$(worktree_reservation_ref_for "$repo_root" "$worktree")
  expected_oid=$(assert_worktree_reservation \
    "$repo_root" "$attempt_key" "$owner" "$worktree" false)
  [[ -n "$expected_oid" ]] || return 0
  git -C "$repo_root" update-ref -d \
    "$reservation_ref" "$expected_oid" 2>/dev/null \
    || die "worker coordinate changed before release: $worktree"
}

assert_worktree_reservation() {
  local repo_root=$1
  local attempt_key=$2
  local owner=$3
  local worktree=$4
  local required=${5-true}
  local reservation_ref
  reservation_ref=$(worktree_reservation_ref_for "$repo_root" "$worktree")
  local expected_oid current_oid
  expected_oid=$(worktree_reservation_oid \
    "$repo_root" "$attempt_key" "$owner" "$worktree")
  current_oid=$(git -C "$repo_root" rev-parse --verify "$reservation_ref" 2>/dev/null || true)
  if [[ -z "$current_oid" ]]; then
    [[ "$required" != true ]] || die "worker coordinate is not reserved: $worktree"
    return 0
  fi
  [[ "$current_oid" == "$expected_oid" ]] \
    || die "worker coordinate belongs to another attempt: $worktree"
  printf '%s\n' "$expected_oid"
}

worktree_is_registered() {
  local repo_root=$1
  local worktree=$2
  git -C "$repo_root" worktree list --porcelain \
    | grep -Fqx "worktree $worktree"
}

write_outcome() {
  local repo_root=$1
  local attempt_key=$2
  local owner=$3
  local outcome=$4
  local detail=$5
  local claim_file
  claim_file=$(claim_file_for "$repo_root" "$attempt_key")
  assert_claim_owner "$claim_file" "$owner"
  local state_dir
  state_dir=$(state_dir_for "$repo_root" "$attempt_key")
  mkdir -p "$state_dir"
  local outcome_file="$state_dir/outcome"
  local attempts_dir
  attempts_dir=$(attempts_dir_for "$repo_root")
  local temp_file
  temp_file=$(mktemp "$attempts_dir/.outcome.XXXXXX")
  printf '%s\n%s\n' "$outcome" "$detail" >"$temp_file"
  if ! acquire_claim_guard "$repo_root" "$attempt_key"; then
    rm "$temp_file"
    return 1
  fi
  local guard_oid=$CLAIM_GUARD_OID
  if ln "$temp_file" "$outcome_file" 2>/dev/null; then
    rm "$temp_file"
    release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
    return 0
  fi
  if cmp -s "$temp_file" "$outcome_file"; then
    rm "$temp_file"
    release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
    return 0
  fi
  rm "$temp_file"
  release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
  return 1
}

remove_unbound_worktree() {
  local repo_root=$1
  local worktree=$2
  [[ -d "$worktree" ]] || return 1
  local worker_root
  worker_root=$(git -C "$worktree" rev-parse --show-toplevel 2>/dev/null) || return 1
  worker_root=$(CDPATH= cd -- "$worker_root" && pwd -P) || return 1
  [[ "$worker_root" != "$repo_root" ]] || return 1
  local worker_common
  worker_common=$(git_common_dir "$worker_root") || return 1
  [[ "$worker_common" == "$(git_common_dir "$repo_root")" ]] || return 1
  local worker_status
  worker_status=$(git -C "$worker_root" status --porcelain --untracked-files=all 2>/dev/null) \
    || return 1
  [[ -z "$worker_status" ]] || return 1
  git -C "$repo_root" worktree remove "$worker_root"
}

fail_after_worktree_creation() {
  local repo_root=$1
  local worktree=$2
  local attempt_key=$3
  local owner=$4
  local branch=$5
  local detail=$6
  local owned_branch=${7-false}
  local owned_branch_head=${8-}

  if remove_unbound_worktree "$repo_root" "$worktree"; then
    if [[ "$owned_branch" == true ]]; then
      if ! git -C "$repo_root" update-ref -d "refs/heads/$branch" "$owned_branch_head" 2>/dev/null; then
        die "$detail; the worktree was removed but owned branch $branch changed during cleanup; attempt-key $attempt_key owner $owner can be recovered after branch reconciliation"
      fi
    fi
    release_worktree_reservation \
      "$repo_root" "$attempt_key" "$owner" "$worktree"
    rm "$(state_dir_for "$repo_root" "$attempt_key")/target"
    release_claim "$repo_root" "$attempt_key" "$owner"
    die "$detail; the unbound worktree was removed and the claim was released"
  fi

  local worker_root=$worktree
  local actual_branch=$branch
  if [[ -d "$worktree" ]]; then
    local discovered_root
    discovered_root=$(git -C "$worktree" rev-parse --show-toplevel 2>/dev/null || true)
    if [[ -n "$discovered_root" ]]; then
      worker_root=$(CDPATH= cd -- "$discovered_root" && pwd -P)
      actual_branch=$(git -C "$worker_root" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
      [[ -n "$actual_branch" ]] || actual_branch='(detached)'
      if write_binding "$repo_root" "$attempt_key" "$owner" "$worker_root" "$actual_branch"; then
        rm "$(state_dir_for "$repo_root" "$attempt_key")/target"
      fi
    fi
  fi
  write_outcome "$repo_root" "$attempt_key" "$owner" blocked "$detail" || true
  die "$detail; attempt-key $attempt_key owner $owner requires owned cleanup"
}

bind_worker() {
  local repo=''
  local attempt_key=''
  local owner=''
  local worktree=''
  local branch=''

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo|--attempt-key|--owner|--worktree|--branch)
        require_value "$1" "${2-}"
        case "$1" in
          --repo) repo=$2 ;;
          --attempt-key) attempt_key=$2 ;;
          --owner) owner=$2 ;;
          --worktree) worktree=$2 ;;
          --branch) branch=$2 ;;
        esac
        shift 2
        ;;
      *) die "unknown bind option: $1" ;;
    esac
  done

  [[ -n "$repo" ]] || die 'bind requires --repo'
  [[ -n "$attempt_key" ]] || die 'bind requires --attempt-key'
  [[ -n "$owner" ]] || die 'bind requires --owner'
  [[ -n "$worktree" ]] || die 'bind requires --worktree'
  [[ -n "$branch" ]] || die 'bind requires --branch'
  validate_attempt_key "$attempt_key"
  validate_owner "$owner"
  git check-ref-format --branch "$branch" >/dev/null 2>&1 \
    || die "invalid branch name: $branch"
  [[ "$branch" != '(detached)' ]] \
    || die 'bind branch cannot use the internal detached-worktree marker'

  local repo_root
  repo_root=$(repo_root_for "$repo")
  local worker_root
  worker_root=$(repo_root_for "$worktree")
  [[ "$worker_root" != *$'\t'* && "$worker_root" != *$'\n'* ]] \
    || die 'worktree path cannot contain a tab or newline'
  [[ "$worker_root" != "$repo_root" ]] || die 'bind refuses the repository root'
  [[ "$(git_common_dir "$worker_root")" == "$(git_common_dir "$repo_root")" ]] \
    || die 'bind target does not belong to the repository'
  local actual_branch
  actual_branch=$(git -C "$worker_root" symbolic-ref --quiet --short HEAD) \
    || die 'bind requires a named worker branch'
  [[ "$actual_branch" == "$branch" ]] \
    || die "worker branch $actual_branch does not match requested branch $branch"

  local claim_file
  claim_file=$(claim_file_for "$repo_root" "$attempt_key")
  assert_claim_owner "$claim_file" "$owner"
  local base_sha
  base_sha=$(claim_field "$claim_file" 2)
  local actual_sha
  actual_sha=$(git -C "$worker_root" rev-parse HEAD)
  [[ "$actual_sha" == "$base_sha" ]] \
    || die "worker HEAD $actual_sha does not match claimed base $base_sha"
  local worker_status
  worker_status=$(git -C "$worker_root" status --porcelain --untracked-files=all) \
    || die 'bind cannot inspect the worker worktree'
  [[ -z "$worker_status" ]] || die 'bind requires a clean worker worktree'

  write_target \
    "$repo_root" "$attempt_key" "$owner" "$worker_root" "$branch" bind \
    || die 'attempt already has a different worker target'
  if ! reserve_worktree "$repo_root" "$attempt_key" "$owner" "$worker_root"; then
    rm "$(state_dir_for "$repo_root" "$attempt_key")/target"
    die "worker worktree is already reserved by another attempt: $worker_root"
  fi
  local reservation_created=$WORKTREE_RESERVATION_CREATED
  if ! write_binding "$repo_root" "$attempt_key" "$owner" "$worker_root" "$branch"; then
    if [[ "$reservation_created" == true ]]; then
      release_worktree_reservation "$repo_root" "$attempt_key" "$owner" "$worker_root"
    fi
    [[ ! -e "$(state_dir_for "$repo_root" "$attempt_key")/target" ]] \
      || rm "$(state_dir_for "$repo_root" "$attempt_key")/target"
    die 'attempt is already bound to a different worker'
  fi
  [[ ! -e "$(state_dir_for "$repo_root" "$attempt_key")/target" ]] \
    || rm "$(state_dir_for "$repo_root" "$attempt_key")/target"
  printf 'bound\t%s\t%s\t%s\n' "$attempt_key" "$worker_root" "$branch"
}

prepare_worker() {
  local repo=''
  local follow_up=''
  local worktree=''
  local branch=''
  local remote=origin

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo|--follow-up|--worktree|--branch|--remote)
        require_value "$1" "${2-}"
        case "$1" in
          --repo) repo=$2 ;;
          --follow-up) follow_up=$2 ;;
          --worktree) worktree=$2 ;;
          --branch) branch=$2 ;;
          --remote) remote=$2 ;;
        esac
        shift 2
        ;;
      *) die "unknown prepare option: $1" ;;
    esac
  done

  [[ -n "$repo" ]] || die 'prepare requires --repo'
  [[ -n "$follow_up" ]] || die 'prepare requires --follow-up'
  [[ -n "$worktree" ]] || die 'prepare requires --worktree'
  [[ -n "$branch" ]] || die 'prepare requires --branch'
  git check-ref-format --branch "$branch" >/dev/null 2>&1 \
    || die "invalid branch name: $branch"
  [[ "$branch" != '(detached)' ]] \
    || die 'prepare branch cannot use the internal detached-worktree marker'
  [[ "$worktree" != *$'\t'* && "$worktree" != *$'\n'* ]] \
    || die 'worktree path cannot contain a tab or newline'
  [[ ! -e "$worktree" ]] || die "worktree path already exists: $worktree"
  local requested_worktree=$worktree
  local worktree_parent
  worktree_parent=$(dirname -- "$worktree")
  [[ -d "$worktree_parent" ]] || die "worktree parent does not exist: $worktree_parent"
  worktree_parent=$(CDPATH= cd -- "$worktree_parent" && pwd -P)
  worktree="$worktree_parent/$(basename -- "$worktree")"

  local identity
  identity=$(resolve_attempt "$repo" "$follow_up" "$remote")
  local status relative base_sha attempt_key state owner
  IFS=$'\t' read -r status relative base_sha attempt_key state owner <<<"$identity"
  if [[ "$status" == 'skipped-unchanged' ]]; then
    printf '%s\n' "$identity"
    return 0
  fi
  [[ "$status" == 'eligible' ]] || die "unexpected identity status: $status"

  local repo_root
  repo_root=$(repo_root_for "$repo")
  local claim
  claim=$(create_claim "$repo_root" "$relative" "$base_sha" "$attempt_key")
  local claim_status claim_key
  IFS=$'\t' read -r claim_status claim_key owner <<<"$claim"
  if [[ "$claim_status" == 'skipped-unchanged' ]]; then
    printf '%s\n' "$claim"
    return 0
  fi
  [[ "$claim_status" == 'claimed' && "$claim_key" == "$attempt_key" ]] \
    || die 'failed to claim the resolved attempt identity'

  if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$branch"; then
    release_claim "$repo_root" "$attempt_key" "$owner"
    die "branch already exists: $branch"
  fi
  write_target "$repo_root" "$attempt_key" "$owner" "$worktree" "$branch" prepare \
    || die "attempt-key $attempt_key owner $owner already has a different worktree target"
  if ! reserve_worktree "$repo_root" "$attempt_key" "$owner" "$worktree"; then
    rm "$(state_dir_for "$repo_root" "$attempt_key")/target"
    release_claim "$repo_root" "$attempt_key" "$owner"
    die "worker worktree is already reserved by another attempt: $worktree"
  fi
  if ! git -C "$repo_root" worktree add -q --detach "$worktree" "$base_sha" >&2; then
    if [[ ! -e "$worktree" ]] \
      && ! git -C "$repo_root" worktree list --porcelain \
        | grep -Fqx "worktree $worktree"; then
      release_worktree_reservation "$repo_root" "$attempt_key" "$owner" "$worktree"
      rm "$(state_dir_for "$repo_root" "$attempt_key")/target"
      release_claim "$repo_root" "$attempt_key" "$owner"
      die "failed to create worker worktree: $worktree; no partial checkout was registered"
    fi
    fail_after_worktree_creation \
      "$repo_root" "$worktree" "$attempt_key" "$owner" "$branch" \
      "failed to create worker worktree: $worktree"
  fi

  local actual_sha
  if ! actual_sha=$(git -C "$worktree" rev-parse HEAD 2>/dev/null); then
    fail_after_worktree_creation \
      "$repo_root" "$worktree" "$attempt_key" "$owner" "$branch" \
      'prepared worktree HEAD cannot be read'
  fi
  if [[ "$actual_sha" != "$base_sha" ]]; then
    fail_after_worktree_creation \
      "$repo_root" "$worktree" "$attempt_key" "$owner" "$branch" \
      "prepared worktree HEAD $actual_sha does not match base $base_sha"
  fi
  local owned_branch=false
  if git -C "$worktree" switch -q -c "$branch" >&2; then
    owned_branch=true
  else
    local switched_branch
    switched_branch=$(git -C "$worktree" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
    actual_sha=$(git -C "$worktree" rev-parse HEAD 2>/dev/null || true)
    if [[ "$switched_branch" == "$branch" ]]; then
      owned_branch=true
    fi
    if [[ "$switched_branch" != "$branch" || "$actual_sha" != "$base_sha" ]]; then
      fail_after_worktree_creation \
        "$repo_root" "$worktree" "$attempt_key" "$owner" "$branch" \
        "failed to create worker branch: $branch" \
        "$owned_branch" "$actual_sha"
    fi
  fi
  local verified_branch
  verified_branch=$(git -C "$worktree" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  actual_sha=$(git -C "$worktree" rev-parse HEAD 2>/dev/null || true)
  if [[ "$verified_branch" != "$branch" || "$actual_sha" != "$base_sha" ]]; then
    fail_after_worktree_creation \
      "$repo_root" "$worktree" "$attempt_key" "$owner" "$branch" \
      "worker changed after branch setup: branch=$verified_branch HEAD=${actual_sha:-unreadable}" \
      "$owned_branch" "$actual_sha"
  fi
  local worker_status
  if ! worker_status=$(git -C "$worktree" status --porcelain --untracked-files=all 2>/dev/null); then
    fail_after_worktree_creation \
      "$repo_root" "$worktree" "$attempt_key" "$owner" "$branch" \
      'cannot inspect worker worktree after branch setup' \
      "$owned_branch" "$actual_sha"
  fi
  if [[ -n "$worker_status" ]]; then
    fail_after_worktree_creation \
      "$repo_root" "$worktree" "$attempt_key" "$owner" "$branch" \
      'worker worktree is dirty after branch setup' \
      "$owned_branch" "$actual_sha"
  fi
  if ! write_binding "$repo_root" "$attempt_key" "$owner" "$worktree" "$branch"; then
    write_outcome "$repo_root" "$attempt_key" "$owner" blocked \
      'attempt was already bound to a different worker during prepare' || true
    die "attempt-key $attempt_key owner $owner was already bound during prepare"
  fi
  rm "$(state_dir_for "$repo_root" "$attempt_key")/target"

  printf 'prepared\t%s\t%s\t%s\t%s\t%s\n' \
    "$requested_worktree" "$branch" "$base_sha" "$attempt_key" "$owner"
}

mark_attempt() {
  local repo=''
  local follow_up=''
  local base_sha=''
  local owner=''
  local outcome=''
  local detail=''

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo|--follow-up|--base-sha|--owner|--outcome|--detail)
        require_value "$1" "${2-}"
        case "$1" in
          --repo) repo=$2 ;;
          --follow-up) follow_up=$2 ;;
          --base-sha) base_sha=$2 ;;
          --owner) owner=$2 ;;
          --outcome) outcome=$2 ;;
          --detail) detail=$2 ;;
        esac
        shift 2
        ;;
      *) die "unknown mark option: $1" ;;
    esac
  done

  [[ -n "$repo" ]] || die 'mark requires --repo'
  [[ -n "$follow_up" ]] || die 'mark requires --follow-up'
  [[ -n "$base_sha" ]] || die 'mark requires --base-sha'
  [[ -n "$owner" ]] || die 'mark requires --owner'
  [[ "$detail" =~ [^[:space:]] ]] \
    || die 'mark requires --detail with decisive evidence or the next useful condition'
  validate_owner "$owner"
  case "$outcome" in
    not-reproduced|needs-shaping|blocked) ;;
    pull-request)
      [[ "$detail" =~ [^[:space:]] ]] \
        || die 'pull-request outcome requires --detail with the pull request URL'
      ;;
    *) die 'mark outcome must be pull-request, not-reproduced, needs-shaping, or blocked' ;;
  esac
  [[ "$detail" != *$'\t'* && "$detail" != *$'\n'* ]] \
    || die 'mark detail cannot contain a tab or newline'

  local repo_root
  repo_root=$(repo_root_for "$repo")
  local relative
  relative=$(relative_follow_up_path "$repo_root" "$follow_up")
  local resolved_base
  resolved_base=$(git -C "$repo_root" rev-parse "$base_sha^{commit}" 2>/dev/null) \
    || die "base SHA is not a commit: $base_sha"
  [[ "$resolved_base" == "$base_sha" ]] \
    || die 'mark requires the full resolved base SHA returned by claim or prepare'
  local attempt_key
  attempt_key=$(attempt_key_at_base "$repo_root" "$relative" "$base_sha")
  local claim_file
  claim_file=$(claim_file_for "$repo_root" "$attempt_key")
  assert_claim_identity "$claim_file" "$relative" "$base_sha"
  assert_claim_owner "$claim_file" "$owner"

  write_outcome "$repo_root" "$attempt_key" "$owner" "$outcome" "$detail" \
    || die 'attempt already has a different terminal outcome'

  printf 'recorded\t%s\t%s' "$attempt_key" "$outcome"
  if [[ -n "$detail" ]]; then
    printf '\t%s' "$detail"
  fi
  printf '\n'
}

recover_attempt() {
  local repo=''
  local attempt_key=''
  local owner=''
  local remote=origin

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo|--attempt-key|--owner|--remote)
        require_value "$1" "${2-}"
        case "$1" in
          --repo) repo=$2 ;;
          --attempt-key) attempt_key=$2 ;;
          --owner) owner=$2 ;;
          --remote) remote=$2 ;;
        esac
        shift 2
        ;;
      *) die "unknown recover option: $1" ;;
    esac
  done

  [[ -n "$repo" ]] || die 'recover requires --repo'
  [[ -n "$attempt_key" ]] || die 'recover requires --attempt-key'
  [[ -n "$owner" ]] || die 'recover requires --owner'
  validate_attempt_key "$attempt_key"
  validate_owner "$owner"

  local repo_root
  repo_root=$(repo_root_for "$repo")
  local claim_file
  claim_file=$(claim_file_for "$repo_root" "$attempt_key")
  assert_claim_owner "$claim_file" "$owner"
  local state_dir
  state_dir=$(state_dir_for "$repo_root" "$attempt_key")
  [[ ! -e "$state_dir/outcome" ]] \
    || die 'recover refuses an attempt with a terminal outcome; use clear after its review condition changes'
  acquire_claim_guard "$repo_root" "$attempt_key" \
    || die 'attempt state is already being updated by another process'
  local guard_oid=$CLAIM_GUARD_OID
  if [[ -e "$state_dir/outcome" ]]; then
    release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
    die 'recover refuses an attempt that reached a terminal outcome during recovery'
  fi

  local binding_file="$state_dir/binding"
  local target_file="$state_dir/target"
  local coordination_file=''
  local preparing=false
  if [[ -f "$binding_file" ]]; then
    coordination_file=$binding_file
  elif [[ -f "$target_file" ]]; then
    coordination_file=$target_file
    if [[ "$(sed -n '3p' "$target_file")" == prepare ]]; then
      preparing=true
    fi
  fi
  if [[ -n "$coordination_file" ]]; then
    local bound_worktree bound_branch published_head
    bound_worktree=$(sed -n '1p' "$coordination_file")
    bound_branch=$(sed -n '2p' "$coordination_file")
    if [[ -e "$bound_worktree" || -L "$bound_worktree" ]]; then
      release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
      die "recover requires the bound worker worktree to be cleaned up first: $bound_worktree"
    fi
    if worktree_is_registered "$repo_root" "$bound_worktree"; then
      if ! reserve_worktree "$repo_root" "$attempt_key" "$owner" "$bound_worktree"; then
        release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
        die "recover cannot prune a worker coordinate reserved by another attempt: $bound_worktree"
      fi
      assert_worktree_reservation \
        "$repo_root" "$attempt_key" "$owner" "$bound_worktree" >/dev/null
      if ! git -C "$repo_root" worktree remove --force "$bound_worktree"; then
        release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
        die "recover cannot remove the missing worker registration: $bound_worktree"
      fi
    fi
    published_head=''
    if [[ "$bound_branch" != '(detached)' ]]; then
      if ! published_head=$(
        git -C "$repo_root" ls-remote "$remote" "refs/heads/$bound_branch" 2>/dev/null \
          | awk 'NR == 1 { print $1 }'
      ); then
        release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
        die "recover cannot inspect the bound worker branch on remote: $remote"
      fi
    fi
    if [[ -n "$published_head" ]]; then
      release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
      die "recover refuses published branch $bound_branch; inspect it for a pull request and mark the terminal result"
    fi
    if [[ "$preparing" == true ]] \
      && git -C "$repo_root" show-ref --verify --quiet "refs/heads/$bound_branch"; then
      release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
      die "recover refuses local preparation branch $bound_branch; reconcile it before releasing the claim"
    fi
    release_worktree_reservation \
      "$repo_root" "$attempt_key" "$owner" "$bound_worktree"
    rm "$coordination_file"
    if [[ "$coordination_file" == "$binding_file" && -f "$target_file" ]]; then
      rm "$target_file"
    fi
  fi
  local base_sha relative content_ref
  base_sha=$(claim_field "$claim_file" 2)
  relative=$(claim_field "$claim_file" 3)
  content_ref=$(content_ref_at_base "$repo_root" "$relative" "$base_sha")
  git -C "$repo_root" update-ref -d "$content_ref" "$base_sha" 2>/dev/null || true
  if [[ -d "$state_dir" ]]; then
    if ! rmdir "$state_dir" 2>/dev/null; then
      release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
      die 'attempt state contains unexpected files'
    fi
  elif [[ -e "$state_dir" ]]; then
    release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
    die 'attempt state path is not a directory'
  fi
  rm "$claim_file"
  release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
  printf 'recovered\t%s\n' "$attempt_key"
}

clear_attempt() {
  local repo=''
  local follow_up=''
  local base_sha=''

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo|--follow-up|--base-sha)
        require_value "$1" "${2-}"
        case "$1" in
          --repo) repo=$2 ;;
          --follow-up) follow_up=$2 ;;
          --base-sha) base_sha=$2 ;;
        esac
        shift 2
        ;;
      *) die "unknown clear option: $1" ;;
    esac
  done

  [[ -n "$repo" ]] || die 'clear requires --repo'
  [[ -n "$follow_up" ]] || die 'clear requires --follow-up'
  [[ -n "$base_sha" ]] || die 'clear requires --base-sha'

  local repo_root
  repo_root=$(repo_root_for "$repo")
  local relative
  relative=$(relative_follow_up_path "$repo_root" "$follow_up")
  local resolved_base
  resolved_base=$(git -C "$repo_root" rev-parse "$base_sha^{commit}" 2>/dev/null) \
    || die "base SHA is not a commit: $base_sha"
  [[ "$resolved_base" == "$base_sha" ]] \
    || die 'clear requires the full resolved base SHA returned by identity or prepare'
  local attempt_key
  attempt_key=$(attempt_key_at_base "$repo_root" "$relative" "$base_sha")
  local claim_file
  claim_file=$(claim_file_for "$repo_root" "$attempt_key")
  assert_claim_identity "$claim_file" "$relative" "$base_sha"
  local state_dir
  state_dir=$(state_dir_for "$repo_root" "$attempt_key")
  [[ -f "$state_dir/outcome" ]] \
    || die 'clear refuses an active claim without a terminal outcome'
  [[ "$(sed -n '1p' "$state_dir/outcome")" == pull-request ]] \
    || die 'clear only permits a pull-request outcome after its pull request closes unmerged'
  local cleanup_coordinates=''
  if [[ -f "$state_dir/binding" ]]; then
    cleanup_coordinates="$state_dir/binding"
  elif [[ -f "$state_dir/target" ]]; then
    cleanup_coordinates="$state_dir/target"
  fi
  if [[ -n "$cleanup_coordinates" ]]; then
    local bound_worktree
    bound_worktree=$(sed -n '1p' "$cleanup_coordinates")
    [[ ! -e "$bound_worktree" && ! -L "$bound_worktree" ]] \
      || die 'clear requires the bound worker worktree to be removed first'
  fi

  acquire_claim_guard "$repo_root" "$attempt_key" \
    || die 'attempt state is already being updated by another process'
  local guard_oid=$CLAIM_GUARD_OID
  if [[ ! -f "$state_dir/outcome" || "$(sed -n '1p' "$state_dir/outcome")" != pull-request ]]; then
    release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
    die 'pull-request outcome changed during clear'
  fi
  cleanup_coordinates=''
  if [[ -f "$state_dir/binding" ]]; then
    cleanup_coordinates="$state_dir/binding"
  elif [[ -f "$state_dir/target" ]]; then
    cleanup_coordinates="$state_dir/target"
  fi
  if [[ -n "$cleanup_coordinates" ]]; then
    local guarded_worktree
    guarded_worktree=$(sed -n '1p' "$cleanup_coordinates")
    if [[ -e "$guarded_worktree" || -L "$guarded_worktree" ]]; then
      release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
      die 'clear requires the bound worker worktree to remain removed'
    fi
  fi

  local content_ref
  content_ref=$(content_ref_at_base "$repo_root" "$relative" "$base_sha")
  git -C "$repo_root" update-ref -d "$content_ref" "$base_sha" 2>/dev/null || true
  if [[ -n "$cleanup_coordinates" ]]; then
    release_worktree_reservation \
      "$repo_root" "$attempt_key" \
      "$(claim_field "$claim_file" 1)" "$(sed -n '1p' "$cleanup_coordinates")"
  fi
  rm "$state_dir/outcome"
  [[ ! -e "$state_dir/binding" ]] || rm "$state_dir/binding"
  [[ ! -e "$state_dir/target" ]] || rm "$state_dir/target"
  if ! rmdir "$state_dir" 2>/dev/null; then
    release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
    die 'attempt state contains unexpected files'
  fi
  rm "$claim_file"
  release_claim_guard "$repo_root" "$attempt_key" "$guard_oid"
  printf 'cleared\t%s\n' "$attempt_key"
}

deinitialize_worker_submodules() {
  local repo_root=$1
  local worker_root=$2
  local worker_git_dir=$3
  local submodule_git_dir=$4
  local common_dir
  common_dir=$(git_common_dir "$repo_root")
  local head
  head=$(git -C "$worker_root" rev-parse HEAD)
  local shadow_root
  shadow_root=$(mktemp -d "$(attempts_dir_for "$repo_root")/.cleanup-shadow.XXXXXX")
  local shadow_git_dir="$shadow_root/.git"
  local ref_format
  ref_format=$(git -C "$repo_root" config --get extensions.refStorage || true)
  local object_format
  object_format=$(git -C "$repo_root" rev-parse --show-object-format)

  if ! (
    set -e
    local init_args=(-q --object-format="$object_format")
    if [[ -n "$ref_format" ]]; then
      init_args+=(--ref-format="$ref_format")
    fi
    git init "${init_args[@]}" "$shadow_root"
    cp "$common_dir/config" "$shadow_git_dir/config"
    git --git-dir="$shadow_git_dir" config core.worktree "$worker_root"
    ln -s "$submodule_git_dir" "$shadow_git_dir/modules"
    export GIT_ALTERNATE_OBJECT_DIRECTORIES="$common_dir/objects"
    git --git-dir="$shadow_git_dir" --work-tree="$worker_root" \
      update-ref HEAD "$head"
    git --git-dir="$shadow_git_dir" --work-tree="$worker_root" \
      read-tree "$head"
    cd "$worker_root"
    GIT_DIR="$shadow_git_dir" GIT_WORK_TREE="$worker_root" \
      git submodule deinit --all >/dev/null
  ); then
    find "$shadow_root" -depth -delete 2>/dev/null || true
    die 'cleanup could not safely deinitialize worker submodules'
  fi
  find "$shadow_root" -depth -delete \
    || die 'cleanup could not remove temporary submodule metadata'
}

cleanup_worker() {
  local repo=''
  local worktree=''
  local attempt_key=''
  local owner=''
  local remote=origin

  while [[ $# -gt 0 ]]; do
    case "$1" in
      --repo|--worktree|--attempt-key|--owner|--remote)
        require_value "$1" "${2-}"
        case "$1" in
          --repo) repo=$2 ;;
          --worktree) worktree=$2 ;;
          --attempt-key) attempt_key=$2 ;;
          --owner) owner=$2 ;;
          --remote) remote=$2 ;;
        esac
        shift 2
        ;;
      *) die "unknown cleanup option: $1" ;;
    esac
  done

  [[ -n "$repo" ]] || die 'cleanup requires --repo'
  [[ -n "$worktree" ]] || die 'cleanup requires --worktree'
  [[ -n "$attempt_key" ]] || die 'cleanup requires --attempt-key'
  [[ -n "$owner" ]] || die 'cleanup requires --owner'
  validate_attempt_key "$attempt_key"
  validate_owner "$owner"
  [[ -d "$worktree" ]] || die "worktree does not exist: $worktree"
  local requested_worktree=$worktree

  local repo_root
  repo_root=$(repo_root_for "$repo")
  local worker_root
  worker_root=$(repo_root_for "$worktree")
  [[ "$worker_root" != "$repo_root" ]] \
    || die 'cleanup refuses to remove the repository root'
  [[ "$(git_common_dir "$worker_root")" == "$(git_common_dir "$repo_root")" ]] \
    || die 'cleanup target does not belong to the repository'

  local claim_file
  claim_file=$(claim_file_for "$repo_root" "$attempt_key")
  assert_claim_owner "$claim_file" "$owner"
  local state_dir
  state_dir=$(state_dir_for "$repo_root" "$attempt_key")
  local binding_file="$state_dir/binding"
  local target_file="$state_dir/target"
  local coordination_file=''
  local targeting=false
  local preparing=false
  if [[ -f "$binding_file" ]]; then
    coordination_file=$binding_file
  elif [[ -f "$target_file" ]]; then
    coordination_file=$target_file
    targeting=true
    if [[ "$(sed -n '3p' "$target_file")" == prepare ]]; then
      preparing=true
    fi
  else
    die 'attempt has no bound or preparing worker worktree'
  fi
  local bound_worktree
  local bound_branch
  bound_worktree=$(sed -n '1p' "$coordination_file")
  bound_branch=$(sed -n '2p' "$coordination_file")
  [[ "$bound_worktree" == "$worker_root" ]] \
    || die 'cleanup target is not the worktree owned by this attempt'

  if ! reserve_worktree "$repo_root" "$attempt_key" "$owner" "$worker_root"; then
    die "worker worktree is reserved by another attempt: $worker_root"
  fi
  assert_worktree_reservation \
    "$repo_root" "$attempt_key" "$owner" "$worker_root" >/dev/null

  [[ -z "$(git -C "$worker_root" status --porcelain --untracked-files=all --ignore-submodules=none)" ]] \
    || die 'cleanup requires a clean worker worktree'
  local branch
  branch=$(git -C "$worker_root" symbolic-ref --quiet --short HEAD 2>/dev/null || true)
  local preparation_owned_branch=false
  if [[ "$preparing" == true ]]; then
    if [[ -z "$branch" ]]; then
      branch='(detached)'
    elif [[ "$branch" == "$bound_branch" ]]; then
      preparation_owned_branch=true
    else
      die 'cleanup preparing worker branch does not match its persisted target'
    fi
  elif [[ "$bound_branch" == '(detached)' ]]; then
    [[ -z "$branch" ]] || die 'cleanup expected the bound worker to remain detached'
    branch='(detached)'
  else
    [[ -n "$branch" ]] || die 'cleanup requires a named worker branch'
    [[ "$branch" == "$bound_branch" ]] \
      || die 'cleanup worker branch does not match the attempt binding'
  fi
  local head
  head=$(git -C "$worker_root" rev-parse HEAD)
  local base_sha
  base_sha=$(claim_field "$claim_file" 2)

  local safe_no_change=false
  if [[ "$head" == "$base_sha" ]]; then
    safe_no_change=true
  fi
  local remote_head=''
  local safe_published=false
  if [[ "$branch" != '(detached)' && ( "$safe_no_change" != true || "$preparing" == true ) ]]; then
    remote_head=$(
      git -C "$repo_root" ls-remote "$remote" "refs/heads/$branch" 2>/dev/null \
        | awk 'NR == 1 { print $1 }'
    ) || die "cannot inspect worker branch on remote: $remote"
    if [[ -n "$remote_head" && "$remote_head" == "$head" ]]; then
      safe_published=true
    fi
  fi
  if [[ "$preparing" == true && -n "$remote_head" ]]; then
    die "preparing worker branch is already published to $remote: $branch"
  fi
  if [[ "$preparing" == true && "$branch" == '(detached)' && "$safe_no_change" != true ]]; then
    die 'cleanup refuses a changed detached worktree from interrupted preparation'
  fi
  if [[ "$preparing" != true && "$safe_no_change" != true && "$safe_published" != true ]]; then
    if [[ -n "$remote_head" ]]; then
      die "published branch HEAD $remote_head does not match worker HEAD $head"
    fi
    die "worker is neither unchanged at its claimed base nor published to $remote: $branch"
  fi

  assert_worktree_reservation \
    "$repo_root" "$attempt_key" "$owner" "$worker_root" >/dev/null
  local worker_git_dir submodule_git_dir
  worker_git_dir=$(git -C "$worker_root" rev-parse --path-format=absolute --git-dir)
  case "$worker_git_dir" in
    "$(git_common_dir "$repo_root")"/worktrees/*) ;;
    *) die 'cleanup cannot validate the linked-worktree administrative directory' ;;
  esac
  submodule_git_dir="$worker_git_dir/modules"
  if [[ -d "$submodule_git_dir" ]]; then
    deinitialize_worker_submodules \
      "$repo_root" "$worker_root" "$worker_git_dir" "$submodule_git_dir"
    [[ -z "$(git -C "$worker_root" status --porcelain --untracked-files=all --ignore-submodules=none)" ]] \
      || die 'cleanup detected worktree changes while deinitializing submodules'
    find "$submodule_git_dir" -depth -delete
  fi
  assert_worktree_reservation \
    "$repo_root" "$attempt_key" "$owner" "$worker_root" >/dev/null
  git -C "$repo_root" worktree remove "$worker_root"
  if [[ "$preparation_owned_branch" == true ]]; then
    git -C "$repo_root" update-ref -d "refs/heads/$branch" "$head" 2>/dev/null \
      || die "preparing worker branch changed during cleanup: $branch"
  fi
  release_worktree_reservation \
    "$repo_root" "$attempt_key" "$owner" "$worker_root"
  if [[ "$targeting" == true ]]; then
    rm "$target_file"
  fi
  printf 'cleaned\t%s\t%s\t%s\n' "$requested_worktree" "$branch" "$head"
}

main() {
  local command=${1-}
  [[ -n "$command" ]] || usage
  shift

  case "$command" in
    list) list_follow_ups "$@" ;;
    identity) identity_attempt "$@" ;;
    claim) claim_attempt "$@" ;;
    bind) bind_worker "$@" ;;
    prepare) prepare_worker "$@" ;;
    mark) mark_attempt "$@" ;;
    recover) recover_attempt "$@" ;;
    clear) clear_attempt "$@" ;;
    cleanup) cleanup_worker "$@" ;;
    *) die "unknown command: $command" ;;
  esac
}

main "$@"
