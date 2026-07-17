import { defineCollection, z } from 'astro:content';
import { glob } from 'astro/loaders';

// Blog = the GLP-1 guides. Frontmatter is typed so every article renders
// consistent Article + FAQPage schema, dates, author, and internal links.
const blog = defineCollection({
  loader: glob({ pattern: '**/*.md', base: './src/content/blog' }),
  schema: z.object({
    title: z.string(),
    description: z.string(),
    // Content pillar for internal linking / grouping.
    pillar: z.enum(['orforglipron', 'rybelsus', 'oral-glp1', 'app']).default('oral-glp1'),
    datePublished: z.string(),
    dateModified: z.string().optional(),
    author: z.string().default('Ayush Gupta'),
    keywords: z.array(z.string()).default([]),
    // Rendered as a visible FAQ AND emitted as FAQPage JSON-LD.
    faqs: z.array(z.object({ q: z.string(), a: z.string() })).default([]),
    // Authoritative sources (FDA label, ClinicalTrials.gov, NIH) — required for YMYL trust.
    sources: z.array(z.object({ label: z.string(), url: z.string().url() })).default([]),
    draft: z.boolean().default(false),
  }),
});

export const collections = { blog };
