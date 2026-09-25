import { fileURLToPath } from "node:url";
import { defineConfig } from "vitest/config";

const src = (file: string) => fileURLToPath(new URL(`./src/${file}`, import.meta.url));

// Each test file starts its own anvil (test/setup/anvil.ts), so files run in parallel safely.
// examples/ imports the package by its name, as a client would; the aliases point it at src/.
export default defineConfig({
  resolve: {
    alias: [
      { find: /^@mintabear\/contracts-client\/backend$/, replacement: src("backend.ts") },
      { find: /^@mintabear\/contracts-client$/, replacement: src("index.ts") },
    ],
  },
  test: {
    include: ["test/**/*.test.ts", "examples/**/*.test.ts"],
    testTimeout: 30_000,
    hookTimeout: 60_000,
  },
});
