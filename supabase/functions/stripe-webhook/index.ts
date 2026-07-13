import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const STRIPE_SECRET_KEY = Deno.env.get("STRIPE_SECRET_KEY_TEST") ??
  Deno.env.get("STRIPE_SECRET_KEY") ?? "";
const STRIPE_WEBHOOK_SECRET = Deno.env.get("STRIPE_WEBHOOK_SECRET_TEST") ??
  Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";

function timingSafeEqual(a: string, b: string): boolean {
  if (a.length !== b.length) return false;

  let result = 0;

  for (let i = 0; i < a.length; i++) {
    result |= a.charCodeAt(i) ^ b.charCodeAt(i);
  }

  return result === 0;
}

async function verifyStripeSignature(
  payload: string,
  sigHeader: string,
  secret: string,
) {
  if (!secret) {
    throw new Error("STRIPE_WEBHOOK_SECRET mancante");
  }

  const parts = sigHeader.split(",");
  const timestamp = parts.find((p) => p.startsWith("t="))?.split("=")[1];
  const signature = parts.find((p) => p.startsWith("v1="))?.split("=")[1];

  if (!timestamp || !signature) {
    throw new Error("Firma non valida");
  }

  const eventTime = parseInt(timestamp, 10);
  const nowSec = Math.floor(Date.now() / 1000);

  if (Math.abs(nowSec - eventTime) > 300) {
    throw new Error("Timestamp webhook troppo vecchio");
  }

  const signedPayload = `${timestamp}.${payload}`;

  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );

  const mac = await crypto.subtle.sign(
    "HMAC",
    key,
    new TextEncoder().encode(signedPayload),
  );

  const expected = Array.from(new Uint8Array(mac))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");

  if (!timingSafeEqual(expected, signature)) {
    throw new Error("Firma non corrispondente");
  }

  return JSON.parse(payload);
}

