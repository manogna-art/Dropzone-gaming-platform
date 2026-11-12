-- DropZone Free-entry gaming giveaways — Supabase schema
create extension if not exists pgcrypto;
create type public.user_role as enum ('user','admin');
create type public.giveaway_status as enum ('draft','active','closed','drawn');
create type public.ticket_status as enum ('eligible','winner','void');

create table public.profiles(
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default 'Player',
 role public.user_role not null default 'user',
 created_at timestamptz not null default now()
);
create table public.giveaways(
 id uuid primary key default gen_random_uuid(),
 title text not null,
 prize text not null,
 game text not null default 'Gaming',
 description text,
 slots integer not null check(slots > 0),
 status public.giveaway_status not null default 'draft',
 ends_at timestamptz,
 winner_ticket_id uuid,
 created_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);
create table public.tickets(
 id uuid primary key default gen_random_uuid(),
 giveaway_id uuid not null references public.giveaways(id) on delete cascade,
 user_id uuid not null references public.profiles(id) on delete cascade,
 number bigint generated always as identity,
 status public.ticket_status not null default 'eligible',
 granted_by uuid references auth.users(id),
 created_at timestamptz not null default now()
);
create table public.draws(
 id uuid primary key default gen_random_uuid(),
 giveaway_id uuid not null unique references public.giveaways(id),
 ticket_id uuid not null references public.tickets(id),
 winner_user_id uuid not null references public.profiles(id),
 drawn_by uuid not null references auth.users(id),
 drawn_at timestamptz not null default now(),
 random_value double precision not null
);
create table public.audit_logs(
 id uuid primary key default gen_random_uuid(),
 actor_id uuid references auth.users(id),
 action text not null,
 entity_id uuid,
 details jsonb not null default '{}'::jsonb,
 created_at timestamptz not null default now()
);
alter table public.giveaways add constraint giveaways_winner_ticket_fk foreign key(winner_ticket_id) references public.tickets(id);

create or replace function public.on_auth_user_created() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,display_name) values(new.id,coalesce(new.raw_user_meta_data->>'display_name',split_part(new.email,'@',1))); return new; end; $$;
create trigger auth_user_profile after insert on auth.users for each row execute procedure public.on_auth_user_created();

create or replace function public.is_admin() returns boolean language sql stable security definer set search_path=public as $$
 select exists(select 1 from public.profiles where id=auth.uid() and role='admin');
$$;

alter table public.profiles enable row level security;
alter table public.giveaways enable row level security;
alter table public.tickets enable row level security;
alter table public.draws enable row level security;
alter table public.audit_logs enable row level security;

create policy "profiles read self or admin" on public.profiles for select using(id=auth.uid() or public.is_admin());
create policy "profile update self display only" on public.profiles for update using(id=auth.uid()) with check(id=auth.uid() and role='user');
create policy "giveaways public read" on public.giveaways for select using(status in ('active','closed','drawn') or public.is_admin());
create policy "admin creates giveaways" on public.giveaways for insert with check(public.is_admin());
create policy "admin updates giveaways" on public.giveaways for update using(public.is_admin()) with check(public.is_admin());
create policy "tickets user own or admin read" on public.tickets for select using(user_id=auth.uid() or public.is_admin());
create policy "draws public read" on public.draws for select using(true);
create policy "audit admin read" on public.audit_logs for select using(public.is_admin());

-- Grant tickets only via this SECURITY DEFINER function; admin auth is checked inside.
create or replace function public.admin_grant_tickets(p_giveaway_id uuid,p_user_email text,p_quantity integer)
returns integer language plpgsql security definer set search_path=public as $$
declare target uuid; g public.giveaways%rowtype; existing_count integer; i integer;
begin
 if not public.is_admin() then raise exception 'Admin permission required'; end if;
 if p_quantity < 1 or p_quantity > 100 then raise exception 'Quantity must be 1..100'; end if;
 select id into target from auth.users where lower(email)=lower(p_user_email);
 if target is null then raise exception 'User email not registered'; end if;
 select * into g from public.giveaways where id=p_giveaway_id for update;
 if g.id is null then raise exception 'Giveaway not found'; end if;
 if g.status <> 'active' then raise exception 'Giveaway is not active'; end if;
 select count(*) into existing_count from public.tickets where giveaway_id=p_giveaway_id and status <> 'void';
 if existing_count+p_quantity > g.slots then raise exception 'Entry capacity would be exceeded'; end if;
 for i in 1..p_quantity loop insert into public.tickets(giveaway_id,user_id,granted_by) values(p_giveaway_id,target,auth.uid()); end loop;
 insert into public.audit_logs(actor_id,action,entity_id,details) values(auth.uid(),'grant_tickets',p_giveaway_id,jsonb_build_object('email',p_user_email,'quantity',p_quantity));
 return p_quantity;
end; $$;
grant execute on function public.admin_grant_tickets(uuid,text,integer) to authenticated;

-- Draw only eligible entries; one unique draw per giveaway, records random score and result.
create or replace function public.admin_run_draw(p_giveaway_id uuid)
returns json language plpgsql security definer set search_path=public as $$
declare g public.giveaways%rowtype; selected public.tickets%rowtype; score double precision;
begin
 if not public.is_admin() then raise exception 'Admin permission required'; end if;
 select * into g from public.giveaways where id=p_giveaway_id for update;
 if g.id is null then raise exception 'Giveaway not found'; end if;
 if g.status not in ('active','closed') then raise exception 'Giveaway must be active or closed'; end if;
 if exists(select 1 from public.draws where giveaway_id=p_giveaway_id) then raise exception 'Draw already exists'; end if;
 select t.*, random() as r into selected, score from public.tickets t where t.giveaway_id=p_giveaway_id and t.status='eligible' order by random() limit 1;
 if selected.id is null then raise exception 'No eligible tickets'; end if;
 update public.tickets set status='winner' where id=selected.id;
 update public.giveaways set status='drawn',winner_ticket_id=selected.id where id=p_giveaway_id;
 insert into public.draws(giveaway_id,ticket_id,winner_user_id,drawn_by,random_value) values(p_giveaway_id,selected.id,selected.user_id,auth.uid(),score);
 insert into public.audit_logs(actor_id,action,entity_id,details) values(auth.uid(),'run_draw',p_giveaway_id,jsonb_build_object('ticket_id',selected.id,'winner_user_id',selected.user_id));
 return json_build_object('ticket_id',selected.id,'ticket_number',selected.number,'winner_user_id',selected.user_id,'drawn_at',now());
end; $$;
grant execute on function public.admin_run_draw(uuid) to authenticated;

-- Restrict direct ticket writes: RLS policies intentionally do not permit user/admin direct insert/update.
