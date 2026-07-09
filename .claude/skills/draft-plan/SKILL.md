---
name: draft-plan
description: spec.md를 기반으로 구현 계획(artifacts/<feature>/plan.md)을 작성한다. 여러 파일에 걸치거나 시나리오가 서로 의존하는 product feature에 쓴다. 한 세션에 끝나는 작업·meta-tooling·명백한 변경은 내장 plan 모드로 한다. "/draft-plan", "draft plan", "계획 작성", "구현 계획"으로도 호출한다.
argument-hint: "feature name"
---

# Draft Plan

spec.md의 판정 기준을 어떤 순서로, 어떤 단위로 구현할지 Task 단위 TDD 계획으로 쪼갠다.

## Inputs / Outputs

| 입력 | 출력 |
|---|---|
| `artifacts/<feature>/spec.md`, `wireframe.html` (있으면) | `artifacts/<feature>/plan.md` |

이 스킬은 plan.md만 만든다. 다른 프로젝트 파일은 생성하지도 수정하지도 않는다 (구현은 `/execute-plan`).

**내장 plan 모드와의 분기**: 한 세션에 끝나고 되돌리기 쉬운 작업이면 이 스킬 대신 내장 plan 모드를 쓴다. plan.md는 작업이 여러 세션에 걸치거나, 판정 기준 커버리지를 추적해야 할 때 값을 한다.

## Workflow

### Step 1. 전제 조건

`$ARGUMENTS`에서 feature 이름을 꺼낸다.

- `artifacts/<feature>/spec.md`: 없으면 "`/write-spec <feature>`를 먼저 실행하세요." 출력 후 중단
- `artifacts/<feature>/wireframe.html`: 있으면 참조

### Step 2. Pre-exploration

plan을 쓰기 전에 이미 존재하는 맥락을 코드·스킬·learnings 세 축에서 모은다.

- **코드베이스**: 아키텍처, 관련 패턴, 영향받을 파일, 의존성, 유사 기능을 파악하고 위험을 기록한다.
- **스킬**: `.claude/skills/`를 스캔해 이 feature와 조금이라도 관련 있는 스킬을 모두 고른다. 애매하면 포함한다. 빠진 스킬 때문에 plan이 프로젝트 규약과 어긋나는 쪽이 넘치는 쪽보다 비용이 크다.
- **learnings**: feature의 도메인 키워드(라이브러리, 파일 경로, 작업 유형)로 `artifacts/*/learnings.md`의 `triggers:` 라인을 grep한다. 걸린 `verified` 항목의 지시문은 plan의 입력이다 — 과거 함정이 Task에 닿으면 해당 Task의 검증 필드나 참조에 명시한다. `hypothesis`는 위험 항목으로만 기록한다.

### Step 3. 빈칸 채우기

Step 2의 입력을 읽고, 구현에 필요하지만 아직 결정되지 않은 항목을 찾는다.

- **변경 비용이 높은 결정만 묻는다**: 후속 수정이 쉬운 건 묻지 않고 초안에서 판단한다
- **한 번에 하나씩, 2~4개 선택지를 제시한다** (사용자가 한 번에 답할 수 있는 분량)

### Step 4. plan.md 생성

Step 2에서 확정한 각 스킬의 SKILL.md를 읽는다. plan이 실행 중 로드되는 규칙과 어긋나면 execute 단계에서 충돌이 터진다.

`references/plan-template.md`를 읽고 그 형식을 따른다. 원칙은 아래에, 형식은 template에 있다.

#### Vertical Slicing

각 Task는 end-to-end로 동작하고 테스트 가능한 slice여야 한다. horizontal layer(DB-only, API-only, UI-only)로 쪼개지 않는다. horizontal로 쪼개면 각 Task만으로는 end-to-end 테스트가 돌지 않아 회귀가 통합 시점에 한꺼번에 터진다.

```
OK (vertical):  Task 1: 사용자가 계정을 생성할 수 있다 (스키마 + API + 가입 UI)
NG (horizontal): Task 1: 모든 DB 스키마 / Task 2: 모든 API / Task 3: 모든 UI
```