async function rimborsa(
  supabase: any,
  pi: any,
  userId: string,
  total: number,
  tipo: string,
) {
  await supabase.from("ordini").insert({
    utente_id: userId,
    totale: total,
    stato: "rimborsato",
    tipo_consegna: tipo,
    tracking: "Rimborso automatico: prodotto non piu disponibile",
    data: new Date().toISOString(),
    stripe_payment_intent_id: pi.id,
  });

  if (!STRIPE_SECRET_KEY) {
    console.error("STRIPE_SECRET_KEY mancante: impossibile rimborsare");
    return;
  }

  await fetch("https://api.stripe.com/v1/refunds", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${STRIPE_SECRET_KEY}`,
      "Content-Type": "application/x-www-form-urlencoded",
    },
    body: new URLSearchParams({
      payment_intent: pi.id,
      reason: "requested_by_customer",
    }),
  });

  try {
    const { data: profilo } = await supabase
      .from("profili")
      .select("fcm_token")
      .eq("id", userId)
      .single();

    if (profilo?.fcm_token) {
      await supabase.functions.invoke("send-notification", {
        body: {
          token: profilo.fcm_token,
          title: "Pagamento rimborsato",
          body:
            "Il prodotto non e piu disponibile. Il rimborso arrivera entro 5-10 giorni.",
        },
      });
    }
  } catch (e) {
    console.log("Errore notifica rimborso:", (e instanceof Error ? e.message : String(e)));
  }
}

Deno.serve(async (req) => {
  if (req.method !== "POST") {
    return new Response("Method not allowed", { status: 405 });
  }

  const body = await req.text();
  const sig = req.headers.get("stripe-signature") ?? "";

  try {
    const event = await verifyStripeSignature(body, sig, STRIPE_WEBHOOK_SECRET);

    console.log("Evento Stripe:", event.type);

    if (event.type !== "payment_intent.succeeded") {
      return new Response("OK", { status: 200 });
    }

    const pi = event.data.object;

    const flow = pi.metadata?.flow ?? "";
    const paymentRequestId =
      pi.metadata?.payment_request_id ?? "";

    const userId = pi.metadata?.user_id;
    const righeJson = pi.metadata?.righe;
    const note = pi.metadata?.note ?? "";
    const tipo = pi.metadata?.tipo ?? "spedizione";
    const couponCode = pi.metadata?.coupon_code ?? null;

    const amountCents = Number(
      pi.amount_received ?? pi.amount ?? 0,
    );

    const total = amountCents / 100;

    const currency = String(
      pi.currency ?? "",
    ).toLowerCase();

    if (!SUPABASE_URL || !SERVICE_ROLE_KEY) {
      console.error("Variabili Supabase mancanti");

      return new Response(
        "Server config error",
        { status: 500 },
      );
    }

    const supabase = createClient(
      SUPABASE_URL,
      SERVICE_ROLE_KEY,
    );

    if (flow === "admin_payment_request") {
      console.log(
        "Pagamento richiesta amministrativa ricevuto:",
        {
          paymentRequestId,
          userId,
          paymentIntentId: pi.id,
          amountCents,
          currency,
        },
      );

      const uuidValido =
        /^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
          .test(paymentRequestId);

      if (!uuidValido || !userId) {
        console.error(
          "Metadata richiesta pagamento mancanti o non validi:",
          {
            paymentRequestId,
            userId,
            paymentIntentId: pi.id,
          },
        );

        return new Response(
          "Invalid payment request metadata",
          { status: 500 },
        );
      }

      const {
        data: richiesta,
        error: richiestaError,
      } = await supabase
        .from("richieste_pagamento")
        .select(`
          id,
          utente_id,
          importo_centesimi,
          valuta,
          stato,
          stripe_payment_intent_id
        `)
        .eq("id", paymentRequestId)
        .maybeSingle();

      if (richiestaError) {
        console.error(
          "Errore lettura richiesta pagamento:",
          richiestaError.message,
        );

        return new Response(
          "Payment request database error",
          { status: 500 },
        );
      }

      if (!richiesta) {
        console.error(
          "Richiesta pagamento non trovata:",
          paymentRequestId,
        );

        return new Response(
          "Payment request not found",
          { status: 500 },
        );
      }

      if (
        String(richiesta.utente_id ?? "") !==
          String(userId)
      ) {
        console.error(
          "Utente richiesta pagamento non corrispondente:",
          {
            paymentRequestId,
            metadataUserId: userId,
            databaseUserId: richiesta.utente_id,
          },
        );

        return new Response(
          "Payment request user mismatch",
          { status: 500 },
        );
      }

      const importoRichiesto = Number(
        richiesta.importo_centesimi,
      );

      const valutaRichiesta = String(
        richiesta.valuta ?? "eur",
      ).toLowerCase();

      if (
        !Number.isInteger(amountCents) ||
        amountCents < 1 ||
        amountCents !== importoRichiesto
      ) {
        console.error(
          "Importo richiesta pagamento non corrispondente:",
          {
            paymentRequestId,
            stripeAmountCents: amountCents,
            databaseAmountCents: importoRichiesto,
          },
        );

        return new Response(
          "Payment request amount mismatch",
          { status: 500 },
        );
      }

      if (currency !== valutaRichiesta) {
        console.error(
          "Valuta richiesta pagamento non corrispondente:",
          {
            paymentRequestId,
            stripeCurrency: currency,
            databaseCurrency: valutaRichiesta,
          },
        );

        return new Response(
          "Payment request currency mismatch",
          { status: 500 },
        );
      }

      if (richiesta.stato === "pagato") {
        if (
          richiesta.stripe_payment_intent_id ===
            pi.id
        ) {
          console.log(
            "Richiesta pagamento già processata - skip:",
            paymentRequestId,
          );

          return new Response(
            "OK",
            { status: 200 },
          );
        }

        console.error(
          "Possibile pagamento duplicato su richiesta già pagata:",
          {
            paymentRequestId,
            paymentIntentCorrente: pi.id,
            paymentIntentRegistrato:
              richiesta.stripe_payment_intent_id,
          },
        );

        return new Response(
          "OK",
          { status: 200 },
        );
      }

      if (richiesta.stato === "annullato") {
        console.error(
          "Pagamento ricevuto per richiesta annullata:",
          {
            paymentRequestId,
            paymentIntentId: pi.id,
          },
        );

        return new Response(
          "Payment received for cancelled request",
          { status: 500 },
        );
      }

      if (
        richiesta.stato !== "da_pagare" &&
        richiesta.stato !== "pagamento_in_corso"
      ) {
        console.error(
          "Stato richiesta pagamento non valido:",
          {
            paymentRequestId,
            stato: richiesta.stato,
          },
        );

        return new Response(
          "Invalid payment request status",
          { status: 500 },
        );
      }

      const pagatoAt =
        new Date().toISOString();

      const {
        data: richiestaAggiornata,
        error: updateError,
      } = await supabase
        .from("richieste_pagamento")
        .update({
          stato: "pagato",
          stripe_payment_intent_id: pi.id,
          pagato_at: pagatoAt,
          updated_at: pagatoAt,
        })
        .eq("id", paymentRequestId)
        .eq("utente_id", userId)
        .in(
          "stato",
          [
            "da_pagare",
            "pagamento_in_corso",
          ],
        )
        .select("id, stato")
        .maybeSingle();

      if (updateError) {
        console.error(
          "Errore aggiornamento richiesta pagamento:",
          updateError.message,
        );

        return new Response(
          "Payment request update error",
          { status: 500 },
        );
      }

      if (!richiestaAggiornata) {
        const {
          data: verificaRichiesta,
          error: verificaError,
        } = await supabase
          .from("richieste_pagamento")
          .select(
            "stato, stripe_payment_intent_id",
          )
          .eq("id", paymentRequestId)
          .maybeSingle();

        if (
          !verificaError &&
          verificaRichiesta?.stato === "pagato" &&
          verificaRichiesta
              ?.stripe_payment_intent_id === pi.id
        ) {
          console.log(
            "Richiesta già aggiornata da elaborazione concorrente:",
            paymentRequestId,
          );

          return new Response(
            "OK",
            { status: 200 },
          );
        }

        console.error(
          "Nessuna richiesta aggiornata:",
          {
            paymentRequestId,
            verificaRichiesta,
            verificaError:
              verificaError?.message ?? null,
          },
        );

        return new Response(
          "Payment request not updated",
          { status: 500 },
        );
      }

      console.log(
        "Richiesta pagamento marcata come pagata:",
        {
          paymentRequestId,
          paymentIntentId: pi.id,
          amountCents,
        },
      );

      return new Response(
        "OK",
        { status: 200 },
      );
    }

    if (!userId || !righeJson) {
      console.log("Metadata mancanti");

      return new Response(
        "OK",
        { status: 200 },
      );
    }

    const righe = JSON.parse(righeJson);

    const { data: result, error: rpcError } = await supabase.rpc(
      "conferma_ordine_atomico",
      {
        p_user_id: userId,
        p_righe: righe,
        p_totale: total,
        p_tipo_consegna: tipo,
        p_tracking: note,
        p_stripe_payment_intent_id: pi.id,
        p_coupon_code: couponCode && couponCode !== "" ? couponCode : null,
      },
    );

    if (rpcError) {
      const msg = rpcError.message ?? "";

      console.error("Errore RPC:", msg);

      if (msg.includes("stock_esaurito")) {
        console.log("Stock esaurito - rimborso");
        await rimborsa(supabase, pi, userId, total, tipo);
        return new Response("OK", { status: 200 });
      }

      if (msg.includes("coupon_gia_usato")) {
        console.error(
          "Pagamento riuscito ma coupon gia usato. PI:",
          pi.id,
          "User:",
          userId,
        );

        const { data: retry, error: retryError } = await supabase.rpc(
          "conferma_ordine_atomico",
          {
            p_user_id: userId,
            p_righe: righe,
            p_totale: total,
            p_tipo_consegna: tipo,
            p_tracking: `${note} [coupon non applicato: gia usato]`,
            p_stripe_payment_intent_id: pi.id,
            p_coupon_code: null,
          },
        );

        if (retryError) {
          console.error("Retry senza coupon fallito:", retryError);
          return new Response("Error", { status: 500 });
        }

        if (retry?.status === "created") {
          console.log("Ordine creato senza coupon:", retry.ordine_id);
        }

        return new Response("OK", { status: 200 });
      }

      return new Response("Error", { status: 500 });
    }

    if (result?.status === "already_processed") {
      console.log("Ordine gia processato - skip:", result.ordine_id);
      return new Response("OK", { status: 200 });
    }

    const orderId = result?.ordine_id;

    console.log("Ordine creato:", orderId);

    try {
      const { data: profilo } = await supabase
        .from("profili")
        .select("nome, cognome, telefono")
        .eq("id", userId)
        .single();

      const nomeCliente = `${profilo?.nome ?? ""} ${profilo?.cognome ?? ""}`
        .trim();

      const prodottiList: string[] = [];
      let notificaProdotto = "";

      for (let i = 0; i < righe.length; i++) {
        const riga = righe[i];

        const { data: prod } = await supabase
          .from("prodotti")
          .select("nome")
          .eq("id", riga.prodotto_id)
          .maybeSingle();

        let label = prod?.nome ?? "Prodotto";

        if (riga.variante_id) {
          const { data: v } = await supabase
            .from("varianti_prodotto")
            .select("ram, memoria, colore")
            .eq("id", riga.variante_id)
            .maybeSingle();

          if (v) {
            const varLabel = [v.ram, v.memoria, v.colore]
              .filter(Boolean)
              .join(" ");

            if (varLabel) {
              label += ` (${varLabel})`;
            }
          }
        }

        prodottiList.push(
          `${label} x${riga.quantita} - \u20AC${
            Number(riga.prezzo).toFixed(2)
          }`,
        );

        if (i === 0) {
          notificaProdotto = label;
        }
      }

      const notificaBody = righe.length > 1
        ? `${nomeCliente} ha ordinato ${notificaProdotto} + ${
          righe.length - 1
        } altro/i - \u20AC${total.toFixed(2)}`
        : `${nomeCliente} ha ordinato ${notificaProdotto} - \u20AC${
          total.toFixed(2)
        }`;

      try {
        const { data: admins } = await supabase
          .from("profili")
          .select("fcm_token")
          .eq("ruolo", "admin")
          .not("fcm_token", "is", null);

        if (admins && admins.length > 0) {
          for (const admin of admins) {
            await supabase.functions.invoke("send-notification", {
              body: {
                token: admin.fcm_token,
                title: "Nuovo ordine",
                body: notificaBody,
              },
            });
          }
        }

        console.log("Notifiche admin inviate");
      } catch (e) {
        console.log("Errore notifica admin:", (e instanceof Error ? e.message : String(e)));
      }

      await fetch(`${SUPABASE_URL}/functions/v1/send-order-email`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          "Authorization": `Bearer ${SERVICE_ROLE_KEY}`,
        },
        body: JSON.stringify({
          ordineId: orderId,
          totale: total.toFixed(2),
          tipo,
          prodotti: prodottiList,
          cliente: nomeCliente,
          telefono: profilo?.telefono ?? "",
          indirizzo: note,
        }),
      });

      console.log("Email admin inviata");
    } catch (e) {
      console.log("Errore email/notifiche:", (e instanceof Error ? e.message : String(e)));
    }

    return new Response("OK", { status: 200 });
  } catch (e) {
    console.error("Errore webhook:", (e instanceof Error ? e.message : String(e)));

    return new Response(
      JSON.stringify({ error: (e instanceof Error ? e.message : "errore_webhook") }),
      {
        status: 400,
        headers: { "Content-Type": "application/json" },
      },
    );
  }
});
