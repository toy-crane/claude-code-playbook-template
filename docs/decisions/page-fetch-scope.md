# Page Fetch Scope

## Decisions

- 변환 대상 URL은 헤드리스 브라우저 렌더링 없이, 서버가 받은 원본 HTML을 그대로 defuddle로 처리한다.

## Boundaries

- 이 결정은 "URL → 본문 추출" 파이프라인에만 적용된다. 이후 다른 목적(예: 스크린샷)으로 페이지를 렌더링할 필요가 생기면 별도로 판단한다.
- 자바스크립트로 본문을 나중에 그리는 SPA, 로그인이 필요한 페이지, 봇 차단이 있는 페이지에서 추출이 실패하는 것은 이 결정에 따른 정상 동작이며 버그가 아니다.

## Why

- defuddle의 Node.js 사용법은 linkedom/JSDOM 같은 정적 DOM 파서와 결합하도록 문서화되어 있고, 이는 페이지의 자바스크립트를 실행하지 않는다. 브라우저에서 직접 쓰는 경우도 이미 로드된 `Document`를 대상으로 하므로 마찬가지다.
- 대부분의 콘텐츠형 사이트(블로그, 뉴스, 위키, 문서 사이트)는 서버 렌더링 HTML에 본문이 이미 포함돼 있어 이 방식으로 충분하다.
- 헤드리스 브라우저(Playwright 등) 도입은 응답 시간(수 초 이상)과 서버 인프라 복잡도를 크게 늘리며, 이번 범위에서 요구되지 않았다.

## Reconsider when

- 실제 사용자가 시도하는 URL 중 SPA/로그인 필요 페이지 비율이 무시할 수 없을 만큼 확인되는 경우.
- defuddle이 자체적으로 헤드리스 렌더링 통합을 공식 지원하는 경우.

## Still-rejected alternatives

- Playwright 등 헤드리스 브라우저로 실제 렌더링 후 추출 — 커버리지는 넓어지지만 응답 지연·인프라 비용이 커서 채택하지 않음; SPA 지원 요구가 명확해지면 재검토.

## Evidence worth preserving

- 2026-08-17 defuddle 공식 문서(defuddle.md/docs) 확인: Node.js 사용 시 linkedom 또는 JSDOM 설치가 필요하고, 브라우저 런타임에서는 `Document` 객체를 직접 사용한다. 두 경로 모두 대상 페이지의 스크립트를 실행하지 않는 정적 파싱이며, `markdown: true` 옵션으로 Markdown을, title/author/description/site 등 메타데이터를 함께 반환한다.
