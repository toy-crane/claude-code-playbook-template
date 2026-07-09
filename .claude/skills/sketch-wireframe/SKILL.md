---
name: sketch-wireframe
description: spec.md를 기반으로 HTML 와이어프레임을 생성하는 옵션 모듈. 레이아웃 구조가 바뀌는 UI feature(새 화면, 새 레이아웃, 화면 간 흐름)에 사용한다. 서버·데이터 전용 변경이나 레이아웃이 그대로인 변경에는 쓰지 않는다. "/sketch-wireframe", "wireframe", "와이어프레임", "레이아웃 확인"으로도 호출한다.
argument-hint: "feature name"
---

# Sketch Wireframe

spec.md를 기반으로 컴포넌트 배치·정보 계층·화면 간 흐름을 검증하는 HTML 와이어프레임을 만든다.

## Inputs / Outputs

| 입력 | 출력 |
|---|---|
| `artifacts/<feature>/spec.md`, 참조 이미지(있으면) | `artifacts/<feature>/wireframe.html` |

spec.md가 없으면 "`/write-spec <feature>`를 먼저 실행하세요." 출력 후 중단한다. wireframe은 spec의 시나리오를 입력으로 받기 때문이다. 시나리오 변경이 필요해지면 wireframe을 멈추고 `/write-spec`으로 돌아간다.

## Workflow

### Step 1. 기존 화면과 참조 자료 확인

프로젝트에 기존 구현이 있으면 관련 컴포넌트 코드를 읽어 레이아웃 구조를 파악한다. 기존 화면에 요소를 추가하는 경우 기존 레이아웃을 바탕으로 와이어프레임을 만든다.

`artifacts/<feature>/references/` 디렉토리에 참조 이미지가 있으면 읽는다. 이미지에서 레이아웃 구조(컴포넌트 배치, 정보 계층, 화면 분할 방식)만 추출하고 시각 디자인(색상, 폰트, 그림자 등)은 무시한다.

### Step 2. Base Screens

1. 이 스킬의 `assets/template.html`을 읽어 HTML 보일러플레이트를 얻는다
2. template.html 주석의 삽입 패턴(`NAV_BUTTONS`, `SCREEN_CONTENT`)을 따라 base 화면들을 생성한다
3. 화면 간 전환은 글로 설명하지 않고 배선한다: 전환을 일으키는 요소에 `data-goto="screen-<id>"`를 단다. 템플릿의 위임 핸들러가 클릭을 화면 전환으로 처리하므로, 리뷰어는 흐름을 읽는 대신 클릭해서 경험한다.
4. 화면 밖에서 진입하는 조건이 있을 때만 화면 제목 아래 `.screen-entry` 한 줄을 쓴다 (예: `진입: 로그인 성공 직후`). 그 외 설명 산문은 wireframe에 쓰지 않는다 — 시각 매체 안의 텍스트는 읽히지 않은 채 승인되고, 유효성 규칙과 비즈니스 로직은 spec.md 소관이다.

출력: `artifacts/<feature>/wireframe.html`

서버 시작: `Bash(run_in_background): bunx vite artifacts/<feature> --port=3456`. 3456 포트가 점유 중이면 Vite가 다음 빈 포트로 자동 이동한다. 백그라운드 출력에서 실제 `Local:` URL을 확인해 사용한다.

#### 피드백 루프

- 사용자에게 `http://localhost:<actual-port>/wireframe.html` 확인을 안내한다 (Mobile/Desktop 토글 양쪽 검증, `data-goto` 전환은 클릭으로 확인)
- 사용자 피드백을 받아 wireframe.html을 수정한다

레이아웃이 확정되면 Step 3으로 넘어간다.

### Step 3. Scenario Screens

확정된 레이아웃 위에 나머지 시나리오를 탭으로 추가한다.

#### 렌더 커버리지 원칙

화면이 `data-scenario`로 주장하는 시나리오는 그 화면의 렌더링에 실제로 보여야 한다. **렌더되지 않은 상태는 커버된 것이 아니다.** 한 렌더링에 공존할 수 없는 상태(빈 상태, 에러 상태)는 레이아웃을 복제해 별도 화면으로 만든다.

| 시나리오 차이 | 판정 |
|---|---|
| 항목 3개 리스트 vs 빈 리스트 | 별도 화면 (한 렌더링에 공존 불가) |
| 제목 에러 상태 → 에러 텍스트 노출 | 별도 화면 (기존 화면을 복제하고 에러 요소만 추가) |
| 모바일 1컬럼 ↔ 데스크톱 사이드바 2컬럼 | 같은 화면 (`@md:` 유틸리티 + 뷰포트 토글이 커버) |
| 일반 리스트 → 필터·검색 UI 추가된 리스트 | 새 화면 (새 요소 배치) |

#### 규칙

- 화면이 커버하는 시나리오는 `data-scenario` 속성에 spec의 시나리오 ID로 지정한다 (예: `data-scenario="S1"`). 본문 텍스트에 번호를 쓰지 않는다. 이 속성은 Step 4 coverage 대조의 입력이다.
- 각 시나리오의 판정 기준에 있는 구체적 값을 예시 데이터로 사용한다

Step 2의 **피드백 루프**를 같은 방식으로 적용해 검증한다.

### Step 4. Coverage 검증 + 핸드오프

기계 검사를 먼저 돌린다: `scripts/spec-coverage.sh <feature> --wireframe` (spec에 없는 ID 주장, dangling `data-goto` 검출).

이어서 spec.md에서 시각적 변경이 있는 시나리오 ID를 나열하고, 각 ID가 wireframe의 어느 화면(`data-scenario`)에 매핑되는지 대조한다. attribute만 있고 해당 상태가 렌더링에 보이지 않으면 미커버로 취급한다. 누락된 ID를 사용자에게 보고한다. 비시각적 시나리오(데이터 저장, 유효성 로직 등)는 wireframe 커버리지 대상이 아니다.

검증 후 **다음 단계**는 새 세션(`/clear`)에서 `/draft-plan <feature>`로 plan 작성이다.

## Principles

- **콘텐츠 영역은 5개의 CSS 변수만 쓴다** (`--w-bg`, `--w-border`, `--w-text`, `--w-muted`, `--w-fill`). 템플릿 크롬(nav, 뷰포트 토글, 모바일 프레임, `.screen-entry`)은 예외다. wireframe은 시각 디자인이 아니라 구조를 검증한다. 팔레트를 미니멀하게 고정해야 사용자의 주의가 레이아웃과 정보 계층으로 집중된다.
- **Mobile-first, Tailwind v4 utilities만** (`@container` + `@md:` prefix로 반응형). 반응형 동작이 실제 구현과 같은 방식으로 검증되기 때문이다. 유틸리티 클래스는 plan으로 넘어가지 않는다 — 하류(draft-plan, plan-reviewer)가 소비하는 것은 컴포넌트 유형이므로, 간격·크기를 정밀하게 다듬지 않는다.
- Lucide 아이콘: `<i data-lucide="icon-name"></i>` (버전은 template.html에 고정되어 있다)
- 커스텀 클래스가 필요하면 `<style>` 블록에 `w-` prefix로 추가한다
