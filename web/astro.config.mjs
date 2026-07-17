// @ts-check
import { defineConfig } from 'astro/config';

import tailwindcss from '@tailwindcss/vite';
import sitemap from '@astrojs/sitemap';

// https://astro.build/config
export default defineConfig({
  site: 'https://glpillapp.com',
  vite: {
    plugins: [tailwindcss()],
  },
  integrations: [
    sitemap({
      // Static app-intent pages kept from the old site (not Astro-generated) — keep them in the sitemap.
      customPages: [
        'https://glpillapp.com/foundayo-tracker.html',
        'https://glpillapp.com/rybelsus-tracker.html',
      ],
    }),
  ],
});
