import "@testing-library/jest-dom/vitest";
import { cleanup } from "@testing-library/react";
import { afterEach } from "vitest";

// globals: false 이므로 Testing Library 자동 cleanup이 걸리지 않는다.
afterEach(cleanup);
