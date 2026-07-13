import "jsr:@supabase/functions-js/edge-runtime.d.ts";
import { createClient } from "jsr:@supabase/supabase-js@2";

const SUPABASE_URL = Deno.env.get("SUPABASE_URL") ?? "";
const SERVICE_ROLE_KEY =
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const ANON_KEY = Deno.env.get("SUPABASE_ANON_KEY") ?? "";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

function jsonResponse(body: unknown, status = 200) {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function parseImportoCentesimi(
  body: Record<string, unknown>,
): number {
  if (body.importo_centesimi !== undefined) {
    return Math.round(Number(body.importo_centesimi));
  }

  const raw = String(body.importo ?? "")
    .trim()
    .replace(",", ".");

  const euro = Number(raw);

  if (!Number.isFinite(euro)) {
    return 0;
  }

  return Math.round(euro * 100);
}

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") {
    return new Response(null, {
      status: 204,
      headers: corsHeaders,
    });
  }

  if (req.method !== "POST") {
    return jsonResponse(
      { error: "metodo_non_consentito" },
      405,
    );
  }

  try {
    if (!SUPABASE_URL || !SERVICE_ROLE_KEY || !ANON_KEY) {
      console.error("Configurazione Supabase mancante");

      return jsonResponse(
        { error: "configurazione_server_mancante" },
        500,
      );
    }

    const authHeader =
      req.headers.get("Authorization") ?? "";

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

    const { data: userData, error: userError } =
      await authClient.auth.getUser(token);

    const user = userData?.user;

    if (userError || !user) {
      return jsonResponse(
        { error: "jwt_non_valido" },
        401,
      );
    }

    const adminClient = createClient(
      SUPABASE_URL,
      SERVICE_ROLE_KEY,
    );

    const {
      data: profiloAdmin,
      error: profiloAdminError,
    } = await adminClient
      .from("profili")
      .select("ruolo")
      .eq("id", user.id)
      .maybeSingle();

    if (
      profiloAdminError ||
      profiloAdmin?.ruolo !== "admin"
    ) {
      return jsonResponse(
        { error: "non_autorizzato" },
        403,
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

    const email = String(body.email ?? "")
      .trim()
      .toLowerCase();

    const descrizione =
      String(body.descrizione ?? "").trim();

    const riferimentoRaw =
      String(body.riferimento ?? "").trim();

    const riferimento =
      riferimentoRaw.length > 0
        ? riferimentoRaw
        : null;

    const importoCentesimi =
      parseImportoCentesimi(body);

    if (!isValidEmail(email)) {
      return jsonResponse(
        { error: "email_non_valida" },
        400,
      );
    }

    if (
      !Number.isInteger(importoCentesimi) ||
      importoCentesimi < 50
    ) {
      return jsonResponse(
        {
          error: "importo_non_valido",
          message: "L'importo minimo è 0,50 euro.",
        },
        400,
      );
    }

    if (importoCentesimi > 100000000) {
      return jsonResponse(
        {
          error: "importo_troppo_alto",
          message:
            "L'importo massimo consentito è 1.000.000 euro.",
        },
        400,
      );
    }

    if (
      descrizione.length < 1 ||
      descrizione.length > 500
    ) {
      return jsonResponse(
        { error: "descrizione_non_valida" },
        400,
      );
    }

    if (
      riferimento !== null &&
      riferimento.length > 150
    ) {
      return jsonResponse(
        { error: "riferimento_troppo_lungo" },
        400,
      );
    }

    const {
      data: profiliCliente,
      error: clienteError,
    } = await adminClient
      .from("profili")
      .select("id, email")
      .eq("email", email)
      .limit(1);

    if (clienteError) {
      console.error(
        "Errore ricerca cliente:",
        clienteError.message,
      );

      return jsonResponse(
        { error: "errore_ricerca_cliente" },
        500,
      );
    }

    const cliente =
      profiliCliente && profiliCliente.length > 0
        ? profiliCliente[0]
        : null;

    const {
      data: richiesta,
      error: insertError,
    } = await adminClient
      .from("richieste_pagamento")
      .insert({
        utente_id: cliente?.id ?? null,
        email_cliente: email,
        importo_centesimi: importoCentesimi,
        valuta: "eur",
        descrizione,
        riferimento,
        stato: "da_pagare",
        metodo_pagamento: "klarna",
        creato_da: user.id,
      })
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
        created_at
      `)
      .single();

    if (insertError || !richiesta) {
      console.error(
        "Errore inserimento richiesta:",
        insertError?.message ?? "risultato mancante",
      );

      return jsonResponse(
        { error: "errore_creazione_richiesta" },
        500,
      );
    }

    console.log("Richiesta pagamento creata:", {
      richiestaId: richiesta.id,
      clienteRegistrato: cliente !== null,
      importoCentesimi,
    });

    return jsonResponse({
      success: true,
      cliente_registrato: cliente !== null,
      richiesta,
    });
  } catch (error) {
    console.error(
      "Errore admin-create-payment-request:",
      error instanceof Error
        ? error.message
        : error,
    );

    return jsonResponse(
      { error: "errore_interno" },
      500,
    );
  }
});