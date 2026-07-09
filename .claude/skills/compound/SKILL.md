---
name: compound
description: 여러 feature에 누적된 learnings.md의 약한 신호를 패턴으로 묶어 Skill·Hook·Rule·CLAUDE.md 승격을 제안한다. `artifacts/*/learnings.md`가 여럿 쌓였거나 같은 함정에 반복해 빠질 때 트리거한다. 단일 feature 진행 중에는 쓰지 않는다. "/compound", "원칙 갱신", "회고"로도 호출한다.
---

# Compound: 누적 회고

여러 feature에 누적된 약한 신호의 패턴을 찾아 원칙(Skill·Hook·Rule·CLAUDE.md)으로 승격할 후보를 제안한다. `/execute-plan` Step 6이 명확한 인사이트를 이미 즉시 승격하므로, 이 스킬은 그 시점엔 약했지만 누적되면 강해지는 신호를 다룬다.

## Inputs / Outputs

| 입력 | 출력 |
|---|---|
| 모든 `artifacts/*/learnings.md` (특히 `applied: not-yet` 항목) | 사용자 승인을 거친 Skill·Hook·Rule·CLAUDE.md 변경 |

## Workflow

### Step 1. 약한 신호 수집

모든 `artifacts/*/learnings.md` 파일을 읽는다. **`applied: not-yet`** 항목이 1차 분석 대상이다. `applied: rule`은 Step 6에서 이미 승격됐고, `applied: discarded`는 일회성으로 판정됐다.

추가로 다음 신호도 본다. 원리는 **사람의 추가 손길이 들었던 모든 흔적**이다:

- 복구 경로를 거친 실패 (build/test 실패 → 우회 → 재시도)
- 같은 에러에 두 번 이상 걸린 상황
- Human Review에서 사용자가 지적한 반복 패턴
- 수동 개입이 필요했던 상황
- 그 밖에도 "사람이 한 번 더 손대야 했던 것"은 모두 신호다

### Step 2. 승격 대상 분류

각 패턴을 적절한 메커니즘으로 분류한다. 기준: **무엇이 가장 적은 비용으로 재발을 막는가**

| 반복 유형 | 승격 대상 | 예시 |
|---|---|---|
| 같은 제약 위반이 반복됨 | **Rule** | `.tsx에서 px 단위 금지`, `components/ui/* 직접 수정 금지` |
| 100% 기계적으로 잡아야 하는 것 | **Hook** | 커밋 전 `bun run build`, 저장 후 linter 자동 실행 |
| 잘못된 사용 패턴 (올바른 방법을 가르쳐야 함) | **Skill** | shadcn 컴포넌트 설치·조합법, 특정 라이브러리 도입 가이드 |
| 아키텍처 결정 변경 | **CLAUDE.md** | 순방향 의존성 순서, 패키지 매니저 결정 |

새 Skill은 라이브러리·도구 단위로 제안한다. 더 작은 단위로 쪼개면 Skill이 누적되어 검색·관리 비용이 커지고, 더 큰 단위(phase 전체)로 묶으면 description으로 트리거하기 어렵다. 새 skill을 실제로 만들 땐 `skill-creator` 스킬을 쓴다. 상세 주제는 `references/`로 분리한다.

### Step 3. 변경 제안

각 제안을 사용자에게 제시한다:
- **무엇이 반복되었는가**: 근거로 해당 learnings.md 항목을 인용한다
- **어느 메커니즘으로 승격할지**: Step 2의 분류 중 하나
- **구체적 파일 경로와 내용 초안**

#### 메커니즘별 기본 경로

| 메커니즘 | 위치 |
|---|---|
| Rule | `.claude/rules/<name>.md` |
| Hook | `.claude/settings.json`: `hooks` 섹션 |
| Skill | `.claude/skills/<name>/SKILL.md` |
| CLAUDE.md | 프로젝트 루트의 `CLAUDE.md` |

사용자가 승인한 것만 적용한다. 적용 후 해당 learnings.md 항목의 `applied`를 `rule`로 갱신한다.
