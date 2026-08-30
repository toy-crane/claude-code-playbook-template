# UI 구성 원칙

## Decisions

- 일반적인 UI는 설치된 shadcn Skill과 공식 shadcn/ui를 기본 구성 체계로 사용합니다. 필요한 UI를 직접 만들기 전에 공식 component와 Block을 먼저 찾습니다.
- Button, Field, Card, Dialog, Tabs, Table, Empty, Alert, Skeleton처럼 이미 제공되는 일반 UI는 별도의 markup으로 다시 만들지 않습니다. 공식 component를 조합해도 해결되지 않는 요구만 직접 구현합니다.
- 하나의 프로젝트에서는 preset, semantic token, typography, radius, spacing scale과 component variant를 하나의 시각 언어로 유지합니다. 일반 UI의 색상과 상태는 `background`, `foreground`, `primary`, `muted`, `destructive` 같은 semantic token으로 표현하고 화면마다 임의의 색상을 덮어쓰지 않습니다.
- 같은 역할의 component는 같은 variant를 사용합니다. 반복되는 class 조합은 공통 variant나 project component로 올리고, 화면별 예외를 계속 추가하지 않습니다.
- 반복되는 작업은 같은 composition으로 표현합니다. 검색과 필터, 폼 action, 목록과 상세 정보, 빈 상태와 오류 상태처럼 같은 의미의 UI가 화면마다 다른 구조와 동작을 사용하지 않습니다.
- 페이지 레이아웃에는 공통 shell을 둡니다. content width, 좌우 gutter, section 간격과 header 위치를 shell에서 관리하고, 개별 화면은 자신의 주된 목적에 필요한 column과 content order만 결정합니다.
- Tailwind class는 flow, grid, gap, alignment와 responsive layout을 구성하는 데 사용합니다. 고정 좌표와 임의의 pixel 값보다 정해진 spacing scale과 자연스러운 document flow를 우선합니다.
- 각 화면은 주된 목적과 가장 중요한 action을 분명히 드러냅니다. 입력, 주요 결과, 보조 정보의 시각적 위계와 사용 순서가 heading, spacing, grouping과 action priority에 반영되어야 합니다.
- loading, empty, error, success, disabled 상태를 정상 화면과 함께 설계합니다. 상태가 달라도 같은 component와 layout 문법을 유지합니다.
- 좁은 화면에서는 정보의 중요도와 사용 순서를 보존한 채 column을 쌓습니다. 단순 축소로 내용이나 action을 숨기지 않습니다.

## Boundaries

- 모든 콘텐츠를 Card에 넣거나 모든 프로젝트에 같은 페이지 레이아웃을 적용하는 결정이 아닙니다.
- 게임, 지도, 캔버스, 데이터 시각화처럼 사용자 경험의 핵심인 표면은 custom UI로 만들 수 있습니다. 그 안의 일반적인 control, navigation, overlay, feedback은 가능하면 shadcn 구성을 유지합니다.
- 공식 component가 필요한 상호작용을 표현하지 못하거나 custom UI가 사용자 결과를 실질적으로 개선할 때는 직접 구현할 수 있습니다. 이때도 현재 token, 접근성, 상태 표현과 인접한 UI의 composition을 유지합니다.
- shadcn 구성을 사용했다는 사실만으로 UI가 완료되지 않습니다. 정보 계층, 콘텐츠 밀도, primary action의 가시성, 반응형 레이아웃과 상태 간 일관성을 실제 화면에서 따로 판단합니다.

## Why

일반 UI를 화면마다 다른 markup, 색상, spacing과 상태 표현으로 만들면 시각 언어가 잘게 나뉘고 접근성과 유지보수 비용이 커집니다. 반복되는 control과 composition은 shadcn의 검증된 기본값을 사용하고, 사용자 결과를 구별하는 표면에만 custom UI를 사용하면 일관성을 지키면서도 고유한 시각 정체성을 만들 수 있습니다.

페이지 레이아웃을 하나의 고정된 모양으로 통일하면 구현은 쉽지만 사용자의 작업과 콘텐츠의 차이를 숨깁니다. 대신 component와 token의 문법을 통일하고, 레이아웃은 주된 목적과 정보 순서에 맞게 구성합니다.

## Reconsider when

- 공식 shadcn component와 Block이 제품의 핵심 상호작용을 지속적으로 제한하거나 동등한 접근성을 제공하지 못할 때
- 공통 구성 체계가 고유한 시각 정체성을 지속적으로 제한한다는 반복 가능한 근거가 생길 때

## Still-rejected alternatives

- 모든 UI를 custom markup과 개별 스타일로 구현하는 방식 — 화면 사이의 composition과 상태 표현이 쉽게 달라지고 검증해야 할 범위가 늘어납니다.
- 하나의 preset과 고정된 페이지 레이아웃을 모든 프로젝트에 그대로 적용하는 방식 — 통일성은 높지만 작업과 콘텐츠의 차이를 표현하지 못합니다.
