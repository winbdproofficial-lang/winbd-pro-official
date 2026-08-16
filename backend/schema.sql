-- Run in Supabase SQL Editor. This schema is for virtual in-app points only.
create table if not exists profiles (id uuid primary key references auth.users on delete cascade, username text unique, phone text, points integer not null default 1000, role text not null default 'user', created_at timestamptz default now());
create table if not exists games (id uuid primary key default gen_random_uuid(), name text not null, category text not null, icon text default '🎮', enabled boolean default true, created_at timestamptz default now());
create table if not exists reward_settings (key text primary key, value jsonb not null);
create table if not exists point_requests (id uuid primary key default gen_random_uuid(), user_id uuid references profiles(id), type text check(type in ('topup','redeem')), amount integer check(amount>0), status text default 'pending', created_at timestamptz default now());
alter table profiles enable row level security; alter table games enable row level security; alter table reward_settings enable row level security; alter table point_requests enable row level security;
create policy "public game read" on games for select using (enabled=true);
create policy "profile owner" on profiles for all using (auth.uid()=id) with check(auth.uid()=id);
create policy "own request" on point_requests for all using (auth.uid()=user_id) with check(auth.uid()=user_id);
