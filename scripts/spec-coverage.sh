#!/usr/bin/env bash
# spec.md의 판정 기준 ID가 plan.md에 배정되고 테스트에 인용되는지 검사한다.
#
# 사용법:
#   scripts/spec-coverage.sh <feature>              # plan 배정만 검사 (draft-plan 단계)
#   scripts/spec-coverage.sh <feature> --tests      # 테스트 인용까지 검사 (execute-plan 체크포인트)
#   scripts/spec-coverage.sh <feature> --wireframe  # wireframe 무결성 검사 (sketch-wireframe Step 4)
#
# 판정 기준 ID 형식: S1, S1-1 (시나리오), INV-1 (불변 규칙)
# spec에서 ~~ID~~ 로 취소선 처리된 결번은 검사에서 제외한다.
#
# --wireframe은 기계적으로 판정 가능한 것만 검사한다:
#   - 유령 ID: wireframe의 data-scenario가 spec에 없는(또는 결번) ID를 주장
#   - dangling data-goto: 배선이 가리키는 화면이 파일에 없음
# "시각적 시나리오가 모두 렌더됐는가"는 시각/비시각 판단이 필요하므로 스킬 Step 4가 담당한다.
set -euo pipefail

feature="${1:?사용법: scripts/spec-coverage.sh <feature> [--tests] [--wireframe]}"
shift
check_tests=0
check_wireframe=0
for arg in "$@"; do
  case "$arg" in
    --tests) check_tests=1 ;;
    --wireframe) check_wireframe=1 ;;
    *) echo "알 수 없는 플래그: $arg" >&2; exit 1 ;;
  esac
done

dir="artifacts/$feature"
spec="$dir/spec.md"
plan="$dir/plan.md"
wireframe="$dir/wireframe.html"

[ -f "$spec" ] || { echo "spec 없음: $spec" >&2; exit 1; }

ids=$(grep -oE '\bS[0-9]+(-[0-9]+)?\b|\bINV-[0-9]+\b' "$spec" | sort -u -V || true)
[ -n "$ids" ] || { echo "spec에서 판정 기준 ID를 찾지 못했다: $spec" >&2; exit 1; }

fail=0
for id in $ids; do
  # 결번(삭제된 기준)은 건너뛴다
  grep -qF "~~$id~~" "$spec" && continue

  if [ -f "$plan" ] && ! grep -qE "\b$id\b" "$plan"; then
    echo "plan 미배정: $id"
    fail=1
  fi

  if [ "$check_tests" -eq 1 ]; then
    # 시나리오 ID(S1)는 세부 기준 인용([S1-1])으로도 커버된 것으로 본다
    # 검색 경로는 CLAUDE.md Architecture의 전체 레이어를 포함한다
    if ! grep -rqE "\[$id(-[0-9]+)?\]" \
        --include='*.test.ts' --include='*.test.tsx' --include='*.spec.ts' \
        app components lib services hooks types config e2e 2>/dev/null; then
      echo "테스트 미인용: $id"
      fail=1
    fi
  fi
done

if [ "$check_wireframe" -eq 1 ]; then
  [ -f "$wireframe" ] || { echo "wireframe 없음: $wireframe" >&2; exit 1; }

  # 유령 ID: data-scenario가 주장하는 ID는 spec에 존재하는 유효한 ID여야 한다
  wf_ids=$(grep -oE 'data-scenario="[^"]*"' "$wireframe" \
    | grep -oE '\bS[0-9]+(-[0-9]+)?\b|\bINV-[0-9]+\b' | sort -u -V || true)
  for id in $wf_ids; do
    if ! printf '%s\n' "$ids" | grep -qxF "$id"; then
      echo "spec에 없는 ID를 wireframe이 주장: $id"
      fail=1
    elif grep -qF "~~$id~~" "$spec"; then
      echo "결번 ID를 wireframe이 주장: $id"
      fail=1
    fi
  done

  # dangling data-goto: 배선이 가리키는 화면이 파일에 존재해야 한다
  gotos=$(grep -oE 'data-goto="screen-[^"]+"' "$wireframe" \
    | sed -E 's/^data-goto="screen-//; s/"$//' | sort -u || true)
  for g in $gotos; do
    if ! grep -q "id=\"screen-$g\"" "$wireframe"; then
      echo "dangling data-goto: screen-$g (해당 화면 없음)"
      fail=1
    fi
  done
fi

if [ "$fail" -eq 0 ]; then
  msg="커버리지 OK: 모든 판정 기준이 plan에 배정"
  [ "$check_tests" -eq 1 ] && msg="$msg되고 테스트에 인용"
  msg="$msg되어 있다"
  [ "$check_wireframe" -eq 1 ] && msg="$msg. wireframe 무결성 OK (유령 ID·dangling data-goto 없음)"
  echo "$msg"
fi
exit "$fail"
