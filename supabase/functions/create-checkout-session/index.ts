import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY_TEST") ??
  Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const STRIPE_PUBLISHABLE_KEY = Deno.env.get("STRIPE_PUBLISHABLE_KEY_TEST") ??
  Deno.env.get("STRIPE_PUBLISHABLE_KEY") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const WEB_SUCCESS_URL =
  "https://topphoneweb.vercel.app/#/order-success?stripe=1";
const WEB_CANCEL_URL = "https://topphoneweb.vercel.app/#/cart";

const SCALAPAY_SUCCESS_URL =
  "https://colorailgusto-source.github.io/topphone-privacy/scalapay-success.html";
const SCALAPAY_CANCEL_URL =
  "https://colorailgusto-source.github.io/topphone-privacy/scalapay-cancel.html";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json", ...corsHeaders },
  });
}

type RigaVerificata = {
  prodotto_id: string;
  variante_id: string | null;
  quantita: number;
  prezzo: number;
  variante_label: string;
};

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, { status: 204, headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get("Authorization") ?? "";
    const token = authHeader.replace(/^Bearer\s+/i, "").trim();

    if (!token) {
      return jsonResponse({ error: "non_autenticato" }, 401);
    }

    const authClient = createClient(SUPABASE_URL, ANON_KEY, {
      global: { headers: { Authorization: `Bearer ${token}` } },
    });

    const { data: userData, error: authError } = await authClient.auth.getUser(
      token,
    );

    if (authError || !userData?.user) {
      return jsonResponse({ error: "jwt_non_valido" }, 401);
    }

    const userId = userData.user.id;
    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY);

    const body = await req.json();

    const {
      righeJson,
      note,
      tipo,
      couponCode,
      metodoPagamento,
    } = body;

    // IMPORTANTE:
    // Solo se Flutter Web manda esattamente "web" usiamo Stripe Checkout URL.
    // Da APK/app Android, se manca platform o arriva un valore diverso, trattiamo come "app".
    const platform = body.platform === "web" ? "web" : "app";

    console.log("Checkout request:", {
      userId,
      metodoPagamento,
      platform,
      tipo,
    });

    if (!righeJson) {
      return jsonResponse({ error: "righe_mancanti" }, 400);
    }

    if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !ANON_KEY) {
      return jsonResponse({ error: "config_supabase_mancante" }, 500);
    }

    if (!STRIPE_SECRET_KEY) {
      return jsonResponse({ error: "stripe_secret_key_mancante" }, 500);
    }

    const righeInput = JSON.parse(righeJson);

    const { data: appConfig } = await supabase
      .from("app_config")
      .select(
        "klarna_attivo, klarna_markup, scalapay_attivo, scalapay_markup, costo_spedizione",
      )
      .eq("id", "config")
      .maybeSingle();

    const costoSpedizione = Number(appConfig?.costo_spedizione ?? 10);

    const rateLimitKey = `checkout_${userId}`;
    const maxRequests = 10;
    const windowMs = 5 * 60 * 1000;
    const nowMs = Date.now();

    const { data: rateData } = await supabase
      .from("rate_limits")
      .select("requests, window_start")
      .eq("id", rateLimitKey)
      .maybeSingle();

    let windowExpired = true;

    if (rateData?.window_start) {
      const windowStartMs = new Date(rateData.window_start).getTime();
      windowExpired = nowMs - windowStartMs > windowMs;
    }

    if (rateData && !windowExpired && rateData.requests >= maxRequests) {
      return jsonResponse({
        error: "Troppe richieste. Riprova tra qualche minuto.",
      }, 429);
    }

    if (!rateData || windowExpired) {
      await supabase.from("rate_limits").upsert({
        id: rateLimitKey,
        requests: 1,
        window_start: new Date(nowMs).toISOString(),
      });
    } else {
      await supabase
        .from("rate_limits")
        .update({ requests: Number(rateData.requests ?? 0) + 1 })
        .eq("id", rateLimitKey);
    }

    const { data: carts } = await supabase
      .from("carrelli")
      .select("id")
      .eq("utente_id", userId)
      .gt("scadenza", new Date().toISOString());

    const cartExists = carts && carts.length > 0;

    const righeVerificate: RigaVerificata[] = [];

    for (const riga of righeInput) {
      let prezzoBase = 0;
      let stockDisponibile = 0;
      let prodottoId = riga.prodotto_id;
      let varianteLabel = "";

      if (riga.variante_id) {
        const { data: v } = await supabase
          .from("varianti_prodotto")
          .select("stock, prezzo_extra, prodotto_id, ram, memoria, colore")
          .eq("id", riga.variante_id)
          .single();

        if (!v) {
          return jsonResponse({ error: "stock_esaurito" }, 400);
        }

        stockDisponibile = Number(v.stock ?? 0);
        prodottoId = v.prodotto_id;

        varianteLabel = [v.ram, v.memoria, v.colore]
          .filter(Boolean)
          .join(" ")
          .trim();

        const { data: p } = await supabase
          .from("prodotti")
          .select("prezzo")
          .eq("id", v.prodotto_id)
          .single();

        prezzoBase = Number(p?.prezzo ?? 0) + Number(v.prezzo_extra ?? 0);
      } else {
        const { data: p } = await supabase
          .from("prodotti")
          .select("prezzo, stock")
          .eq("id", riga.prodotto_id)
          .single();

        if (!p) {
          return jsonResponse({ error: "stock_esaurito" }, 400);
        }

        stockDisponibile = Number(p.stock ?? 0);
        prezzoBase = Number(p.prezzo ?? 0);
      }

      const quantita = Number(riga.quantita ?? 0);

      if (quantita <= 0) {
        return jsonResponse({ error: "quantita_non_valida" }, 400);
      }

      if (!cartExists && stockDisponibile < quantita) {
        return jsonResponse({ error: "stock_esaurito" }, 400);
      }

      righeVerificate.push({
        prodotto_id: prodottoId,
        variante_id: riga.variante_id ?? null,
        quantita,
        prezzo: Number(prezzoBase.toFixed(2)),
        variante_label: varianteLabel || riga.variante_label || "",
      });
    }

    let metodoFinale = "card";
    let markupFactor = 1;

    if (metodoPagamento === "klarna" && appConfig?.klarna_attivo) {
      const markup = Number(appConfig.klarna_markup ?? 6);
      markupFactor = 1 + markup / 100;
      metodoFinale = "klarna";
    } else if (metodoPagamento === "scalapay" && appConfig?.scalapay_attivo) {
      const markup = Number(appConfig.scalapay_markup ?? 6);
      markupFactor = 1 + markup / 100;
      metodoFinale = "scalapay";
    }

    if (markupFactor !== 1) {
      for (const riga of righeVerificate) {
        riga.prezzo = Number((riga.prezzo * markupFactor).toFixed(2));
      }
    }

    let subtotaleProdotti = righeVerificate.reduce((sum, riga) => {
      return sum + Number(riga.prezzo) * Number(riga.quantita);
    }, 0);

    subtotaleProdotti = Number(subtotaleProdotti.toFixed(2));

    let subtotale = subtotaleProdotti;

    if (tipo === "spedizione") {
      subtotale += costoSpedizione;
    }

    subtotale = Number(subtotale.toFixed(2));

    let scontoReale = 0;

    if (couponCode) {
      const nowIso = new Date().toISOString();

      const { data: coupon } = await supabase
        .from("coupon")
        .select("valore")
        .eq("codice", couponCode)
        .eq("utente_id", userId)
        .eq("usato", false)
        .gt("scadenza", nowIso)
        .maybeSingle();

      if (coupon) {
        scontoReale = Number(coupon.valore ?? 0);
      }
    }

    const totaleFinale = Number(
      Math.max(0, subtotale - scontoReale).toFixed(2),
    );

    const righeJsonVerificato = JSON.stringify(righeVerificate);

    // WEB:
    // Klarna web usa Checkout Session e torna al sito.
    //
    // APP:
    // Klarna app NON usa Checkout Session, usa PaymentIntent e deve tornare all'app.
    //
    // SCALAPAY:
    // Resta su Checkout Session/pagina esterna.
    const useCheckoutSession =
      metodoFinale === "scalapay" ||
      (metodoFinale === "klarna" && platform === "web");

    console.log("Checkout mode:", {
      metodoFinale,
      platform,
      useCheckoutSession,
      totaleFinale,
    });

    if (useCheckoutSession) {
      const isScalapay = metodoFinale === "scalapay";
      const successUrl = isScalapay ? SCALAPAY_SUCCESS_URL : WEB_SUCCESS_URL;
      const cancelUrl = isScalapay ? SCALAPAY_CANCEL_URL : WEB_CANCEL_URL;
      const paymentMethod = metodoFinale === "scalapay" ? "scalapay" : "klarna";

      const csBody = new URLSearchParams({
        "mode": "payment",
        "success_url": successUrl,
        "cancel_url": cancelUrl,
        "expires_at": (Math.floor(Date.now() / 1000) + 1800).toString(),
        "payment_method_types[]": paymentMethod,
        "line_items[0][price_data][currency]": "eur",
        "line_items[0][price_data][product_data][name]":
          "Ordine Top Phone Torre",
        "line_items[0][price_data][unit_amount]": Math.round(
          totaleFinale * 100,
        ).toString(),
        "line_items[0][quantity]": "1",
        "payment_intent_data[metadata][user_id]": userId,
        "payment_intent_data[metadata][righe]": righeJsonVerificato,
        "payment_intent_data[metadata][note]": note ?? "",
        "payment_intent_data[metadata][tipo]": tipo ?? "spedizione",
        "payment_intent_data[metadata][coupon_code]": couponCode ?? "",
        "payment_intent_data[metadata][metodo_pagamento]": metodoFinale,
      });

      const csResponse = await fetch(
        "https://api.stripe.com/v1/checkout/sessions",
        {
          method: "POST",
          headers: {
            "Authorization": `Bearer ${STRIPE_SECRET_KEY}`,
            "Content-Type": "application/x-www-form-urlencoded",
          },
          body: csBody.toString(),
        },
      );

      const cs = await csResponse.json();

      if (cs.error) {
        console.error("Errore Checkout Session:", cs.error);
        return jsonResponse({ error: cs.error.message }, 400);
      }

      return jsonResponse({ checkoutUrl: cs.url });
    }

    const piBody = new URLSearchParams({
      "amount": Math.round(totaleFinale * 100).toString(),
      "currency": "eur",
      "payment_method_types[]": metodoFinale,
      "metadata[user_id]": userId,
      "metadata[righe]": righeJsonVerificato,
      "metadata[note]": note ?? "",
      "metadata[tipo]": tipo ?? "spedizione",
      "metadata[coupon_code]": couponCode ?? "",
      "metadata[metodo_pagamento]": metodoFinale,
    });

    const piResponse = await fetch("https://api.stripe.com/v1/payment_intents", {
      method: "POST",
      headers: {
        "Authorization": `Bearer ${STRIPE_SECRET_KEY}`,
        "Content-Type": "application/x-www-form-urlencoded",
      },
      body: piBody.toString(),
    });

    const pi = await piResponse.json();

    if (pi.error) {
      console.error("Errore PaymentIntent:", pi.error);
      return jsonResponse({ error: pi.error.message }, 400);
    }

    return jsonResponse({
      paymentIntentClientSecret: pi.client_secret,
      publishableKey: STRIPE_PUBLISHABLE_KEY,
    });
  } catch (e) {
    console.error("Errore:", e?.message ?? e);
    return jsonResponse({ error: e?.message ?? "errore_server" }, 500);
  }
});