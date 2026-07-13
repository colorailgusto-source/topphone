import { serve } from "https://deno.land/std@0.177.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

serve(async (req) => {
  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!
  );

  // Verifica admin
  const authHeader = req.headers.get("Authorization")!;
  const token = authHeader.replace("Bearer ", "");
  const { data: { user } } = await supabase.auth.getUser(token);

  if (!user) {
    return new Response(JSON.stringify({ error: "Non autenticato" }), { status: 401 });
  }

  const { data: profilo } = await supabase
    .from("profili")
    .select("ruolo")
    .eq("id", user.id)
    .single();

  if (profilo?.ruolo !== "admin") {
    return new Response(JSON.stringify({ error: "Non autorizzato" }), { status: 403 });
  }

  const { richiesta_id, nuova_variante_id } = await req.json();

  // Prendi la richiesta pendente
  const { data: richiesta, error: errRichiesta } = await supabase
    .from("richieste_cambio")
    .select("*, righe_ordine(*)")
    .eq("id", richiesta_id)
    .eq("stato", "in_attesa")
    .single();

  if (!richiesta || errRichiesta) {
    return new Response(
      JSON.stringify({ error: "Richiesta non trovata o già gestita" }),
      { status: 404 }
    );
  }

  // Verifica stock nuova variante
  const { data: nuovaVariante } = await supabase
    .from("varianti_prodotto")
    .select("id, colore, memoria, ram, stock")
    .eq("id", nuova_variante_id)
    .single();

  if (!nuovaVariante || nuovaVariante.stock < 1) {
    return new Response(
      JSON.stringify({ error: "Variante non disponibile" }),
      { status: 400 }
    );
  }

  // STOCK SWAP
  // Vecchia variante: +1
  if (richiesta.vecchia_variante_id) {
    await supabase.rpc("incrementa_stock", {
      p_variante_id: richiesta.vecchia_variante_id,
      p_quantita: 1,
    });
  }

  // Nuova variante: -1
  const { error: errStock } = await supabase.rpc("decrementa_stock", {
    p_variante_id: nuova_variante_id,
    p_quantita: 1,
  });

  if (errStock) {
    // Rollback vecchia variante
    if (richiesta.vecchia_variante_id) {
      await supabase.rpc("decrementa_stock", {
        p_variante_id: richiesta.vecchia_variante_id,
        p_quantita: 1,
      });
    }
    return new Response(
      JSON.stringify({ error: "Stock insufficiente" }),
      { status: 400 }
    );
  }

  // Aggiorna riga_ordine con nuova variante
  const label = [nuovaVariante.colore, nuovaVariante.memoria, nuovaVariante.ram]
    .filter(Boolean)
    .join(" - ");

  await supabase
    .from("righe_ordine")
    .update({
      variante_id: nuova_variante_id,
      variante_label: label,
    })
    .eq("id", richiesta.riga_ordine_id);

  // Marca richiesta come approvata
  await supabase
    .from("richieste_cambio")
    .update({
      stato: "approvata",
      nuova_variante_id: nuova_variante_id,
      risolta_at: new Date().toISOString(),
      risolta_da: user.id,
    })
    .eq("id", richiesta_id);

  // Messaggio sistema nella chat
  await supabase.from("messaggi_ordine").insert({
    ordine_id: richiesta.ordine_id,
    tipo_mittente: "admin",
    mittente_id: user.id,
    messaggio: `✅ Cambio approvato: ${label}`,
    tipo_messaggio: "cambio_confermato",
  });

  // Push al cliente
  const { data: ordine } = await supabase
    .from("ordini")
    .select("utente_id")
    .eq("id", richiesta.ordine_id)
    .single();

  if (ordine) {
    const { data: profCliente } = await supabase
      .from("profili")
      .select("fcm_token")
      .eq("id", ordine.utente_id)
      .single();

    if (profCliente?.fcm_token) {
      await fetch("https://fcm.googleapis.com/fcm/send", {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Authorization: `key=${Deno.env.get("FCM_SERVER_KEY")}`,
        },
        body: JSON.stringify({
          to: profCliente.fcm_token,
          notification: {
            title: "Modifica ordine confermata",
            body: `Variante cambiata: ${label}`,
          },
        }),
      });
    }
  }

  return new Response(JSON.stringify({ success: true }), { status: 200 });
});