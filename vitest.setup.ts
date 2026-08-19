import "@testing-library/jest-dom/vitest";
import { cleanup } from "@testing-library/react";
import { afterEach } from "vitest";

// globals: false 이므로 Testing Library 자동 cleanup이 걸리지 않는다.
afterEach(cleanup);

// jsdom에는 ResizeObserver가 없다. 레이아웃을 계산하지 않는 환경이라 관찰할
// 크기 변화도 없으므로, 구독만 받아 두는 최소 스텁으로 충분하다.
if (!("ResizeObserver" in globalThis)) {
  globalThis.ResizeObserver = class {
    observe() {}
    unobserve() {}
    disconnect() {}
  } as unknown as typeof ResizeObserver;
}
