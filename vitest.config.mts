import react from "@vitejs/plugin-react";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [react()],
  // tsconfig.json의 "@/*" 경로 별칭을 Vite가 직접 해석한다.
  resolve: { tsconfigPaths: true },
  test: {
    environment: "jsdom",
    setupFiles: ["./vitest.setup.ts"],
    passWithNoTests: true,
    exclude: [
      "node_modules/**",
      ".next/**",
      "e2e/**",
      // 에이전트 스킬은 skills-lock.json이 관리하는 벤더 복사본이고,
      // .claude/worktrees는 이 앱의 중복 체크아웃이다.
      ".claude/**",
      ".agents/**",
    ],
  },
});
