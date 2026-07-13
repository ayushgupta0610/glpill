// Vercel serverless function — GLPill waitlist capture.
// Runs server-side: secrets never reach the browser.
// Dual-sink for resilience:
//   1) Inserts into Supabase `glpill_waitlist` via the service-role key
//      (works the moment the table exists — see docs/WAITLIST.md).
//   2) Sends a Resend notification to the founder as a reliable fallback.
// Returns 200 if at least one sink succeeds.

const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export default async function handler(req, res) {
  // CORS (same-origin in practice, but harmless and future-proof)
  res.setHeader("Access-Control-Allow-Origin", "*");
  res.setHeader("Access-Control-Allow-Methods", "POST, OPTIONS");
  res.setHeader("Access-Control-Allow-Headers", "Content-Type");
  if (req.method === "OPTIONS") return res.status(204).end();
  if (req.method !== "POST") return res.status(405).json({ error: "Method not allowed" });

  let body = req.body;
  if (typeof body === "string") {
    try { body = JSON.parse(body); } catch { body = {}; }
  }
  const email = (body?.email || "").trim().toLowerCase();
  const source = (body?.source || "landing").slice(0, 40);

  if (!EMAIL_RE.test(email) || email.length > 254) {
    return res.status(400).json({ error: "Please enter a valid email address." });
  }

  const results = { supabase: false, email: false };

  // 1) Supabase insert (service role bypasses RLS)
  const SB_URL = process.env.SUPABASE_URL;
  const SB_KEY = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (SB_URL && SB_KEY) {
    try {
      const r = await fetch(`${SB_URL}/rest/v1/glpill_waitlist`, {
        method: "POST",
        headers: {
          apikey: SB_KEY,
          Authorization: `Bearer ${SB_KEY}`,
          "Content-Type": "application/json",
          Prefer: "resolution=ignore-duplicates,return=minimal",
        },
        body: JSON.stringify({ email, source }),
      });
      // 2xx = inserted or duplicate-ignored; 404/42P01 = table missing (fine, fallback covers it)
      results.supabase = r.ok;
    } catch { /* fall through to email */ }
  }

  // 2) Resend founder notification (zero-config sender, delivers to account owner)
  const RESEND_KEY = process.env.RESEND_API_KEY;
  const NOTIFY_TO = process.env.WAITLIST_NOTIFY_TO;
  if (RESEND_KEY && NOTIFY_TO) {
    try {
      const r = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          Authorization: `Bearer ${RESEND_KEY}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: "GLPill Waitlist <onboarding@resend.dev>",
          to: [NOTIFY_TO],
          subject: `New GLPill waitlist signup: ${email}`,
          text: `${email} joined the GLPill waitlist (source: ${source}).`,
        }),
      });
      results.email = r.ok;
    } catch { /* ignore */ }
  }

  if (results.supabase || results.email) {
    return res.status(200).json({ ok: true });
  }
  // Both sinks failed — surface a soft error so the UI can fall back to the IG CTA.
  return res.status(502).json({ error: "Could not save right now — please follow @glpillapp instead." });
}
