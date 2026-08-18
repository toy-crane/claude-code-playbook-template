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
      ".claude/worktrees/**",
    ],
  },
});
