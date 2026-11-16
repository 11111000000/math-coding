import { fileURLToPath } from "node:url";
import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

const pluginRoot = fileURLToPath(new URL("../plugin/math-coding-console", import.meta.url));

export default defineConfig({
  plugins: [react()],
  resolve: {
    alias: {
      // The shared interface is written against React Native primitives.
      // In the browser they are provided by react-native-web.
      "react-native": "react-native-web",
    },
    // The shared interface lives in the plugin package and resolves React
    // from its own node_modules. Without deduplication the browser bundle
    // would contain two React copies and the shared hooks would break.
    // The data layer belongs to the same list: two copies of it mean two
    // query contexts, and the page asks for a provider it cannot see.
    dedupe: ["react", "react-dom", "react-native-web", "@tanstack/react-query"],
  },
  server: {
    host: "127.0.0.1",
    port: 5173,
    strictPort: false,
    fs: {
      allow: [pluginRoot, fileURLToPath(new URL(".", import.meta.url))],
    },
  },
  build: {
    outDir: "dist",
    emptyOutDir: true,
  },
});
