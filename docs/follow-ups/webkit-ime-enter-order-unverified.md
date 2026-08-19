# WebKit 에서 조합 확정 Enter 가 걸러지는지 확인하지 못했다

## 증상 (추정)

Safari·iOS 에서 한글 조합을 확정하는 Enter 가 "추가"로 처리되어, 확정된
글자가 입력창에 남은 채 항목이 들어가고 사용자가 Enter 를 한 번 더 누르면
같은 항목이 두 번 생길 수 있다. 편집창에서도 조합 확정 Enter 가 편집을
일찍 닫을 수 있다.

`docs/specs/todo-app/spec.md` 의 "한 번의 Enter 로 추가되면서 확정된 글자가
입력창에 남아 같은 항목이 두 번 들어가는 일이 없어야 한다" 를 어긋나게 한다.

## 관찰한 근거와 확인하지 못한 것

Chromium 에서 CDP 로 실제 조합 이벤트를 보내 측정한 순서는 이렇다.

```
compositionstart → compositionupdate → input(isComposing=true)
→ keydown Enter (isComposing=true)   ← 조합을 확정하는 Enter
→ compositionupdate → input → compositionend
→ keydown Enter (isComposing=false)  ← 사용자가 다시 누른 Enter
```

확정 Enter 가 `compositionend` 보다 먼저 오므로 `isComposing` 으로 정확히
걸러진다. 실제로 Chromium 에서는 중복 추가가 일어나지 않는 것을 확인했다.

2026-08-19 코드 리뷰는 WebKit 이 `compositionend` 를 확정 `keydown` 보다
먼저 보내는 경우가 있어 `isComposing` 이 false 로 온다고 지적했다. 이
저장소의 실행 환경에는 WebKit 을 띄울 시스템 라이브러리가 없어
(`bunx playwright install webkit` 이 호스트 의존성 검증에서 실패) 그 순서를
직접 확인하지 못했다. Playwright 프로젝트도 chromium 하나뿐이다.

## 시도한 것

`isComposing` 에 더해 `keyCode === 229` 를 함께 본다. 위험이 없는 보강이지만,
지적된 순서(조합이 이미 끝나 `isComposing` 도 false, `keyCode` 도 13)에는
효과가 없다.

`compositionend` 직후 짧은 시간 안에 온 Enter 를 무시하는 방식도 검토했으나
넣지 않았다. 한국어 사용자는 Enter 를 빠르게 두 번 누르는 일이 잦아, 확인하지
못한 이득을 위해 정상 입력을 삼킬 위험을 감수할 이유가 없다고 판단했다.

## 다음에 할 것

1. WebKit 을 띄울 수 있는 환경에서 위와 같은 이벤트 순서를 측정한다.
   실행 파일은 `/opt/pw-browsers/webkit-2336` 에 이미 내려와 있고, 부족한 것은
   시스템 라이브러리다(`bunx playwright install-deps webkit`).
2. 순서가 다르다면 `compositionend` 시점을 기록해 그 직후의 Enter 만 거르되,
   창을 아주 짧게(같은 이벤트 루프 턴 수준) 잡아 정상 입력을 삼키지 않게 한다.
3. `playwright.config.ts` 에 webkit 프로젝트를 더해 회귀를 잡는다.
