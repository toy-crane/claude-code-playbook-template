# learnings.md 작성 가이드

구현 중 내린 판단·실수·발견을 `artifacts/<feature>/learnings.md`에 기록한다.

이 파일의 목적은 **같은 일을 다음에 더 쉽게 만드는 것**이다. Compound Engineering 정신이다. 명확한 인사이트는 `/execute-plan` Step 6에서 즉시 원칙(`.claude/rules/` 또는 `CLAUDE.md`)으로 승격하고, 여기엔 약한 신호만 메모로 남긴다. `/compound`가 여러 feature에 누적된 메모를 분석한다.

**기록 기준**: 모든 판단을 기록하지 않는다. 잘 풀린 일은 생략하고, **예상과 달랐던 것, 우회했던 것, 다시 마주치고 싶지 않은 것**만 남긴다.

## 항목 형식

각 항목은 YAML frontmatter 2키 + 본문 3필드로 쓴다.

```markdown
---
category: <task-ordering | spec-ambiguity | code-review | escalation | refactor | tooling>
applied: <rule | not-yet | discarded>
---
## <Title>

**상황**: <어디서 무엇을 결정했나. Step 번호, 트리거 사건>
**판단**: <무엇을, 왜 결정했나. 결과와 우회 포함>
**다시 마주칠 가능성**: 높음 / 중간 / 낮음 (한 줄 근거)
```

### 필드 의미

- `category`: 다른 feature의 같은 종류 학습과 묶기 위한 태그. 자유롭게 추가한다.
- `applied`:
  - `rule`: Step 6에서 이미 원칙으로 승격됨 (참고용 기록)
  - `not-yet`: 아직 약한 신호. compound의 누적 분석을 기다린다
  - `discarded`: 일회성으로 판정하고 일반화하지 않기로 함
- **상황**: 어디서 어떤 사건이 판단을 촉발했는가
- **판단**: 무엇을, 왜 결정했고 어떻게 됐나 (상태머신 없이 결과를 바로 적는다. commit이 진실의 출처다)
- **다시 마주칠 가능성**: 승격 우선순위 신호. "높음"인데 자주 안 마주치면 compound가 회고 때 정리한다

### 예시

```markdown
---
category: task-ordering
applied: not-yet
---
## auth-login을 submit-project보다 먼저 실행

**상황**: Step 2, Task 의존성 식별 중. plan은 submit-project를 먼저 두었지만, profiles 스키마를 공유함을 발견.
**판단**: 순서를 뒤집어 auth-login을 우선했다. 역순이면 throwaway stub이 필요했을 것이다.
**다시 마주칠 가능성**: 중간 (entity 수준 의존성을 plan.md가 표시하지 않는 패턴은 다른 feature에서도 재발할 수 있다).
```

## 기록 시점

전형적 트리거:

| Event | Step |
|---|---|
| Task 실행 순서 (의존성) | Step 2 |
| Spec 모호성 (하나의 해석을 선택) | Step 3 |
| Task 범위 변경 (추가 / 제거 / 병합) | Step 3 |
| 빌드 또는 테스트 실패 (복구 경로) | Step 3 |
| `/code-review` findings 판단 (accept / reject / partial) | Step 4 |
| 사용자 피드백 판단 | Step 5 |
| Step 6에서 즉시 승격된 항목 (`applied: rule`로 기록) | Step 6 |

자명한 결정(예: "대안 없이 plan.md를 그대로 따름")은 기록하지 않는다.
