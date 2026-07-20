/**
 * Grindpoint — supabase-config.js v5
 * Bulletproof: hard timeout fallback, clear error states, no silent failures
 */

const SUPABASE_URL      = "https://hfbquuhbfjfeiosktdhl.supabase.co";
const SUPABASE_ANON_KEY = "sb_publishable_Mp7LjPCYeTStuHs45xjifQ_vc3B1dMQ";

let _sb = null;

// ── Always reveal body after 5s max (failsafe — page never stays blank) ──
window.addEventListener("load", () => {
  setTimeout(() => {
    if (document.body.style.visibility === "hidden") {
      document.body.style.visibility = "";
      console.warn("[GP] Body reveal timeout fired — auth check took too long or failed silently.");
    }
  }, 5000);
});

function getSupabase() {
  if (_sb) return _sb;

  // The @supabase/supabase-js UMD bundle attaches to window.supabase
  const lib = window.supabase;

  if (!lib || typeof lib.createClient !== "function") {
    console.error("[GP] window.supabase.createClient not found. SDK not loaded.");
    return null;
  }

  try {
    _sb = lib.createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      auth: {
        persistSession:     true,
        autoRefreshToken:   true,
        detectSessionInUrl: true,
        storageKey:         "gp_session",
      }
    });
    return _sb;
  } catch (e) {
    console.error("[GP] createClient error:", e.message);
    return null;
  }
}

async function getSession() {
  const sb = getSupabase();
  if (!sb) return null;
  try {
    const { data, error } = await sb.auth.getSession();
    if (error) { console.error("[GP] getSession error:", error.message); return null; }
    return data.session || null;
  } catch (e) {
    console.error("[GP] getSession threw:", e.message);
    return null;
  }
}

async function getProfile(uid) {
  const sb = getSupabase();
  if (!sb || !uid) return null;
  try {
    const { data } = await sb.from("profiles").select("*").eq("id", uid).maybeSingle();
    return data || null;
  } catch (e) {
    console.warn("[GP] getProfile error:", e.message);
    return null;
  }
}

// ── For user-facing protected pages ─────────────────────────────────────────
async function requireAuth(redirect = "login") {
  try {
    const session = await getSession();
    if (!session) {
      window.location.replace(redirect);
      return null;
    }
    const profile = await getProfile(session.user.id);

    /* Block banned users — show message and sign them out */
    if (profile?.status === "banned") {
      document.body.style.visibility = "";
      document.body.innerHTML = `
        <div style="min-height:100vh;display:flex;align-items:center;justify-content:center;background:var(--bg-base,#0f1117);padding:2rem;">
          <div style="max-width:440px;text-align:center;background:var(--bg-card,#1a1d27);border:1px solid rgba(239,68,68,.3);border-radius:16px;padding:2.5rem;">
            <div style="font-size:3rem;margin-bottom:1rem;">🚫</div>
            <h2 style="color:#ef4444;margin-bottom:.75rem;">Account Suspended</h2>
            <p style="color:#94a3b8;line-height:1.7;margin-bottom:1.5rem;">
              Your Grindpoint account has been suspended due to a violation of our Terms of Service.
              If you believe this is a mistake, please contact us on WhatsApp.
            </p>
            <a href="https://wa.me/2349034192652" style="display:inline-block;background:#25D366;color:#fff;padding:.75rem 1.5rem;border-radius:8px;text-decoration:none;font-weight:700;margin-bottom:1rem;">Contact Support</a>
            <br/>
            <a href="login" style="font-size:.82rem;color:#64748b;">Sign in with a different account</a>
          </div>
        </div>`;
      await getSupabase().auth.signOut();
      return null;
    }

    /* Show warning banner to warned users — still let them access the platform */
    if (profile?.status === "warned" && profile?.warn_reason) {
      const banner = document.createElement("div");
      banner.style.cssText = "position:fixed;top:0;left:0;right:0;z-index:9999;background:rgba(245,158,11,.97);color:#000;padding:.85rem 1.25rem;display:flex;align-items:center;gap:1rem;font-size:.875rem;font-weight:600;box-shadow:0 2px 12px rgba(0,0,0,.3);";
      banner.innerHTML = `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2.5" style="width:20px;height:20px;flex-shrink:0;"><path d="M10.29 3.86L1.82 18a2 2 0 001.71 3h16.94a2 2 0 001.71-3L13.71 3.86a2 2 0 00-3.42 0z"/><line x1="12" y1="9" x2="12" y2="13"/><line x1="12" y1="17" x2="12.01" y2="17"/></svg><span>Account Warning: ${profile.warn_reason}. Further violations may result in a permanent ban.</span><button onclick="this.parentElement.remove()" style="margin-left:auto;background:rgba(0,0,0,.1);border:none;border-radius:6px;padding:.25rem .6rem;font-size:1rem;cursor:pointer;color:#000;font-weight:800;">×</button>`;
      document.body.prepend(banner);
      document.body.style.paddingTop = "56px";
    }

    document.body.style.visibility = "";
    return { session, user: session.user, profile };
  } catch (e) {
    console.error("[GP] requireAuth error:", e.message);
    document.body.style.visibility = "";
    window.location.replace(redirect);
    return null;
  }
}

