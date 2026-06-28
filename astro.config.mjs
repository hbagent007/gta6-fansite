// @ts-check
import { defineConfig } from 'astro/config';
import tailwindcss from '@tailwindcss/vite';

// https://astro.build/config
export default defineConfig({
  site: 'https://hubgta6.com',
  server: {
    allowedHosts: ['.loca.lt', '.trycloudflare.com'],
  },
  vite: {
    plugins: [tailwindcss()],
  },
});
