// ============================================================
// Grindpoint — bank-utils Edge Function
// ============================================================
// Powers two things on the dashboard withdrawal form:
//   1. A live, always-current bank + mobile-wallet dropdown
//   2. "Type your account number, see your real name pop up"
//      before a withdrawal can be submitted
//
// This MUST run server-side because it needs your Paystack
// secret key, which should never be shipped to the browser.
//
// ---------------- SETUP (one-time) ----------------
// 1. Create a free account at https://dashboard.paystack.com/#/signup
//    (no business verification needed just to use bank resolve —
//    that's only required later if you start moving money through
//    Paystack itself, which is a separate decision).
// 2. Settings → API Keys & Webhooks → copy your SECRET key
//    (starts with sk_live_... or sk_test_... while testing).
// 3. In your Supabase project: Edge Functions → set a secret:
//      supabase secrets set PAYSTACK_SECRET_KEY=sk_live_xxxxxxxx
// 4. Deploy this file:
//      supabase functions deploy bank-utils
// ----------------------------------------------------
//
// Called from the dashboard via the Supabase JS client:
//   await supabase.functions.invoke('bank-utils', { body: { action: 'list_banks' } })
//   await supabase.functions.invoke('bank-utils', { body: { action: 'resolve', account_number, bank_code } })
// ============================================================

import { serve } from "https://deno.land/std@0.168.0/http/server.ts";

const PAYSTACK_SECRET_KEY = Deno.env.get("PAYSTACK_SECRET_KEY");

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
};

serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  if (!PAYSTACK_SECRET_KEY) {
    return new Response(
      JSON.stringify({ error: "PAYSTACK_SECRET_KEY is not configured on the server." }),
      { status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" } }
    );
  }

  try {
    const { action, account_number, bank_code } = await req.json();

    if (action === "list_banks") {
      const res = await fetch("https://api.paystack.co/bank?country=nigeria&currency=NGN&perPage=100", {
        headers: { Authorization: `Bearer ${PAYSTACK_SECRET_KEY}` },
      });
      const json = await res.json();
      if (!json.status) throw new Error(json.message || "Could not fetch bank list.");

      const banks = json.data
        .map((b: any) => ({ name: b.name, code: b.code }))
        .sort((a: any, b: any) => a.name.localeCompare(b.name));

      return new Response(JSON.stringify({ banks }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    if (action === "resolve") {
      if (!account_number || !bank_code) {
        return new Response(JSON.stringify({ error: "account_number and bank_code are required." }), {
          status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      const res = await fetch(
        `https://api.paystack.co/bank/resolve?account_number=${encodeURIComponent(account_number)}&bank_code=${encodeURIComponent(bank_code)}`,
        { headers: { Authorization: `Bearer ${PAYSTACK_SECRET_KEY}` } }
      );
      const json = await res.json();

      if (!json.status) {
        return new Response(JSON.stringify({ error: json.message || "Could not resolve this account. Check the number and bank." }), {
          status: 200, headers: { ...corsHeaders, "Content-Type": "application/json" },
        });
      }

      return new Response(JSON.stringify({ account_name: json.data.account_name }), {
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      });
    }

    return new Response(JSON.stringify({ error: "Unknown action." }), {
      status: 400, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  } catch (err) {
    return new Response(JSON.stringify({ error: err.message || "Unexpected error." }), {
      status: 500, headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  }
});
