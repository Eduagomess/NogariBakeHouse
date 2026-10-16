-- NOGARI V31 · PAINEL ÚNICO (PEDIDOS + EDIÇÃO DO SITE)
-- Execute UMA VEZ no SQL Editor do projeto Nogari.
-- Seguro para executar novamente: não apaga pedidos, pessoas, administradores ou cardápio existente.

-- =========================================================
-- 1) CARDÁPIO (mantém compatibilidade com a V30)
-- =========================================================
create table if not exists public.cardapio_itens (
  id uuid primary key default gen_random_uuid(),
  categoria text not null default 'Cookies',
  nome text not null,
  descricao text not null default '',
  preco numeric(10,2) not null default 0 check (preco >= 0),
  ativo boolean not null default true,
  destaque boolean not null default false,
  novidade boolean not null default false,
  ordem integer not null default 0,
  foto_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists cardapio_itens_nome_lower_uidx
  on public.cardapio_itens(lower(nome));
create index if not exists cardapio_itens_ordem_idx
  on public.cardapio_itens(ordem, categoria, nome);

create or replace function public.cardapio_atualizar_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists cardapio_itens_updated_at on public.cardapio_itens;
create trigger cardapio_itens_updated_at
before update on public.cardapio_itens
for each row execute function public.cardapio_atualizar_updated_at();

alter table public.cardapio_itens enable row level security;
revoke all on table public.cardapio_itens from anon;
revoke all on table public.cardapio_itens from authenticated;
grant select on table public.cardapio_itens to anon;
grant select, insert, update, delete on table public.cardapio_itens to authenticated;

drop policy if exists "publico_le_cardapio_ativo" on public.cardapio_itens;
create policy "publico_le_cardapio_ativo"
on public.cardapio_itens for select to anon using (ativo = true);

drop policy if exists "admin_le_cardapio" on public.cardapio_itens;
create policy "admin_le_cardapio"
on public.cardapio_itens for select to authenticated using (public.is_admin());

drop policy if exists "admin_insere_cardapio" on public.cardapio_itens;
create policy "admin_insere_cardapio"
on public.cardapio_itens for insert to authenticated with check (public.is_admin());

drop policy if exists "admin_atualiza_cardapio" on public.cardapio_itens;
create policy "admin_atualiza_cardapio"
on public.cardapio_itens for update to authenticated
using (public.is_admin()) with check (public.is_admin());

drop policy if exists "admin_exclui_cardapio" on public.cardapio_itens;
create policy "admin_exclui_cardapio"
on public.cardapio_itens for delete to authenticated using (public.is_admin());

-- Só cria os sabores iniciais se ainda não existirem.
insert into public.cardapio_itens (categoria,nome,descricao,preco,ativo,destaque,novidade,ordem)
values
  ('Cookies','Nozes','Massa branca com gotas de chocolate nobre ao leite e nozes.',16,true,false,false,1),
  ('Cookies','Meio Amargo','Massa de cacau e gotas de chocolate nobre meio amargo.',14,true,false,false,2),
  ('Cookies','Nutella','Massa branca recheada de Nutella e gotas de chocolate nobre meio amargo.',18,true,false,false,3),
  ('Cookies','Pistachio','Massa branca recheada de creme de pistache e gotas de chocolate nobre branco.',19,true,false,false,4),
  ('Cookies','Pistachio Black','Massa cacau recheada de creme de pistache, gotas de chocolate nobre branco e meio amargo.',19,true,false,false,5),
  ('Cookies','Maltine','Massa cacau recheada de creme de ovomaltine e gotas de chocolate nobre meio amargo.',18,true,false,false,6),
  ('Cookies','Buenissimo','Massa branca recheada de creme de kinder e gotas de chocolate nobre branca e meio amargo.',18,true,true,false,7)
on conflict do nothing;

-- =========================================================
-- 2) CONTEÚDO DO SITE
-- Uma única linha JSON guarda os textos, links e fototeca.
-- Público pode ler; somente ADM pode alterar.
-- =========================================================
create table if not exists public.site_config (
  id text primary key,
  config jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now(),
  updated_by uuid references public.admin_users(user_id) on delete set null
);

create or replace function public.site_config_atualizar_updated_at()
returns trigger
language plpgsql
set search_path = public, auth
as $$
begin
  new.updated_at = now();
  if auth.uid() is not null then
    new.updated_by = auth.uid();
  end if;
  return new;
end;
$$;

drop trigger if exists site_config_updated_at on public.site_config;
create trigger site_config_updated_at
before update on public.site_config
for each row execute function public.site_config_atualizar_updated_at();

alter table public.site_config enable row level security;
revoke all on table public.site_config from anon;
revoke all on table public.site_config from authenticated;
grant select on table public.site_config to anon;
grant select, insert, update on table public.site_config to authenticated;

drop policy if exists "publico_le_site_config" on public.site_config;
create policy "publico_le_site_config"
on public.site_config for select to anon using (id = 'principal');

