-- Schema per Divisione Spesa Cena
-- Da eseguire nel SQL Editor di Supabase

-- ============================================================
-- BLOCCO 1: TABELLE, GRANT, RLS, TRIGGER
-- Esegui questo blocco DA SOLO, senza il blocco 2 più sotto.
-- Motivo: se un'istruzione del blocco 2 (storage) fallisce, Postgres
-- annulla l'INTERA transazione inclusa la creazione di queste tabelle,
-- perché uno script multi-istruzione incollato ed eseguito insieme
-- viene trattato come una singola transazione implicita.
-- ============================================================

create table if not exists cene (
  id uuid primary key default gen_random_uuid(),
  nome text not null,
  data date default current_date,
  created_at timestamptz default now()
);

create table if not exists partecipanti (
  id uuid primary key default gen_random_uuid(),
  cena_id uuid references cene(id) on delete cascade,
  nome text not null,
  num_persone integer not null default 1 check (num_persone >= 1),
  created_at timestamptz default now(),
  unique(cena_id, nome)
);

create table if not exists spese (
  id uuid primary key default gen_random_uuid(),
  cena_id uuid references cene(id) on delete cascade,
  partecipante_id uuid references partecipanti(id) on delete cascade,
  descrizione text,
  importo numeric(10,2) not null check (importo >= 0),
  foto_url text,
  updated_by text,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);

-- Necessario perché "Automatically expose new tables" è disattivato:
-- senza questi GRANT, le tabelle esistono ma sono invisibili all'API
-- (PostgREST), anche con RLS configurata correttamente.
grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.cene to anon, authenticated;
grant select, insert, update, delete on public.partecipanti to anon, authenticated;
grant select, insert, update, delete on public.spese to anon, authenticated;

-- Nessuna RLS restrittiva: chiunque abbia il link (cena_id) può leggere/scrivere.
-- Coerente con la scelta "name-based, nessun controllo tecnico di accesso".
alter table cene enable row level security;
alter table partecipanti enable row level security;
alter table spese enable row level security;

create policy "public read cene" on cene for select using (true);
create policy "public insert cene" on cene for insert with check (true);

create policy "public read partecipanti" on partecipanti for select using (true);
create policy "public insert partecipanti" on partecipanti for insert with check (true);
create policy "public update partecipanti" on partecipanti for update using (true);
create policy "public delete partecipanti" on partecipanti for delete using (true);

create policy "public read spese" on spese for select using (true);
create policy "public insert spese" on spese for insert with check (true);
create policy "public update spese" on spese for update using (true);
create policy "public delete spese" on spese for delete using (true);

-- Trigger per aggiornare updated_at automaticamente
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

create trigger spese_updated_at
before update on spese
for each row execute function set_updated_at();

-- Abilita la trasmissione realtime delle modifiche (necessario perché altri
-- dispositivi vedano le modifiche fatte da qualcun altro senza ricaricare la
-- pagina manualmente). Le proprie azioni locali non dipendono da questo,
-- solo la sincronizzazione tra dispositivi diversi.
alter publication supabase_realtime add table cene;
alter publication supabase_realtime add table partecipanti;
alter publication supabase_realtime add table spese;

-- ============================================================
-- BLOCCO 2: STORAGE per le foto degli scontrini
-- Esegui SEPARATAMENTE dal blocco 1, in una query diversa.
-- NOTA: se hai già creato il bucket manualmente da dashboard e le
-- policy risultano già presenti (verificato: 3 policy sul bucket),
-- NON serve eseguire questo blocco di nuovo.
-- ============================================================

-- Se il bucket non esiste ancora, crealo da Dashboard > Storage > New Bucket
-- (nome a tua scelta, es. "scontrini" o "cena-split", pubblico), poi esegui
-- le policy sotto sostituendo 'NOME_BUCKET' con il nome scelto:

-- create policy "public upload NOME_BUCKET"
-- on storage.objects for insert
-- with check (bucket_id = 'NOME_BUCKET');

-- create policy "public read NOME_BUCKET"
-- on storage.objects for select
-- using (bucket_id = 'NOME_BUCKET');

-- create policy "public delete NOME_BUCKET"
-- on storage.objects for delete
-- using (bucket_id = 'NOME_BUCKET');

-- ============================================================
-- Se in futuro rieseguirai questo schema su un progetto con tabelle
-- già esistenti ma senza le colonne più recenti, usa queste righe:
-- alter table partecipanti add column if not exists num_persone integer not null default 1 check (num_persone >= 1);
-- alter table spese add column if not exists foto_url text;
-- ============================================================