#### Task Sizing

목표: S (1~2 파일) 또는 M (3~5 파일). L 이상은 금지한다. 리뷰가 사실상 불가능해지고 되돌리기 비용이 급격히 커진다.

판정: 담당 판정 기준이 너무 많거나, 여러 서브시스템에 닿거나, 제목에 "and"가 있으면 쪼갠다.

#### 판정 기준 배분

각 Task는 spec의 판정 기준을 **담당 판정 기준** 필드에 ID로 나열한다. 기준 문장을 복사하지 않는다. 원본은 spec에만 존재해야 수정할 곳이 하나로 유지된다.

- spec의 모든 ID(`S*`, `INV-*`)를 어느 Task엔가 배정한다
- 시나리오 일부만 담당하면 기준 ID를 낱개로 나열한다 (예: `S3-1, S3-2`)
- 한 기준이 두 Task에 걸치면 Task 경계가 잘못됐다는 신호다
- 배분을 마치면 커버리지를 검사한다: `scripts/spec-coverage.sh <feature>`

#### Verification

각 Task의 **검증** 필드에 그 Task의 판정 기준을 어떻게 증명하는지 적는다. 다른 사람이 같은 점검을 반복할 수 있어야 한다. 가장 낮은 증명 경계를 선택한다.

| 증명 가능한 곳 | 사용 |
|---|---|
| 코드 (DOM, 함수, DB, HTTP) | Vitest / `bun run typecheck` |
| 실제 브라우저, CI에서 반복 가능 | Playwright (`bun run test:e2e`) |
| 실제 브라우저, 일회성 증거 | Browser MCP (`mcp__claude-in-chrome__*`) |
| 자동화 불가능 (디자인 판단, 스크린 리더, cross-browser 느낌) | Human review: 리뷰어·기준 명시, 증거는 `artifacts/<feature>/evidence/`에 저장 |

#### Ordering & Checkpoint

- 테스트 파일 생성을 먼저 둔다
- 의존성이 적은 Task부터, **고위험 Task를 앞에** 둔다. 실패가 일찍 드러나야 sunk cost가 작고 plan을 조기에 재조정할 수 있다.
- 각 Task는 시스템을 동작 가능한 상태로 둔다
- Task 2~3개마다 체크포인트를 삽입한다 (테스트 + 빌드 + 커버리지 검사 + slice의 end-to-end 동작). 마지막 체크포인트는 spec의 End-to-end 검증 절차 실행이다.

#### Wireframe 통합

- `wireframe.html`이 있으면 Task의 구현 대상에 컴포넌트 유형을 반영한다
- wireframe에서 식별된 컴포넌트 중 프로젝트에 없는 것은 직접 구현하기 전에 패키지 레지스트리에서 설치 가능한지 먼저 확인한다

#### 기타

- "영향받는 파일" 섹션에 코드베이스 탐색 결과를 반영한다
- Task 참조에는 실행자가 스스로 찾을 수 없는 외부 소스만 넣는다 (스킬은 이름 + 키워드)

파일명: `artifacts/<feature>/plan.md`

### Step 5. 독립 검토 (조건부)

다음 중 하나에 해당하면 `plan-reviewer` 에이전트를 호출한다:

- Task가 5개 이상이거나 의존성이 얽혀 있다
- `wireframe.html`이 있다
- 중간에 되돌리기 비싼 도메인이다 (마이그레이션, 결제, 권한)

해당 없으면 건너뛴다. 판정 기준 커버리지는 Step 4의 스크립트가 이미 기계적으로 검사했다. 리뷰어는 기계가 못 보는 것(Task 분해의 건전성, wireframe 일관성)만 본다. 불일치가 보고되면 사용자에게 제시하고, 어느 것을 plan.md에 반영할지 결정받는다.

### Step 6. Human Review & Handoff

완성된 plan.md를 사용자에게 제시한다. 승인 또는 수정 요청을 받고, 요청된 변경을 반영한다. 사용자가 승인할 때까지 다음 단계로 진행하지 않는다.

승인되면 **다음 단계**는 새 세션(`/clear`)에서 `/execute-plan <feature>`다.
