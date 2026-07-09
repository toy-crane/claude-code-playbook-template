---
name: idea-refine
description: 날것의 아이디어를 실행 가능한 one-pager(artifacts/<feature>/idea.md)로 다듬는 옵션 모듈. 아이디어가 막연하거나 MVP 범위·추진 방향을 정해야 할 때("이거 괜찮을까?", "뭘 먼저 만들지?") 트리거한다. 요구사항이 이미 구체적이면 건너뛰고 /write-spec으로 간다. "/idea-refine", "아이디어 정리", "ideate"로도 호출한다.
argument-hint: "idea or feature name"
---

# Idea Refine

날것의 아이디어를 추진할 만한 one-pager로 다듬는다. 요구사항이 이미 구체적이면 이 단계를 건너뛰고 `/write-spec`으로 간다.

## Inputs / Outputs

| 입력 | 출력 |
|---|---|
| 사용자의 날것 아이디어 | `artifacts/<feature>/idea.md` |

## Workflow

### Step 1. 질문으로 진단한다

아이디어를 명료한 문제 진술로 재진술한다. 사용자의 말을 되풀이하지 말고 문제의 틀 자체를 다시 잡는다. 그리고 `AskUserQuestion`으로 날카로운 질문을 3~5개 던진다. 초점: 누구를 위한 것인가, 성공은 어떤 모습인가, 진짜 제약은 무엇인가, 왜 지금인가. 처음 요청에 이미 답이 나왔으면 확인만 한다.

코드베이스 안이라면 `Glob`·`Grep`·`Read`로 기존 아키텍처·패턴·제약을 먼저 훑는다. 방향은 실제로 존재하는 것에 발을 붙여야 한다.

### Step 2. 방향을 제시하고 정직하게 평가한다

진짜로 다른 방향을 2~3개 만들고, 각각의 사용자 가치·실현 가능성·차별점을 평가한 뒤 하나를 추천한다. 낮은 차별성이나 높은 복잡도는 그대로 지적한다. 맞장구치지 않는다.

숨은 가정을 드러내고, **틀리면 아이디어가 죽는 가정**부터 검증 대상으로 삼는다.

확산 축, 평가 프레임워크, 가정 분류법 같은 사고 도구가 필요하면 `references/thinking-frameworks.md`를 참조한다.

### Step 3. One-pager로 정리한다

`references/idea-template.md` 형식으로 정리한다. MVP는 가장 위험한 가정을 먼저 검증해야 하고, "Not Doing" 리스트가 가장 가치 있다. 집중은 좋은 아이디어에 No라고 말하는 것이다.

사용자에게 `artifacts/<feature>/idea.md`에 저장할지 묻고, 확인했을 때만 저장한다.

저장 후 **다음 단계**는 `/write-spec <feature>`로 외부 관찰 가능한 동작을 spec.md에 확정하는 것이다.
