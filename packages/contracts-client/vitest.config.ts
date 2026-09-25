import { defineConfig } from "vitest/config";

// Each test file starts its own anvil (test/setup/anvil.ts), so files run in parallel safely.
export default defineConfig({
  test: {
    include: ["test/**/*.test.ts"],
    testTimeout: 30_000,
    hookTimeout: 60_000,
  },
});