drop policy if exists "admin_le_site_config" on public.site_config;
create policy "admin_le_site_config"
on public.site_config for select to authenticated using (public.is_admin());

drop policy if exists "admin_insere_site_config" on public.site_config;
create policy "admin_insere_site_config"
on public.site_config for insert to authenticated with check (public.is_admin() and id = 'principal');

drop policy if exists "admin_atualiza_site_config" on public.site_config;
create policy "admin_atualiza_site_config"
on public.site_config for update to authenticated
using (public.is_admin() and id = 'principal')
with check (public.is_admin() and id = 'principal');

insert into public.site_config (id, config)
values (
  'principal',
  $json$
  {
    "home": {
      "tagline": "cookies artesanais, recheados com afeto",
      "footer": "Nogari · Bakehouse"
    },
    "menu": {
      "eyebrow": "Sabores · Assados na hora",
      "title": "Cardápio",
      "comingEnabled": true,
      "comingTag": "Em breve",
      "comingTitle": "Focacias",
      "comingDesc": "Fermentação lenta, azeite italiano e a generosidade da casa."
    },
    "order": {
      "eyebrow": "Pedidos · Canais oficiais",
      "title": "Peça já",
      "intro": "Escolha seu canal preferido para pedir ou falar com a Nogari.",
      "ifoodUrl": "https://www.ifood.com.br/delivery/jundiai-sp/nogari-bakehouse-medeiros/d66d34f0-da93-43a2-9e25-829025dc0ac1?utm_medium=share",
      "ifoodLabel": "Peça no iFood",
      "instagramUrl": "https://www.instagram.com/nogaribakehouse?igsh=MWYzbWozcTIzNGMzcA==",
      "instagramLabel": "Instagram @Nogaribakehouse",
      "email": "contato@nogari.com",
      "hours": "Ter — Sáb · 09h — 19h",
      "badges": ["Manteiga francesa", "Chocolate belga", "Assado na hora"]
    },
    "about": {
      "eyebrow": "A casa · Desde sempre",
      "title": "Sobre nós",
      "body1": "Nogari nasceu de uma cozinha pequena, de um forno teimoso e da obsessão por um único objetivo: o cookie perfeito — aquele que estala por fora e derrete por dentro.",
      "body2": "Massa branca, massa de cacau, recheios cremosos de pistache, nutella, ovomaltine, kinder. Cada sabor é desenhado com manteiga francesa, chocolate belga e o tempo de descanso que cada massa pede. Nada é apressado, nada é industrial.",
      "quote": "\"Feito com a paciência de quem ama o ofício.\"",
      "philosophyLabel": "Nossa filosofia",
      "philosophyText": "Massa, manteiga\ne tempo."
    },
    "gallery": {
      "eyebrow": "Registros · Atelier",
      "title": "Fototeca",
      "soonTag": "Em breve",
      "soonText": "Fotografias reais do atelier",
      "items": [
        {"emoji":"🌾","caption":"Massa em descanso","photo":""},
        {"emoji":"🔥","caption":"Forno · 180°","photo":""},
        {"emoji":"🫑","caption":"Recheio de pistache","photo":""},
        {"emoji":"🍪","caption":"Cookie partido ao meio","photo":""},
        {"emoji":"🧈","caption":"Manteiga & farinha","photo":""},
        {"emoji":"📦","caption":"Caixa pronta","photo":""}
      ]
    }
  }
  $json$::jsonb
)
on conflict (id) do nothing;

-- =========================================================
-- 3) STORAGE PARA FOTOS DO CARDÁPIO E FOTOTECA
-- Público pode visualizar; somente ADM pode enviar/alterar/excluir.
-- =========================================================
insert into storage.buckets (id, name, public, file_size_limit)
values ('site-media', 'site-media', true, 8388608)
on conflict (id) do update
set public = true,
    file_size_limit = excluded.file_size_limit;

drop policy if exists "publico_le_site_media" on storage.objects;
create policy "publico_le_site_media"
on storage.objects for select to public
using (bucket_id = 'site-media');

drop policy if exists "admin_insere_site_media" on storage.objects;
create policy "admin_insere_site_media"
on storage.objects for insert to authenticated
with check (bucket_id = 'site-media' and public.is_admin());

drop policy if exists "admin_atualiza_site_media" on storage.objects;
create policy "admin_atualiza_site_media"
on storage.objects for update to authenticated
using (bucket_id = 'site-media' and public.is_admin())
with check (bucket_id = 'site-media' and public.is_admin());

drop policy if exists "admin_exclui_site_media" on storage.objects;
create policy "admin_exclui_site_media"
on storage.objects for delete to authenticated
using (bucket_id = 'site-media' and public.is_admin());

-- =========================================================
-- 4) REALTIME
-- =========================================================
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'cardapio_itens'
  ) then
    alter publication supabase_realtime add table public.cardapio_itens;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'site_config'
  ) then
    alter publication supabase_realtime add table public.site_config;
  end if;
end $$;

-- FIM V31
