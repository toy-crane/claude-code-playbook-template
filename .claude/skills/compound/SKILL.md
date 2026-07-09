---
name: compound
description: 여러 feature에 쌓인 `artifacts/*/learnings.md`를 정리한다 — 중복 병합, 충돌 해소, 낡은 항목 폐기, hypothesis 확정. 승격은 하지 않는다. learnings.md가 여러 feature에 쌓였을 때 트리거하고, 단일 feature 진행 중에는 쓰지 않는다. "/compound", "회고", "메모리 정리"로도 호출한다.
---

# Compound: 메모리 정리

learnings.md는 feature 간 메모리 레이어다. `/draft-plan`과 `/execute-plan`이 검색으로 소비하므로, 메모리의 품질이 곧 다음 feature의 품질이다. 이 스킬은 규칙을 만들지 않는다 — **쌓인 메모리를 병합·해소·폐기·확정으로 관리한다.** 나쁜 메모리는 무용한 게 아니라 유해하다(에이전트는 저장된 경험을 그대로 따라 하므로).

## Inputs / Outputs

| 입력 | 출력 |
|---|---|
| 모든 `artifacts/*/learnings.md` | 사용자 승인을 거친 learnings.md 정리 (병합·수정·삭제) |

## Workflow

### Step 1. 수집

모든 `artifacts/*/learnings.md` 파일을 읽는다.

### Step 2. 분석

네 종류의 후보를 찾는다:

| 신호 | 조치 후보 |
|---|---|
| 같은 triggers·주제의 항목이 여러 feature에 흩어져 있다 | **병합** — 하나의 강한 교훈으로 합치고 지시문을 일반화한다 |
| 서로 모순되는 지시문이 있다 | **충돌 해소** — 증거를 대조해 한쪽을 수정하거나 scope로 분리한다 |
| scope·date가 낡았거나 이후 작업이 지시문을 반증했다 | **폐기** — 삭제한다 |
| `hypothesis` 항목의 패턴이 다른 feature에서 재발했다 | **확정** — `status: verified`로 올리고 증거를 보강한다 |

### Step 3. 제안

각 후보를 사용자에게 제시한다:

- **무엇을 발견했는가**: 근거로 해당 learnings.md 항목들을 인용한다
- **어떤 조치인가**: Step 2의 네 분류 중 하나
- **조치 후의 모습**: 병합본·수정본 초안 또는 삭제 대상 목록

사용자가 승인한 것만 적용한다.

### Step 4. 적용

- **병합**: 병합본은 가장 관련 깊은 feature의 learnings.md에 두고, 흡수된 항목은 삭제한다. 병합본의 에피소드에 출처 feature들을 남긴다. triggers는 합집합으로 보강한다.
- **폐기**: 삭제로 처리한다 (주석 처리·보관 아님). 낡은 메모리를 남겨두면 검색에 계속 걸린다.
- **확정**: `status`를 `verified`로 바꾸고 재발 증거를 증거 필드에 추가한다.
