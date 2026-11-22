-- JARL Barbearia — schema do MVP (multi-barbearia)
-- Rodar uma vez no SQL Editor do Supabase (ou via migration).

create extension if not exists pgcrypto;

-- Barbearias (cada cliente da FLK! vira uma linha aqui)
create table public.barbearias (
  id uuid primary key default gen_random_uuid(),
  slug text not null unique,
  nome text not null,
  abre time not null default '09:00',
  fecha time not null default '19:00',
  dias_fechados int[] not null default '{0}', -- 0 = domingo
  created_at timestamptz not null default now()
);

-- Quem pode ver o painel de cada barbearia
create table public.membros (
  barbearia_id uuid not null references public.barbearias(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  papel text not null default 'barbeiro' check (papel in ('dono','barbeiro')),
  primary key (barbearia_id, user_id)
);

create table public.barbeiros (
  id uuid primary key default gen_random_uuid(),
  barbearia_id uuid not null references public.barbearias(id) on delete cascade,
  nome text not null,
  especialidade text,
  cor text not null default '#7a3b22',
  ativo boolean not null default true,
  ordem int not null default 0
);

create table public.servicos (
  id uuid primary key default gen_random_uuid(),
  barbearia_id uuid not null references public.barbearias(id) on delete cascade,
  nome text not null,
  descricao text,
  duracao_min int not null check (duracao_min between 5 and 240),
  preco numeric(10,2) not null check (preco >= 0),
  ativo boolean not null default true,
  ordem int not null default 0
);

create table public.reservas (
  id uuid primary key default gen_random_uuid(),
  barbearia_id uuid not null references public.barbearias(id) on delete cascade,
  barbeiro_id uuid not null references public.barbeiros(id),
  servico_id uuid not null references public.servicos(id),
  data date not null,
  hora time not null,
  cliente_nome text not null check (char_length(cliente_nome) between 2 and 80),
  cliente_whatsapp text not null check (cliente_whatsapp ~ '^[0-9]{10,13}$'),
  status text not null default 'confirmada' check (status in ('confirmada','atendida','cancelada')),
  created_at timestamptz not null default now()
);

-- Um barbeiro não pode ter duas reservas ativas no mesmo horário
create unique index reservas_slot_unico on public.reservas (barbeiro_id, data, hora) where status <> 'cancelada';
create index reservas_dia on public.reservas (barbearia_id, data);
create index barbeiros_barbearia on public.barbeiros (barbearia_id);
create index servicos_barbearia on public.servicos (barbearia_id);
create index membros_user on public.membros (user_id);

-- Helper: o usuário logado é membro desta barbearia?
create or replace function public.is_membro(b uuid) returns boolean
language sql stable security definer set search_path = public as $$
  select exists (select 1 from public.membros where barbearia_id = b and user_id = (select auth.uid()));
$$;

alter table public.barbearias enable row level security;
alter table public.membros    enable row level security;
alter table public.barbeiros  enable row level security;
alter table public.servicos   enable row level security;
alter table public.reservas   enable row level security;

-- Vitrine pública: qualquer um lê barbearia, barbeiros e serviços ativos
create policy "barbearias publicas" on public.barbearias for select using (true);
create policy "barbeiros ativos"   on public.barbeiros  for select using (ativo or public.is_membro(barbearia_id));
create policy "servicos ativos"    on public.servicos   for select using (ativo or public.is_membro(barbearia_id));

-- Membros veem a própria vinculação
create policy "meus vinculos" on public.membros for select using (user_id = (select auth.uid()));

-- Reservas: só membros da barbearia leem e atualizam (nome e WhatsApp nunca ficam públicos)
create policy "membro le reservas"      on public.reservas for select to authenticated using (public.is_membro(barbearia_id));
create policy "membro atualiza reservas" on public.reservas for update to authenticated using (public.is_membro(barbearia_id)) with check (public.is_membro(barbearia_id));

-- Horários ocupados de um barbeiro num dia (só a hora, sem dados do cliente)
create or replace function public.horarios_ocupados(p_barbeiro uuid, p_data date)
returns table (hora time)
language sql stable security definer set search_path = public as $$
  select r.hora from public.reservas r
  where r.barbeiro_id = p_barbeiro and r.data = p_data and r.status <> 'cancelada';
$$;

-- Criar reserva pelo site (cliente anônimo). Valida tudo no servidor.
create or replace function public.criar_reserva(
  p_barbeiro uuid, p_servico uuid, p_data date, p_hora time, p_nome text, p_whatsapp text
) returns uuid
language plpgsql security definer set search_path = public as $$
declare
  v_barb uuid; v_serv_barb uuid; v_id uuid; v_b public.barbearias;
  v_zap text := regexp_replace(coalesce(p_whatsapp,''), '\D', '', 'g');
begin
  select barbearia_id into v_barb from public.barbeiros where id = p_barbeiro and ativo;
  select barbearia_id into v_serv_barb from public.servicos where id = p_servico and ativo;
  if v_barb is null or v_serv_barb is null or v_barb <> v_serv_barb then
    raise exception 'Barbeiro ou serviço inválido';
  end if;
  select * into v_b from public.barbearias where id = v_barb;
  if p_data < (now() at time zone 'America/Sao_Paulo')::date or p_data > (now() at time zone 'America/Sao_Paulo')::date + 60 then
    raise exception 'Data fora do período de reservas';
  end if;
  if p_data + p_hora <= (now() at time zone 'America/Sao_Paulo') then
    raise exception 'Esse horário já passou';
  end if;
  if extract(dow from p_data)::int = any(v_b.dias_fechados) or p_hora < v_b.abre or p_hora >= v_b.fecha then
    raise exception 'A barbearia está fechada nesse horário';
  end if;
  insert into public.reservas (barbearia_id, barbeiro_id, servico_id, data, hora, cliente_nome, cliente_whatsapp)
  values (v_barb, p_barbeiro, p_servico, p_data, p_hora, trim(p_nome), v_zap)
  returning id into v_id;
  return v_id;
exception when unique_violation then
  raise exception 'Esse horário acabou de ser reservado. Escolha outro.';
end;
$$;

revoke all on function public.criar_reserva(uuid,uuid,date,time,text,text) from public;
grant execute on function public.criar_reserva(uuid,uuid,date,time,text,text) to anon, authenticated;
grant execute on function public.horarios_ocupados(uuid,date) to anon, authenticated;

-- Dados de exemplo: a JARL
with b as (
  insert into public.barbearias (slug, nome) values ('jarl', 'JARL Barbearia') returning id
), bar as (
  insert into public.barbeiros (barbearia_id, nome, especialidade, cor, ordem)
  select b.id, x.nome, x.esp, x.cor, x.o from b,
  (values ('Bjorn','Degradê e navalha','#7a3b22',1),('Leif','Barbas longas','#2f5563',2),('Sigrid','Cortes com tesoura','#a4221b',3)) as x(nome,esp,cor,o)
  returning 1
)
insert into public.servicos (barbearia_id, nome, descricao, duracao_min, preco, ordem)
select b.id, x.nome, x.descr, x.dur, x.preco, x.o from b,
(values
  ('Corte do Guerreiro','Corte na máquina e tesoura, lavagem e finalização',40,50,1),
  ('Barba do Jarl','Barba com toalha quente, navalha e óleo',30,40,2),
  ('Ritual de Valhalla','Corte + barba + hidromel sem álcool de cortesia',70,80,3),
  ('Navalha de Odin','Acabamento completo na navalha',30,35,4),
  ('Jovem Skald','Corte infantil até 12 anos',30,35,5),
  ('Pezinho do Escudeiro','Contorno e acabamento entre cortes',15,20,6)
) as x(nome,descr,dur,preco,o);

-- Depois de criar o usuário do barbeiro em Authentication > Users:
-- insert into public.membros (barbearia_id, user_id, papel)
-- select id, '<uuid do usuário>', 'dono' from public.barbearias where slug = 'jarl';
