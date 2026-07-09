---
name: sketch-wireframe
description: spec.md를 기반으로 HTML 와이어프레임을 생성하는 옵션 모듈. 레이아웃 구조가 바뀌는 UI feature에서 사용한다 (예: 새 화면, 새 레이아웃, 화면 간 흐름). 서버·데이터 전용 변경이나 단일 카피·토글처럼 레이아웃이 그대로인 변경에는 쓰지 않는다. 레이아웃을 시각적으로 검증하고 피드백 루프를 도는 게 본질이기 때문이다. "/sketch-wireframe", "wireframe", "와이어프레임", "레이아웃 확인"으로도 호출한다.
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
3. 각 화면 하단에 Screen Notes를 쓴다: 트리거(진입 조건), 인터랙션(핵심 행동), 전환(다른 화면으로 이동하는 조건)

#### Screen Notes 예시

좋음:
```
트리거: 로그인 성공 직후 진입
인터랙션: 상단 "새 할 일" 버튼 클릭 → 입력 폼 표시 / 리스트 항목 클릭 → 상세 화면 전환
전환: "로그아웃" 클릭 → 로그인 화면으로 이동
```

나쁨 (비즈니스 로직·유효성 규칙이 섞임):
```
트리거: 로그인 성공 직후 진입
인터랙션: "새 할 일" 제출 시 제목이 빈 문자열이면 에러, 100자 초과면 에러, 중복이면 경고 dialog 표시
```
유효성 규칙은 spec.md 소관이다. wireframe에 들어오면 wireframe이 바뀔 때마다 규칙을 다시 봐야 한다.

출력: `artifacts/<feature>/wireframe.html`

서버 시작: `Bash(run_in_background): bunx vite artifacts/<feature> --port=3456`. 3456 포트가 점유 중이면 Vite가 다음 빈 포트로 자동 이동한다. 백그라운드 출력에서 실제 `Local:` URL을 확인해 사용한다.

#### 피드백 루프

- 사용자에게 `http://localhost:<actual-port>/wireframe.html` 확인을 안내한다 (Mobile/Desktop 토글 양쪽 검증)
- 사용자 피드백을 받아 wireframe.html을 수정한다

레이아웃이 확정되면 Step 3으로 넘어간다.

### Step 3. Scenario Screens

확정된 레이아웃 위에 나머지 시나리오를 탭으로 추가한다.

#### 새 화면 vs 기존 화면 매핑

원리: **새 레이아웃 구조**가 필요하면 새 화면, **데이터·상태만 다르면** 기존 화면을 재사용한다. 보통의 경우 다음 표가 가이드다:

| 시나리오 차이 | 판정 |
|---|---|
| 빈 리스트 → 항목 3개 있는 리스트 | 기존 화면 재사용 (`data-scenario` 매핑) |
| 모바일 1컬럼 → 데스크톱 사이드바 + 본문 2컬럼 | 새 화면 (레이아웃 구조가 다름) |
| 제목 에러 상태 → 에러 텍스트 노출 | 기존 화면 재사용 |
| 일반 리스트 → 필터·검색 UI 추가된 리스트 | 새 화면 (새 요소 배치) |

#### 규칙

- 화면이 커버하는 시나리오는 `data-scenario` 속성에 spec의 시나리오 ID로 지정한다 (예: `data-scenario="S1, S2"`). 본문 텍스트에 번호를 쓰지 않는다. 시나리오 토글이 attribute로 동작해야 같은 화면 위에서 데이터만 갈아끼울 수 있다.
- 각 시나리오의 판정 기준에 있는 구체적 값을 예시 데이터로 사용한다
- Screen Notes에는 화면 흐름만 쓴다 (진입 조건, 전환, 요소 역할). 유효성 규칙과 비즈니스 로직은 spec.md에 속한다.

Step 2의 **피드백 루프**를 같은 방식으로 적용해 검증한다.

### Step 4. Coverage 검증 + 핸드오프

spec.md에서 시각적 변경이 있는 시나리오 ID를 나열하고, 각 ID가 wireframe의 어느 화면(`data-scenario`)에 매핑되는지 대조한다. 누락된 ID를 사용자에게 보고한다. 비시각적 시나리오(데이터 저장, 유효성 로직 등)는 wireframe 커버리지 대상이 아니다.

검증 후 **다음 단계**는 `/draft-plan <feature>`로 plan 작성이다.

## Principles

- **5개의 CSS 변수만 쓴다** (`--w-bg`, `--w-border`, `--w-text`, `--w-muted`, `--w-fill`). 그 외 색상은 쓰지 않는다. wireframe은 시각 디자인이 아니라 구조를 검증한다. 팔레트를 미니멀하게 고정해야 사용자의 주의가 레이아웃과 정보 계층으로 집중된다.
- **Mobile-first, Tailwind v4 utilities만** (`@container` + `@md:` prefix로 반응형). 프로젝트의 실제 구현 스택과 동일하므로 확정된 wireframe의 유틸리티를 거의 그대로 plan 단계로 옮길 수 있다.
- Lucide 아이콘: `<i data-lucide="icon-name"></i>`
- 시스템 monospace 폰트
- 커스텀 클래스가 필요하면 `<style>` 블록에 `w-` prefix로 추가한다