// ── For admin pages ──────────────────────────────────────────────────────────
async function requireAdmin() {
  try {
    const session = await getSession();

    if (!session) {
      document.body.style.visibility = "";
      window.location.replace("../login.html");
      return null;
    }

    const profile = await getProfile(session.user.id);

    if (!profile || profile.role !== "admin") {
      document.body.style.visibility = "";
      document.body.innerHTML = `
        <div style="display:flex;align-items:center;justify-content:center;min-height:100vh;
          flex-direction:column;gap:1.25rem;font-family:'DM Sans',sans-serif;
          background:#0b0c0e;color:#f4f4f5;text-align:center;padding:2rem;">
          <div style="font-size:3rem;">🔒</div>
          <h2 style="font-family:Syne,sans-serif;font-size:1.5rem;">Admin Access Only</h2>
          <p style="color:#71717a;max-width:340px;line-height:1.6;">
            Your account does not have admin privileges.
            ${profile ? `Your current role is <strong style="color:#f59e0b;">${profile.role}</strong>.` : "No profile found."}
          </p>
          <p style="color:#71717a;font-size:0.85rem;max-width:380px;">
            To get admin access, run this in your Supabase SQL Editor:<br>
            <code style="background:#1c2028;padding:4px 8px;border-radius:4px;margin-top:6px;display:inline-block;color:#f59e0b;">
              UPDATE profiles SET role = 'admin' WHERE email = '${session.user.email}';
            </code>
          </p>
          <a href="../login.html" style="color:#f59e0b;font-size:.9rem;">← Sign in with a different account</a>
          <a href="debug.html" style="color:#71717a;font-size:.8rem;">Run diagnostics →</a>
        </div>`;
      return null;
    }

    document.body.style.visibility = "";
    return { session, user: session.user, profile };

  } catch (e) {
    console.error("[GP] requireAdmin error:", e.message);
    document.body.style.visibility = "";
    document.body.innerHTML = `
      <div style="display:flex;align-items:center;justify-content:center;min-height:100vh;
        flex-direction:column;gap:1rem;font-family:sans-serif;background:#0b0c0e;color:#f4f4f5;padding:2rem;text-align:center;">
        <div style="font-size:2.5rem;">⚠️</div>
        <h2>Auth Error</h2>
        <p style="color:#71717a;max-width:400px;">${e.message}</p>
        <p style="color:#71717a;font-size:.85rem;">Open browser DevTools → Console for details.</p>
        <a href="debug.html" style="color:#f59e0b;">Run diagnostics →</a>
        <a href="../login.html" style="color:#71717a;font-size:.85rem;">← Back to Login</a>
      </div>`;
    return null;
  }
}

// ── Sign out ─────────────────────────────────────────────────────────────────
async function signOut() {
  const sb = getSupabase();
  if (sb) { try { await sb.auth.signOut(); } catch (e) {} }
  const isAdmin = window.location.pathname.includes("/admin/");
  window.location.replace(isAdmin ? "../login.html" : "login");
}

// ── Currency helper ───────────────────────────────────────────────────────────
function formatNaira(n) {
  return "₦" + (parseFloat(n) || 0).toLocaleString("en-NG", {
    minimumFractionDigits: 2,
    maximumFractionDigits: 2
  });
}

// ── Backward-compat alias ─────────────────────────────────────────────────
// Some pages still call getCurrentUserAndProfile() — keep it working
async function getCurrentUserAndProfile() {
  const session = await getSession();
  if (!session) return { session: null, user: null, profile: null };
  const profile = await getProfile(session.user.id);
  return { session, user: session.user, profile };
}
