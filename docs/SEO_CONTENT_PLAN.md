# GLPill — SEO & Content Plan

> Built from Ahrefs Free Keyword Generator (US, 2026-07-17). Volumes are the free-tool
> buckets (>100 / >1,000 / >10,000 / >100K). Framing: **educational, cited, not medical advice.**
> Domain `glpillapp.com` is clean (no Wayback history). Goal: rank to drive iOS installs.

## The core insight
YMYL health head terms are owned by Healthline / Drugs.com / GoodRx / Novo Nordisk — unwinnable for a new site. **But `orforglipron` (the Foundayo drug) is a new, exploding, under-saturated topic with EASY-KD terms at high volume.** That is GLPill's wedge: own the oral-GLP-1 *practical/how-to/tracking* space, lead with orforglipron.

## Keyword research (US)

| Seed | Ideas | Read |
|---|---|---|
| **orforglipron** | **2,500** | price >10k **Easy**, brand name >10k, side effects >1k, pill >1k, weight loss/fda approval >100, vs tirzepatide **Easy**, vs zepbound, "fda approval status 2026". → **PRIMARY — winnable + growing** |
| rybelsus | 10,181 | head >100K but **Hard**; winnable *Medium* long-tails: cost, coupon, for weight loss, dosing/food/how-to |
| glp1 pill | 387 | head >10k Hard; long-tails uncontested: best glp1 pill, **glp1 pill vs injection**, cheapest, cost without insurance |

## Content clusters (pillar + spokes)

### Pillar 1 — Orforglipron / Foundayo  ⭐ PRIMARY (winnable, high growth)
Target: orforglipron price, side effects, how to take, dosing, weight loss results, FDA approval status 2026, orforglipron vs tirzepatide / vs zepbound / vs Ozempic / vs Rybelsus, is orforglipron approved, where to buy.
- Existing: `foundayo-orforglipron-guide`, `orforglipron-side-effects` → upgrade + expand into a linked cluster.
- New (priority): "Orforglipron price & cost", "Orforglipron vs tirzepatide", "How to take orforglipron", "Orforglipron FDA approval status (2026)", "Orforglipron weight-loss results".

### Pillar 2 — Rybelsus (practical how-to long-tails only)
Target: how to take Rybelsus (empty stomach, 30-min wait), Rybelsus cost/coupon, food timing, dosing schedule 3/7/14 mg, side effects first week.
- Existing: `how-to-take-rybelsus` → upgrade with citations + FAQ. New: "Rybelsus cost & coupons", "Rybelsus food & timing rules".

### Pillar 3 — Oral GLP-1 category
Target: glp1 pill vs injection, best oral GLP-1, cheapest glp1 pill, cost without insurance, muscle loss, protein.
- Existing: `glp1-pill-vs-injection`, `glp1-and-muscle-loss`, `protein-on-glp1` → upgrade.

### Conversion pages — the app (low comp, high intent)
Target: app to track oral GLP-1 / Rybelsus reminder / orforglipron tracker.
- Existing: `track-glp1-pill-routine`, `rybelsus-tracker.html`, `foundayo-tracker.html` → make these the app-CTA landing pages.

## Per-article upgrade checklist (the YMYL gaps we found)
Every article (7 existing + new) must add:
- [ ] **Citations** to authoritative sources (FDA label, ClinicalTrials.gov, NIH/PubMed, manufacturer PI) — currently **0 across all 7**.
- [ ] **FAQ section + `FAQPage` JSON-LD** — currently none.
- [ ] **`MedicalWebPage`/`Article` schema** with `author`, `reviewedBy`/`about`, `datePublished` + `dateModified`.
- [ ] **Medical disclaimer** ("informational, not medical advice; consult your clinician").
- [ ] **Internal links** to the app + related articles; clear App-Store CTA.
- [ ] Depth: expand thin sections; answer the People-Also-Ask questions.

## Astro rebuild plan
1. Scaffold Astro in `site/` (or `web/`) + Tailwind; keep the Vercel serverless `api/waitlist.js`.
2. **Layout.astro** — one shared head (title/description/canonical/OG/Twitter/GA `G-3WKYBWQRFP`/theme), nav, footer, disclaimer.
3. **Blog content collection** (Markdown) — auto `Article`+`FAQPage` schema, auto sitemap, related-posts, breadcrumbs.
4. Migrate landing + privacy + tracker pages; migrate the 7 articles into the collection and apply the upgrade checklist.
5. Author/About page + Organization schema (E-E-A-T).
6. Reuse the factory **QA gate** (`../microtool-factory/qa`) for responsive + functional checks.
7. Deploy to the existing Vercel project; keep `glpillapp.com`.
8. Search Console: already has GA; submit the new sitemap, request indexing on the orforglipron cluster first.

## Sequence
Keyword research ✅ → Astro foundation + Layout → migrate & upgrade 7 articles → write orforglipron-cluster new articles → deploy → index.
