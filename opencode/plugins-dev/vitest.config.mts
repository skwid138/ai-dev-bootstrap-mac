import { defineConfig } from "vitest/config";

export default defineConfig({
  esbuild: {
    jsx: "automatic",
    jsxImportSource: "@opentui/solid",
  },
  test: {
    include: ["__tests__/*.test.{ts,tsx}"],
  },
});
