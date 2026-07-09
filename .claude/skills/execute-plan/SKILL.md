---
name: execute-plan
description: 확정된 artifacts/<feature>/plan.md의 Task를 TDD로 하나씩 구현하고 Task당 한 커밋을 만든다. 사용자가 "이제 구현 시작", "플랜 실행" 같은 신호를 보낼 때 트리거한다. plan.md 없이 바로 구현하는 경우에는 쓰지 않는다. "/execute-plan", "플랜 실행", "구현 시작"으로도 호출한다.
argument-hint: "feature name"
---

# Execute Plan

plan.md의 Task를 메인 컨텍스트에서 한 번에 하나씩 직접 구현한다. 구현은 직접 하고, 독립 검증은 내장 `/code-review` 스킬에 위임한다. 판단은 전부 직접 내리고 `artifacts/<feature>/learnings.md`에 기록해 다음 feature를 더 쉽게 만든다. Compound Engineering 정신이다.

완료의 기준은 실행 증거다. spec.md의 판정 기준 체크박스는 테스트 통과 또는 End-to-end 확인으로만 켠다.

## Inputs / Outputs

| 입력 | 출력 |
|---|---|
| `artifacts/<feature>/plan.md`, `spec.md`, `wireframe.html`(있으면) | 코드 + 커밋, `artifacts/<feature>/learnings.md` |

## Workflow

### Step 1. 전제 조건 확인

`$ARGUMENTS`에서 feature 이름을 추출한다.

- `artifacts/<feature>/plan.md`: 없으면 "`/draft-plan`을 먼저 실행하세요." 출력 후 중단
- `artifacts/<feature>/spec.md`: 없으면 "`/write-spec`을 먼저 실행하세요." 출력 후 중단. 커버리지 검사와 판정 기준 체크가 이 파일 경로에 의존한다
- spec.md에서 판정 기준 ID와 원문을 읽는다
- `artifacts/<feature>/wireframe.html`: 있으면 참조
- plan.md의 필요 스킬에 나열된 각 SKILL.md 읽기
- `references/learnings-template.md` 읽기 (learnings.md 기록 형식 확인)
- **과거 learnings 검색**: feature 이름과 plan.md의 기술 키워드(라이브러리, 파일 경로, 작업 유형)로 `artifacts/*/learnings.md`의 `triggers:` 라인을 grep하고, 걸린 항목만 읽는다. `status: verified`는 지시문을 따르고, `hypothesis`는 참고만 한다.

### Step 2. Task 순서 결정

plan.md의 Task 목록을 분석한다.

1. Task 간 의존성을 식별한다 (공유 파일, import 관계, 데이터 흐름)
2. 실행 순서를 결정한다 (순차, 의존성 우선)
3. 순서를 간단히 출력한다

plan.md와 다르게 순서를 결정한 경우에만 그 근거를 learnings.md에 기록한다.

### Step 3. Task 실행

Step 2의 순서대로 Task를 한 번에 하나씩 구현한다. 각 Task에 대해:

1. **담당 판정 기준**의 ID로 spec.md에서 원문을 읽는다
2. **코드로 표현 가능한 판정 기준에 TDD(RED → GREEN)를 적용한다**: UI 시각 검증·디자인 판단은 제외. `CLAUDE.md` → Testing 규율을 따른다. 테스트 이름에 담당 ID를 `[S1-1]` 형식으로 인용한다.
3. 기준을 충족하는 최소 코드를 구현한다
4. `bun run typecheck`와 영향받은 테스트를 실행한다 (풀빌드는 체크포인트에서만 돈다)
5. Task당 conventional commit 하나를 만든다
6. plan.md에서 Task를 완료로 표시하고, 테스트로 증명된 판정 기준의 체크박스를 spec.md에서 켠다

plan의 체크포인트에 도달하면 체크포인트 항목을 실행한다 (테스트 + 빌드 + `scripts/spec-coverage.sh <feature> --tests` + slice 동작 확인). **마지막 체크포인트는 spec.md의 End-to-end 검증 절차를 실제로 실행하는 것이다.** 절차가 통과해야 feature가 완료다.

컨텍스트가 길어졌으면 체크포인트 통과 후 `/clear`하고 `/execute-plan <feature>`로 재개해도 안전하다. plan.md의 완료 표시와 spec.md 체크박스가 진행 상태를 들고 있다.

빌드·테스트가 실패하면 근본 원인을 찾기 전에 **에러 메시지 문자열로 `artifacts/*/learnings.md`를 grep**한다 — 과거에 같은 함정을 밟았다면 verified 지시문이 우회 없이 해결해 준다. 없으면 우회하지 않고 근본 원인을 찾는다. 빌드 skip, 테스트 disable, 에러 swallow는 기술 부채를 가리는 단기 우회일 뿐이다.

