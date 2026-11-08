# 의존성 버전 정책

## Decisions

- `next`, `react`, `react-dom`, `eslint-config-next`는 caret 없이 정확한 버전으로 고정합니다. 네 패키지는 함께 올리고, `eslint-config-next`는 항상 `next`와 같은 번호를 씁니다.
- 그 밖의 의존성은 caret 범위로 두고 `bun update`로 갱신합니다. 메이저를 넘는 상향은 개별로 판단합니다.
- `typescript`는 6.0.x를 상한으로 유지합니다. 7.x로 올리지 않습니다.
- `@types/node`는 `create-next-app` 템플릿 기본값이 아니라 이 프로젝트를 실제로 실행하는 Node의 메이저에 맞춥니다. 현재는 `^26`입니다.

## Boundaries

- 특정 라이브러리를 쓰지 말라는 결정이 아닙니다. 버전을 고를 때의 기준만 정합니다.
- `next` 메이저 업그레이드 자체를 막는 결정도 아닙니다. 다만 `next`를 올리면 `eslint-config-next`도 같은 번호로 따라가야 합니다.

## Why

`typescript` 7.x는 린트를 깨뜨립니다. `eslint-config-next`가 `typescript-eslint`를 dependency로 끌고 오는데, 이 패키지의 peer가 `typescript >=4.8.4 <6.1.0`입니다. TS 7에서는 설정을 읽는 단계에서 `typescript-eslint does not support TS 7.0`으로 즉시 실패합니다. 직접 설치한 적 없는 패키지가 상한을 결정하므로, `typescript`만 보고 올리면 원인을 찾기 어렵습니다.

`@types/node`를 실행 Node에 맞추는 이유는 타입이 실제 런타임과 어긋나지 않게 하기 위해서입니다. `create-next-app` 16.4.5 템플릿은 `^20`으로 고정하지만, 이 저장소는 Node 26에서 돌고 `vitest` 5의 engines도 `>=26`을 포함합니다. 템플릿 기본값을 따르면 최신 Node API가 타입에 없습니다.

`next`와 React를 정확한 버전으로 고정하는 이유는 강의용 템플릿이어서입니다. 수강생이 각자 설치한 시점에 따라 다른 버전을 받으면 화면과 오류 메시지가 달라집니다. `next`의 peer는 `react ^18.2.0 || ^19.0.0`으로 넓어서 고정하지 않으면 범위 안에서 흔들립니다.

## Reconsider when

- `typescript-eslint`가 TS 7 이상을 지원하는 정식 버전을 내면 `typescript` 상한을 다시 봅니다. 추적 이슈는 typescript-eslint#10940입니다.
- 이 저장소가 돌아가는 Node 메이저가 바뀌면 `@types/node`도 함께 옮깁니다.

## Still-rejected alternatives

- `typescript` 7과 TS 6 API를 나란히 설치해 `typescript-eslint`만 6으로 돌리는 방식 — 학습 템플릿에 런타임을 두 벌 얹게 되고, 수강생이 둘의 차이를 신경 써야 합니다.
- `@types/node`를 템플릿 기본값 `^20`에 맞추는 방식 — `create-next-app` 결과와는 같아지지만, 실행 중인 Node 26의 API가 타입에 없습니다.
