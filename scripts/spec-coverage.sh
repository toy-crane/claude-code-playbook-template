#!/usr/bin/env bash
# spec.md의 판정 기준 ID가 plan.md에 배정되고 테스트에 인용되는지 검사한다.
#
# 사용법:
#   scripts/spec-coverage.sh <feature>          # plan 배정만 검사 (draft-plan 단계)
#   scripts/spec-coverage.sh <feature> --tests  # 테스트 인용까지 검사 (execute-plan 체크포인트)
#
# 판정 기준 ID 형식: S1, S1-1 (시나리오), INV-1 (불변 규칙)
# spec에서 ~~ID~~ 로 취소선 처리된 결번은 검사에서 제외한다.
set -euo pipefail

feature="${1:?사용법: scripts/spec-coverage.sh <feature> [--tests]}"
check_tests="${2:-}"

dir="artifacts/$feature"
spec="$dir/spec.md"
plan="$dir/plan.md"

[ -f "$spec" ] || { echo "spec 없음: $spec" >&2; exit 1; }

ids=$(grep -oE '\bS[0-9]+(-[0-9]+)?\b|\bINV-[0-9]+\b' "$spec" | sort -u -V)
[ -n "$ids" ] || { echo "spec에서 판정 기준 ID를 찾지 못했다: $spec" >&2; exit 1; }

fail=0
for id in $ids; do
  # 결번(삭제된 기준)은 건너뛴다
  grep -qF "~~$id~~" "$spec" && continue

  if [ -f "$plan" ] && ! grep -qE "\b$id\b" "$plan"; then
    echo "plan 미배정: $id"
    fail=1
  fi

  if [ "$check_tests" = "--tests" ]; then
    # 시나리오 ID(S1)는 세부 기준 인용([S1-1])으로도 커버된 것으로 본다
    if ! grep -rqE "\[$id(-[0-9]+)?\]" \
        --include='*.test.ts' --include='*.test.tsx' --include='*.spec.ts' \
        app components lib e2e 2>/dev/null; then
      echo "테스트 미인용: $id"
      fail=1
    fi
  fi
done

if [ "$fail" -eq 0 ]; then
  if [ "$check_tests" = "--tests" ]; then
    echo "커버리지 OK: 모든 판정 기준이 plan에 배정되고 테스트에 인용되어 있다"
  else
    echo "커버리지 OK: 모든 판정 기준이 plan에 배정되어 있다"
  fi
fi
exit "$fail"