#### 유연한 판단

상황에 따라 Task 재정렬·병합, spec 범위 밖 피드백 기각, 접근 전환, 사용자 escalation을 직접 결정한다. 다음 같은 판단은 기록할 가치가 있다:

- **재정렬이 정당한 경우**: Task 3이 Task 1의 출력에 의존하는데 plan이 역순으로 배치했다. 순서를 바꿔 throwaway stub을 없앤다.
- **피드백 기각이 정당한 경우**: 사용자가 "비밀번호 재설정도 같이 해달라"고 요청했다. spec 범위 밖이므로 learnings.md에 근거를 기록하고 "새 feature로 다루자"고 제안한다.

판단은 learnings.md에 기록한다. 형식은 `references/learnings-template.md`에 있다.

### Step 4. 독립 코드 리뷰

모든 Task 구현이 끝나면:

1. **내장 `/code-review` 스킬을 실행한다**: feature 브랜치의 전체 diff를 대상으로 한다 (마지막 커밋만 보지 않는다). 정확성 버그와 함께 중복·재사용·단순화 정리도 보고된다.
2. feature가 인증·결제·개인정보를 다루면 **내장 `/security-review`도 실행한다**.
3. **왜곡 검사를 직접 수행한다**: 각 테스트가 이름에 인용한 판정 기준 ID의 spec 원문과 실제 단언 내용을 대조한다. 커버리지 스크립트는 ID의 존재만 확인하므로, ID를 달고 엉뚱한 것을 단언하는 테스트는 여기서 잡는다.

보고된 findings를 분류해 처리한다. 기준: **지금 안 고치면 다음에 얼마의 비용이 드는가**

- **Critical**: 머지하면 사용자·시스템에 즉각 손해. 직접 수정하고 영향받은 테스트를 재실행한다. (예: PII 노출, 보안 취약점, 데이터 손실)
- **Important**: 동작은 하지만 다음 작업 비용을 누적시킨다. 직접 수정한다 (spec 범위 밖이면 learnings.md에 근거를 기록하고 기각). (예: 유지보수 부담, 중복)
- **Suggestion**: 동작·유지보수 영향이 없는 가독성·취향. Step 7 보고에만 언급하고, 반영은 선택이다.

판정을 learnings.md에 기록한다.

### Step 5. Human Review

모든 Task가 완료되면 사용자에게 요약을 제시한다:

- 판정 기준 ID별 상태 (pass / fail, 실행 증거와 함께)
- `bun run build`와 테스트, 커버리지 검사 결과
- spec.md End-to-end 검증 절차의 실행 결과

사용자에게 spec.md 대비 feature를 검증해 달라고 요청한다. 피드백이 있으면 직접 수정하고 재검증한다. 판단을 learnings.md에 기록한다.

### Step 6. Retrospective: 학습 정리

Compound Engineering 정신: 이번 feature가 다음 feature를 더 쉽게 만들도록 학습을 누적한다. 항상 실행한다. 발견이 없으면 "발견 없음"도 기록한다.

다음 3질문에 답해 사용자에게 제시한다:

1. **무엇이 잘 됐는가**
2. **무엇이 안 됐는가**
3. **다음에도 쓸 인사이트는 무엇인가**

이어서 이번 feature의 learnings.md 항목을 최종 정리한다. learnings는 다음 feature가 검색으로 소비하는 메모리이므로, 여기가 기록 품질을 지키는 마지막 관문이다:

- **triggers 보강**: 각 항목의 triggers를 미래의 검색어 관점에서 재검토한다 (에러 메시지 원문, 라이브러리명, 파일 경로가 들어갔는가)
- **증거 확인**: 커밋 해시·테스트 이름이 실제로 존재하는가
- **status 확정**: 증거가 있으면 `verified`, 원인이 불확실하면 `hypothesis`
- **재발 명기**: 과거 feature의 learnings에 같은 패턴이 이미 있으면 그 사실을 에피소드에 남긴다 (`/compound`의 병합·확정 근거가 된다)

### Step 7. Done

사용자에게 결과를 보고한다:

- **실행 요약**: 전체 Task 개수, 생성된 커밋
- **판정 기준 커버리지**: spec.md의 어느 기준이 실행 증거로 충족되었는가
- **학습 결과**: learnings.md에 남긴 교훈 요약 (verified / hypothesis 구분)

이번 feature는 완료다. learnings가 여러 feature에 쌓이면 **다음 단계**는 `/compound`로 메모리를 정리(병합·폐기·확정)하는 것이다.
