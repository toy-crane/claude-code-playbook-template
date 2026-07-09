# learnings.md 작성 가이드

구현 중 내린 판단·실수·발견을 `artifacts/<feature>/learnings.md`에 기록한다.

이 파일은 feature 간 **메모리 레이어**다. 모든 교훈은 이 파일 안에서 완결된다 — 다른 곳으로 승격되지 않고, 다음 feature가 `/draft-plan`·`/execute-plan`의 검색(grep)으로 소비한다. 따라서 각 항목은 과거의 서사가 아니라 **미래의 검색어에 걸리는 교훈 카드**로 쓴다.

**기록 기준**: 모든 판단을 기록하지 않는다. 잘 풀린 일과 자명한 결정은 생략하고, **예상과 달랐던 것, 우회했던 것, 다시 마주치고 싶지 않은 것**만 남긴다.

## 항목 형식

각 항목은 YAML frontmatter 4키 + 본문 3필드로 쓴다.

```markdown
---
triggers: [vitest, jsdom, ThemeToggle, "matchMedia is not defined"]
status: verified
scope: this-repo (vitest 3.x, jsdom)
date: 2026-07-09
---
## jsdom에는 matchMedia가 없다

**지시문**: matchMedia를 쓰는 컴포넌트를 테스트할 때는 vitest.setup.ts의 stub을 먼저 확인하고, 없으면 vi.stubGlobal로 추가하라.
**에피소드**: Task 4에서 ThemeToggle 테스트가 ReferenceError로 실패. 컴포넌트가 아니라 테스트 환경의 문제였다.
**증거**: commit a1b2c3d, ThemeToggle.test.tsx [S2-1] 통과
```

### 필드 의미

- `triggers`: **가장 중요한 필드.** 이 교훈이 적용되는 상황의 검색 키워드 — 파일 경로, 라이브러리명, 작업 유형, 그리고 **에러 메시지 원문 그대로**(grep이 걸리도록). 반드시 한 줄로 쓴다. 검색되지 않는 항목은 존재하지 않는 것과 같다.
- `status`:
  - `verified`: 근본 원인과 증거를 확보했거나 재발로 확인됨. 검색되면 지시문을 그대로 따라도 안전하다.
  - `hypothesis`: 한 번 겪었지만 원인이 불확실. 읽는 쪽은 참고만 하고 그대로 따르지 않는다. 재발 시 `/compound`가 verified로 확정한다.
- `scope`: 유효 범위 (예: `this-repo`, `next@15 한정`). `date`와 함께 `/compound`가 낡음을 판정하는 축이다.
- **지시문**: "X 상황이면 Y를 하라/하지 마라"의 조건→행동 명령형 1~2문장. 서사가 아니라 미래의 에이전트가 그대로 실행할 수 있는 형태로 쓴다.
- **에피소드**: 한 문단 이내의 상황·판단. 지시문이 나중에 틀렸다고 판명될 때 폐기 여부를 결정하는 근거다.
- **증거**: 커밋 해시, 테스트 이름, 재현 절차 등 검증의 최소 근거. 증거를 못 대면 `status: hypothesis`다.

### 남기지 않는 것

- 잘 풀린 일의 서사, 자명한 결정 (예: "대안 없이 plan.md를 그대로 따름")
- 검증 안 된 추측을 `verified`로 — hypothesis로 격리하거나 버린다
- diff·commit·plan.md에서 이미 읽을 수 있는 것 (출처 단일화)
- triggers 키워드를 쓸 수 없는 항목 — 검색될 수 없으면 메모리가 아니다

## 기록 시점

전형적 트리거:

| Event | Step |
|---|---|
| Task 실행 순서를 plan과 다르게 결정한 경우 | Step 2 |
| Spec 모호성 (하나의 해석을 선택) | Step 3 |
| Task 범위 변경 (추가 / 제거 / 병합) | Step 3 |
| 빌드 또는 테스트 실패 (복구 경로와 근본 원인) | Step 3 |
| `/code-review` findings 판단 (accept / reject / partial) | Step 4 |
| 사용자 피드백 판단 | Step 5 |
| Step 6 회고에서 정리·보강된 항목 | Step 6 |
