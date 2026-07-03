import {fileURLToPath} from 'node:url';
import {defineConfig} from 'vitest/config';

export default defineConfig({
  resolve: {
    alias: {
      // Webpack alias provided by Docusaurus at build time — stubbed in tests.
      '@theme-original/Mermaid': fileURLToPath(
        new URL('./tests/stubs/theme-original-mermaid.jsx', import.meta.url),
      ),
    },
  },
  test: {
    environment: 'jsdom',
    include: ['src/**/*.test.{js,jsx}'],
    setupFiles: ['./tests/setup.js'],
  },
});
