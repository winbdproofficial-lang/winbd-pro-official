-- WINBD-PRO backend: virtual points only. No real-money deposits/withdrawals.
create extension if not exists pgcrypto;
create table if not exists public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 username text unique,
 phone text,
 points integer not null default 1000 check(points >= 0),
 role text not null default 'user' check(role in ('user','admin')),
 last_bonus_at timestamptz,
 created_at timestamptz not null default now()
);
create table if not exists public.games (
 id uuid primary key default gen_random_uuid(), name text not null, category text not null,
 icon text default '🎮', enabled boolean not null default true, created_at timestamptz not null default now()
);
create table if not exists public.reward_settings (key text primary key, value jsonb not null);

alter table public.profiles enable row level security;
alter table public.games enable row level security;
alter table public.reward_settings enable row level security;

drop policy if exists "profile owner" on public.profiles;
drop policy if exists "public game read" on public.games;
drop policy if exists "admin game write" on public.games;
drop policy if exists "admin reward write" on public.reward_settings;
create policy "profile owner read" on public.profiles for select using(auth.uid()=id);
create policy "profile owner update" on public.profiles for update using(auth.uid()=id) with check(auth.uid()=id);
create policy "public enabled games" on public.games for select using(enabled=true);
create policy "admin games" on public.games for all using(exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin')) with check(exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'));
create policy "admin reward settings" on public.reward_settings for all using(exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin')) with check(exists(select 1 from public.profiles p where p.id=auth.uid() and p.role='admin'));

create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path=public as $$
begin insert into public.profiles(id,username) values(new.id,coalesce(new.raw_user_meta_data->>'username',split_part(new.email,'@',1))) on conflict(id) do nothing; return new; end; $$;
drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();

insert into public.reward_settings(key,value) values('daily_bonus','100'::jsonb) on conflict(key) do nothing;
insert into public.games(name,category,icon) values
('Lucky 777','স্লট','7️⃣'),('Royal Treasure','স্লট','♛'),('Fortune Tiger','স্পিন','🐯'),('Diamond Rush','আর্কেড','💎'),('Dragon Legend','ফিশিং','🐉')
on conflict do nothing;

create or replace function public.claim_daily_bonus() returns jsonb language plpgsql security definer set search_path=public as $$
declare uid uuid:=auth.uid(); amount integer:=100; old_ts timestamptz; new_points integer;
begin
 if uid is null then raise exception 'Login required'; end if;
 select last_bonus_at into old_ts from public.profiles where id=uid for update;
 select coalesce((value#>>'{}')::integer,100) into amount from public.reward_settings where key='daily_bonus';
 if old_ts is not null and old_ts > now()-interval '24 hours' then raise exception 'Daily bonus already claimed'; end if;
 update public.profiles set points=points+amount,last_bonus_at=now() where id=uid returning points into new_points;
 return jsonb_build_object('bonus',amount,'points',new_points);
end; $$;
grant execute on function public.claim_daily_bonus() to authenticated;
