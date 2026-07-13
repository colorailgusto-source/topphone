-- Richieste di pagamento create dal pannello amministratore.
-- Il cliente può soltanto leggere le proprie richieste.
-- Creazione e aggiornamento avvengono tramite Edge Functions con service role.

create table if not exists public.richieste_pagamento (
  id uuid primary key default gen_random_uuid(),

  utente_id uuid null
    references auth.users(id)
    on delete set null,

  email_cliente text not null,
  importo_centesimi bigint not null
    check (importo_centesimi > 0),

  valuta text not null default 'eur'
    check (char_length(valuta) = 3),

  descrizione text not null
    check (
      char_length(trim(descrizione)) >= 1
      and char_length(descrizione) <= 500
    ),

  riferimento text null
    check (
      riferimento is null
      or char_length(riferimento) <= 150
    ),

  stato text not null default 'da_pagare'
    check (
      stato in (
        'da_pagare',
        'pagamento_in_corso',
        'pagato',
        'annullato'
      )
    ),

  metodo_pagamento text not null default 'klarna',

  stripe_checkout_session_id text null,
  stripe_payment_intent_id text null,

  creato_da uuid null
    references auth.users(id)
    on delete set null,

  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  pagato_at timestamptz null,
  annullato_at timestamptz null
);

create index if not exists richieste_pagamento_utente_idx
  on public.richieste_pagamento (utente_id);

create index if not exists richieste_pagamento_email_idx
  on public.richieste_pagamento (lower(trim(email_cliente)));

create index if not exists richieste_pagamento_stato_idx
  on public.richieste_pagamento (stato);

create index if not exists richieste_pagamento_created_at_idx
  on public.richieste_pagamento (created_at desc);

create unique index if not exists richieste_pagamento_checkout_unique
  on public.richieste_pagamento (stripe_checkout_session_id)
  where stripe_checkout_session_id is not null;

create unique index if not exists richieste_pagamento_payment_intent_unique
  on public.richieste_pagamento (stripe_payment_intent_id)
  where stripe_payment_intent_id is not null;


-- Aggiornamento automatico di updated_at.

create or replace function public.set_richieste_pagamento_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists trg_richieste_pagamento_updated_at
  on public.richieste_pagamento;

create trigger trg_richieste_pagamento_updated_at
before update on public.richieste_pagamento
for each row
execute function public.set_richieste_pagamento_updated_at();


-- Collega automaticamente le richieste all'utente quando viene
-- creato o aggiornato un profilo con la stessa email.

create or replace function public.collega_richieste_pagamento_profilo()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.email is not null and trim(new.email) <> '' then
    update public.richieste_pagamento
    set utente_id = new.id
    where utente_id is null
      and lower(trim(email_cliente)) = lower(trim(new.email));
  end if;

  return new;
end;
$$;

drop trigger if exists trg_collega_richieste_pagamento_profilo
  on public.profili;

create trigger trg_collega_richieste_pagamento_profilo
after insert or update of email on public.profili
for each row
execute function public.collega_richieste_pagamento_profilo();


-- Collega anche eventuali richieste già presenti a profili esistenti.

update public.richieste_pagamento as rp
set utente_id = p.id
from public.profili as p
where rp.utente_id is null
  and p.email is not null
  and lower(trim(rp.email_cliente)) = lower(trim(p.email));


-- Verifica amministratore dedicata alle richieste di pagamento.
-- SECURITY DEFINER permette il controllo del profilo senza dipendere
-- dalle policy RLS applicate alla tabella profili.

create or replace function public.richieste_pagamento_is_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profili as p
    where p.id = auth.uid()
      and p.ruolo = 'admin'
  );
$$;

revoke all
on function public.richieste_pagamento_is_admin()
from public;

grant execute
on function public.richieste_pagamento_is_admin()
to authenticated;

-- Sicurezza RLS.

alter table public.richieste_pagamento enable row level security;

drop policy if exists "richieste_pagamento_select_cliente_admin"
  on public.richieste_pagamento;

create policy "richieste_pagamento_select_cliente_admin"
on public.richieste_pagamento
for select
to authenticated
using (
  utente_id = auth.uid()
  or public.richieste_pagamento_is_admin()
);


-- Il client può soltanto leggere.
-- Nessun INSERT, UPDATE o DELETE diretto per utenti autenticati.

revoke all on table public.richieste_pagamento from anon;
revoke all on table public.richieste_pagamento from authenticated;

grant select on table public.richieste_pagamento to authenticated;
grant all on table public.richieste_pagamento to service_role;

comment on table public.richieste_pagamento is
  'Richieste di pagamento create dagli amministratori per clienti fisici';

comment on column public.richieste_pagamento.importo_centesimi is
  'Importo affidabile espresso in centesimi, ad esempio 69900 = 699 euro';