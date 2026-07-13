import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY_TEST") ??
  Deno.env.get("STRIPE_SECRET_KEY") ??
  "";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";

const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const WEB_SUCCESS_URL =
  "https://topphoneweb.vercel.app/#/orders?payment_request=success";

const WEB_CANCEL_URL =
  "https://topphoneweb.vercel.app/#/orders?payment_request=cancel";

const APP_SUCCESS_URL =
  "https://topphoneweb.vercel.app/payment-request-success.html";

const APP_CANCEL_URL =
  "https://topphoneweb.vercel.app/payment-request-cancel.html";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(
  body: unknown,
  status = 200,
): Response {
  return new Response(
    JSON.stringify(body),
    {
      status,
      headers: {
        ...corsHeaders,
        "Content-Type": "application/json",
      },
    },
  );
}

function isUuid(value: string): boolean {
  return /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
    .test(value);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(
      null,
      {
        status: 204,
        headers: corsHeaders,
      },
    );
  }

  if (req.method !== "POST") {
    return jsonResponse(
      { error: "metodo_non_consentito" },
      405,
    );
  }

  try {
    if (
      !SUPABASE_URL ||
      !SERVICE_ROLE_KEY ||
      !ANON_KEY
    ) {
      console.error(
        "Configurazione Supabase mancante",
      );

      return jsonResponse(
        { error: "configurazione_supabase_mancante" },
        500,
      );
    }

    if (!STRIPE_SECRET_KEY) {
      console.error(
        "Configurazione Stripe mancante",
      );

      return jsonResponse(
        { error: "stripe_secret_key_mancante" },
        500,
      );
    }

    const authHeader = req.headers.get("Authorization") ?? "";

    const token = authHeader
      .replace(/^Bearer\s+/i, "")
      .trim();

    if (!token) {
      return jsonResponse(
        { error: "non_autenticato" },
        401,
      );
    }

    const authClient = createClient(
      SUPABASE_URL,
      ANON_KEY,
      {
        global: {
          headers: {
            Authorization: `Bearer ${token}`,
          },
        },
      },
    );

    const {
      data: userData,
      error: authError,
    } = await authClient.auth.getUser(token);

    const user = userData?.user;

    if (authError || !user) {
      return jsonResponse(
        { error: "jwt_non_valido" },
        401,
      );
    }

    let body: Record<string, unknown>;

    try {
      body = await req.json();
    } catch {
      return jsonResponse(
        { error: "json_non_valido" },
        400,
      );
    }

    const richiestaId = String(
      body.richiesta_id ??
        body.payment_request_id ??
        "",
    ).trim();

    const clientPlatform = String(
      body.client_platform ?? "web",
    ).trim().toLowerCase();

    if (
      clientPlatform !== "web" &&
      clientPlatform !== "app"
    ) {
      return jsonResponse(
        { error: "client_platform_non_valido" },
        400,
      );
    }

    const successUrl = clientPlatform === "app"
      ? APP_SUCCESS_URL
      : WEB_SUCCESS_URL;

    const cancelUrl = clientPlatform === "app"
      ? APP_CANCEL_URL
      : WEB_CANCEL_URL;

    if (!isUuid(richiestaId)) {
      return jsonResponse(
        { error: "richiesta_id_non_valido" },
        400,
      );
    }

    const supabase = createClient(
      SUPABASE_URL,
      SERVICE_ROLE_KEY,
    );

    const {
      data: richiesta,
      error: richiestaError,
    } = await supabase
      .from("richieste_pagamento")
      .select(`
        id,
        utente_id,
        email_cliente,
        importo_centesimi,
        valuta,
        descrizione,
        riferimento,
        stato,
        metodo_pagamento,
        stripe_checkout_session_id
      `)
      .eq("id", richiestaId)
      .maybeSingle();

    if (richiestaError) {
      console.error(
        "Errore lettura richiesta:",
        richiestaError.message,
      );

      return jsonResponse(
        { error: "errore_lettura_richiesta" },
        500,
      );
    }

    if (!richiesta) {
      return jsonResponse(
        { error: "richiesta_non_trovata" },
        404,
      );
    }

    const userId = user.id;

    const authEmail = String(user.email ?? "")
      .trim()
      .toLowerCase();

    const richiestaEmail = String(richiesta.email_cliente ?? "")
      .trim()
      .toLowerCase();

    const richiestaUserId = richiesta.utente_id?.toString() ?? "";

    const appartieneUtente = richiestaUserId === userId;

    const collegabilePerEmail = richiestaUserId.length === 0 &&
      authEmail.length > 0 &&
      authEmail === richiestaEmail;

    if (
      !appartieneUtente &&
      !collegabilePerEmail
    ) {
      return jsonResponse(
        { error: "richiesta_non_autorizzata" },
        403,
      );
    }

    const stato = String(richiesta.stato ?? "");

    if (stato === "pagato") {
      return jsonResponse(
        {
          error: "richiesta_gia_pagata",
          message: "Questa richiesta risulta già pagata.",
        },
        409,
      );
    }

    if (stato === "annullato") {
      return jsonResponse(
        {
          error: "richiesta_annullata",
          message: "Questa richiesta è stata annullata.",
        },
        409,
      );
    }

    if (
      stato !== "da_pagare" &&
      stato !== "pagamento_in_corso"
    ) {
      return jsonResponse(
        { error: "stato_richiesta_non_valido" },
        409,
      );
    }

    const importoCentesimi = Number(richiesta.importo_centesimi);

    if (
      !Number.isInteger(importoCentesimi) ||
      importoCentesimi < 50
    ) {
      console.error(
        "Importo richiesta non valido:",
        richiestaId,
        importoCentesimi,
      );

      return jsonResponse(
        { error: "importo_richiesta_non_valido" },
        500,
      );
    }

    const valuta = String(richiesta.valuta ?? "eur")
      .trim()
      .toLowerCase();

    if (valuta !== "eur") {
      return jsonResponse(
        { error: "valuta_non_supportata" },
        400,
      );
    }

    const {
      data: appConfig,
      error: appConfigError,
    } = await supabase
      .from("app_config")
      .select("klarna_attivo")
      .eq("id", "config")
      .maybeSingle();

    if (appConfigError) {
      console.error(
        "Errore configurazione Klarna:",
        appConfigError.message,
      );

      return jsonResponse(
        { error: "errore_configurazione_klarna" },
        500,
      );
    }

    if (appConfig?.klarna_attivo === false) {
      return jsonResponse(
        {
          error: "klarna_non_disponibile",
          message: "Klarna non è attualmente disponibile.",
        },
        400,
      );
    }

    if (collegabilePerEmail) {
      const {
        error: collegamentoError,
      } = await supabase
        .from("richieste_pagamento")
        .update({
          utente_id: userId,
        })
        .eq("id", richiestaId)
        .is("utente_id", null);

      if (collegamentoError) {
        console.error(
          "Errore collegamento richiesta:",
          collegamentoError.message,
        );

        return jsonResponse(
          { error: "errore_collegamento_richiesta" },
          500,
        );
      }
    }

    const existingCheckoutSessionId = String(
      richiesta.stripe_checkout_session_id ?? "",
    ).trim();

    let idempotencyKey =
      `payment-request-${richiestaId}-initial-${clientPlatform}`;

    if (existingCheckoutSessionId.length > 0) {
      idempotencyKey =
        `payment-request-${richiestaId}-after-${existingCheckoutSessionId}-${clientPlatform}`;

      const existingSessionResponse = await fetch(
        `https://api.stripe.com/v1/checkout/sessions/${
          encodeURIComponent(existingCheckoutSessionId)
        }`,
        {
          method: "GET",
          headers: {
            "Authorization": `Bearer ${STRIPE_SECRET_KEY}`,
          },
        },
      );

      const existingSessionData = await existingSessionResponse.json();

      if (
        existingSessionResponse.ok &&
        !existingSessionData?.error
      ) {
        const existingStatus = String(
          existingSessionData?.status ?? "",
        );

        const existingPaymentStatus = String(
          existingSessionData?.payment_status ?? "",
        );

        const existingUrl = String(
          existingSessionData?.url ?? "",
        );

        const existingFlow = String(
          existingSessionData?.metadata?.flow ?? "",
        );

        const existingRequestId = String(
          existingSessionData?.metadata
            ?.payment_request_id ?? "",
        );

        const existingUserId = String(
          existingSessionData?.metadata?.user_id ?? "",
        );

        const existingClientPlatform = String(
          existingSessionData?.metadata
            ?.client_platform ?? "web",
        ).trim().toLowerCase();

        const existingAmount = Number(
          existingSessionData?.amount_total,
        );

        const existingCurrency = String(
          existingSessionData?.currency ?? "",
        ).toLowerCase();

        const existingSessionMatchesRequest =
          existingFlow === "admin_payment_request" &&
          existingRequestId === richiestaId &&
          existingUserId === userId &&
          existingAmount === importoCentesimi &&
          existingCurrency === valuta;

        if (!existingSessionMatchesRequest) {
          console.error(
            "Sessione Stripe esistente non coerente con la richiesta:",
            {
              richiestaId,
              existingCheckoutSessionId,
              existingFlow,
              existingRequestId,
              existingUserId,
              existingAmount,
              existingCurrency,
            },
          );

          return jsonResponse(
            {
              error: "sessione_esistente_non_coerente",
              message:
                "La sessione di pagamento esistente non corrisponde alla richiesta.",
            },
            409,
          );
        }

        let resolvedExistingStatus = existingStatus;

        if (
          existingStatus === "open" &&
          existingClientPlatform !== clientPlatform
        ) {
          const expireResponse = await fetch(
            `https://api.stripe.com/v1/checkout/sessions/${
              encodeURIComponent(existingCheckoutSessionId)
            }/expire`,
            {
              method: "POST",
              headers: {
                "Authorization": `Bearer ${STRIPE_SECRET_KEY}`,
              },
            },
          );

          const expireData = await expireResponse.json();

          if (
            !expireResponse.ok ||
            expireData?.error
          ) {
            console.error(
              "Errore scadenza sessione per cambio piattaforma:",
              expireData?.error ?? expireData,
            );

            return jsonResponse(
              {
                error: "errore_cambio_piattaforma_checkout",
                message:
                  "Impossibile preparare il pagamento per questa piattaforma.",
              },
              502,
            );
          }

          resolvedExistingStatus = "expired";

          console.log(
            "Sessione precedente scaduta per cambio piattaforma:",
            {
              richiestaId,
              existingCheckoutSessionId,
              existingClientPlatform,
              clientPlatform,
            },
          );
        }

        if (
          resolvedExistingStatus === "open" &&
          existingUrl.length > 0
        ) {
          console.log(
            "Riutilizzo sessione Checkout già aperta:",
            {
              richiestaId,
              existingCheckoutSessionId,
              clientPlatform,
            },
          );

          return jsonResponse({
            success: true,
            checkoutUrl: existingUrl,
            checkoutSessionId: existingCheckoutSessionId,
            reused: true,
          });
        }

        if (
          resolvedExistingStatus === "complete" ||
          existingPaymentStatus === "paid"
        ) {
          return jsonResponse(
            {
              error: "pagamento_in_elaborazione",
              message:
                "Il pagamento risulta già completato o in elaborazione. Aggiorna la pagina tra poco.",
            },
            409,
          );
        }

        if (resolvedExistingStatus !== "expired") {
          console.error(
            "Stato sessione Stripe non gestibile:",
            {
              richiestaId,
              existingCheckoutSessionId,
              existingStatus,
              existingPaymentStatus,
            },
          );

          return jsonResponse(
            {
              error: "sessione_esistente_non_riutilizzabile",
              message:
                "La sessione di pagamento esistente non può essere riutilizzata.",
            },
            409,
          );
        }

        console.log(
          "Sessione precedente scaduta, nuovo tentativo consentito:",
          {
            richiestaId,
            existingCheckoutSessionId,
          },
        );
      } else {
        const stripeErrorCode = String(
          existingSessionData?.error?.code ?? "",
        );

        const sessionNotFound = existingSessionResponse.status === 404 ||
          stripeErrorCode === "resource_missing";

        if (!sessionNotFound) {
          console.error(
            "Errore recupero sessione Stripe esistente:",
            {
              richiestaId,
              existingCheckoutSessionId,
              status: existingSessionResponse.status,
              stripeError: existingSessionData?.error ??
                existingSessionData,
            },
          );

          return jsonResponse(
            {
              error: "errore_verifica_sessione_esistente",
              message:
                "Impossibile verificare la sessione di pagamento esistente.",
            },
            502,
          );
        }

        console.warn(
          "Sessione Stripe registrata non trovata, nuovo tentativo consentito:",
          {
            richiestaId,
            existingCheckoutSessionId,
          },
        );
      }
    }

    const descrizione = String(richiesta.descrizione ?? "")
      .trim()
      .slice(0, 500);

    const riferimento = String(richiesta.riferimento ?? "")
      .trim()
      .slice(0, 150);

    const nomeProdotto = riferimento.length > 0
      ? `Pagamento Top Phone - ${riferimento}`
      : "Pagamento Top Phone Torre";

    const csBody = new URLSearchParams({
      "mode": "payment",
      "success_url": successUrl,
      "cancel_url": cancelUrl,
      "expires_at": (
        Math.floor(Date.now() / 1000) + 1800
      ).toString(),
      "payment_method_types[]": "klarna",
      "customer_email": richiestaEmail,
      "locale": "it",
      "line_items[0][price_data][currency]": valuta,
      "line_items[0][price_data][product_data][name]": nomeProdotto,
      "line_items[0][price_data][product_data][description]": descrizione,
      "line_items[0][price_data][unit_amount]": importoCentesimi.toString(),
      "line_items[0][quantity]": "1",

      "metadata[flow]": "admin_payment_request",
      "metadata[payment_request_id]": richiestaId,
      "metadata[user_id]": userId,
      "metadata[client_platform]": clientPlatform,

      "payment_intent_data[metadata][flow]": "admin_payment_request",
      "payment_intent_data[metadata][payment_request_id]": richiestaId,
      "payment_intent_data[metadata][user_id]": userId,
      "payment_intent_data[metadata][client_platform]": clientPlatform,
      "payment_intent_data[metadata][metodo_pagamento]": "klarna",
    });

    const stripeResponse = await fetch(
      "https://api.stripe.com/v1/checkout/sessions",
      {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${STRIPE_SECRET_KEY}`,
          "Content-Type": "application/x-www-form-urlencoded",
          "Idempotency-Key": idempotencyKey,
        },
        body: csBody.toString(),
      },
    );

    const stripeData = await stripeResponse.json();

    if (
      !stripeResponse.ok ||
      stripeData?.error
    ) {
      console.error(
        "Errore Stripe Checkout:",
        stripeData?.error ??
          stripeData,
      );

      return jsonResponse(
        {
          error: "errore_checkout_stripe",
          message: stripeData?.error?.message ??
            "Impossibile avviare il pagamento Klarna.",
        },
        400,
      );
    }

    const checkoutUrl = String(stripeData?.url ?? "");

    const checkoutSessionId = String(stripeData?.id ?? "");

    if (
      !checkoutUrl ||
      !checkoutSessionId
    ) {
      console.error(
        "Risposta Stripe incompleta:",
        stripeData,
      );

      return jsonResponse(
        { error: "risposta_stripe_incompleta" },
        500,
      );
    }

    const {
      error: updateError,
    } = await supabase
      .from("richieste_pagamento")
      .update({
        utente_id: userId,
        stripe_checkout_session_id: checkoutSessionId,
        metodo_pagamento: "klarna",
        stato: "pagamento_in_corso",
      })
      .eq("id", richiestaId)
      .neq("stato", "pagato")
      .neq("stato", "annullato");

    if (updateError) {
      console.error(
        "Sessione creata ma aggiornamento DB fallito:",
        updateError.message,
      );
    }

    console.log(
      "Checkout richiesta pagamento creato:",
      {
        richiestaId,
        userId,
        checkoutSessionId,
        importoCentesimi,
      },
    );

    return jsonResponse({
      success: true,
      checkoutUrl,
      checkoutSessionId,
    });
  } catch (error) {
    console.error(
      "Errore create-payment-request-checkout:",
      error instanceof Error ? error.message : error,
    );

    return jsonResponse(
      { error: "errore_interno" },
      500,
    );
  }
});
