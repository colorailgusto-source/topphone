-- Correzione della visibilità delle richieste di pagamento.
--
-- 1. Collega automaticamente una richiesta al profilo con la stessa email.
-- 2. Collega retroattivamente le richieste già presenti.
-- 3. Consente al cliente autenticato di leggere anche tramite l'email JWT.
-- 4. Il client mantiene esclusivamente il permesso SELECT.

create or replace function
public.collega_richiesta_pagamento_da_email()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  if new.utente_id is null
     and new.email_cliente is not null
     and btrim(new.email_cliente) <> '' then

    select p.id
    into new.utente_id
    from public.profili as p
    where p.email is not null
      and lower(btrim(p.email)) =
          lower(btrim(new.email_cliente))
    limit 1;
  end if;

  return new;
end;
$$;

drop trigger if exists
trg_collega_richiesta_pagamento_da_email
on public.richieste_pagamento;

create trigger
trg_collega_richiesta_pagamento_da_email
before insert or update
on public.richieste_pagamento
for each row
execute function
public.collega_richiesta_pagamento_da_email();


-- Collega le richieste esistenti ai profili già registrati.

update public.richieste_pagamento as rp
set utente_id = p.id
from public.profili as p
where rp.utente_id is null
  and p.email is not null
  and lower(btrim(rp.email_cliente)) =
      lower(btrim(p.email));


-- La policy permette:
-- - lettura tramite utente_id;
-- - lettura tramite email dell'utente autenticato;
-- - lettura amministratore.

drop policy if exists
"richieste_pagamento_select_cliente_admin"
on public.richieste_pagamento;

create policy
"richieste_pagamento_select_cliente_admin"
on public.richieste_pagamento
for select
to authenticated
using (
  utente_id = auth.uid()

  or (
    email_cliente is not null
    and lower(btrim(email_cliente)) =
        lower(
          btrim(
            coalesce(auth.jwt() ->> 'email', '')
          )
        )
  )

  or public.richieste_pagamento_is_admin()
);


-- Il client può leggere, ma non scrivere.

revoke all
on table public.richieste_pagamento
from anon;

revoke all
on table public.richieste_pagamento
from authenticated;

grant select
on table public.richieste_pagamento
to authenticated;