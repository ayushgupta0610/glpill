# Waitlist — how it works & the one step left for you

The landing form at glpillapp.com POSTs to `/api/waitlist` (a Vercel serverless function, `site/api/waitlist.js`). Secrets live in Vercel env vars, never in the browser. It writes to **two** places for resilience:

1. **Supabase** `glpill_waitlist` table (service-role insert, dedupes on email).
2. **Resend** email to you (`WAITLIST_NOTIFY_TO`) as a reliable fallback.

## What's already done (overnight)
- Function written and deployed.
- Vercel env vars set on the `glpill` project: `SUPABASE_URL`, `SUPABASE_SERVICE_ROLE_KEY`, `RESEND_API_KEY`, `WAITLIST_NOTIFY_TO` (your Gmail). Values reused from the sports-booking `.env.local` as you authorized.
- Form wired with real submit + success state.

## The one step left (2 min, your call on which DB)
I deliberately did **not** run schema changes against the live sports-booking database unsupervised (it has real payment/booking data). Create the table wherever you want the emails to land — running it in the sports-booking project is safe (it's a brand-new isolated table, `CREATE TABLE` touches nothing existing), or spin up a dedicated GLPill Supabase project and repoint `SUPABASE_URL` + `SUPABASE_SERVICE_ROLE_KEY`.

Paste this in the Supabase SQL editor:

```sql
create table if not exists public.glpill_waitlist (
  id uuid primary key default gen_random_uuid(),
  email text not null unique,
  source text default 'landing',
  created_at timestamptz not null default now()
);
-- Server writes with the service role (bypasses RLS). Keep RLS on, no anon policy needed.
alter table public.glpill_waitlist enable row level security;
```

The moment this table exists, signups start landing in it automatically — no code change. Until then, every signup still reaches your inbox via Resend, so nothing is lost.

## Export the list later
Supabase → Table editor → `glpill_waitlist` → Export CSV. Or SQL: `select email from glpill_waitlist order by created_at;`

## Note on the Resend sender
Uses `onboarding@resend.dev` (Resend's zero-config sender), which reliably delivers to the Resend account owner's email. If waitlist notifications don't arrive, it means the Resend account's owner email isn't your Gmail — in that case just create the Supabase table above and the DB becomes the source of truth.
