-- Radiant: database schema, security rules and realtime setup.
-- Run this once in the Supabase dashboard: SQL Editor -> New query -> paste -> Run.

-- ---------------------------------------------------------------------------
-- Tables
-- ---------------------------------------------------------------------------

-- One row per intersection: the summary cards on both Event Log screens.
create table if not exists public.intersections (
  id                     int primary key,
  name                   text not null,
  mode                   text not null default 'normal'
                         check (mode in ('normal', 'emergency', 'idle')),
  vehicles_today         int  not null default 0,
  emergency_alerts_today int  not null default 0,
  updated_at             timestamptz not null default now()
);

-- Full live snapshot (lane counts, signals, agent text). Admin only.
create table if not exists public.intersection_live (
  intersection_id int primary key references public.intersections (id) on delete cascade,
  frame           jsonb not null,
  updated_at      timestamptz not null default now()
);

-- The Event Log.
create table if not exists public.events (
  id              bigint generated always as identity primary key,
  occurred_at     timestamptz not null,
  intersection_id int  not null references public.intersections (id) on delete cascade,
  lane            text not null,
  type            text not null
                  check (type in ('densityAdjust', 'emergencyDetected', 'idleMode', 'pedestrianCrossing')),
  description     text not null
);

create index if not exists events_occurred_at_idx
  on public.events (occurred_at desc);
create index if not exists events_intersection_idx
  on public.events (intersection_id, occurred_at desc);

-- One row per intersection while an emergency vehicle is approaching.
-- Drivers read this for the banner, the alert screen and the notification.
create table if not exists public.active_emergencies (
  intersection_id int primary key references public.intersections (id) on delete cascade,
  payload         jsonb not null,
  updated_at      timestamptz not null default now()
);

insert into public.intersections (id, name) values
  (1, 'Intersection 01'),
  (2, 'Intersection 02'),
  (3, 'Intersection 03'),
  (4, 'Intersection 04'),
  (5, 'Intersection 05')
on conflict (id) do nothing;

-- ---------------------------------------------------------------------------
-- Security (row level security)
--
-- Nobody using the app can write anything. Only the simulator, which uses the
-- secret/service key and bypasses these rules, writes data.
--
--   drivers (no login, role "anon")  -> summaries, events, active emergencies
--   authorized users (signed in)     -> everything, including live lane data
-- ---------------------------------------------------------------------------

alter table public.intersections       enable row level security;
alter table public.intersection_live   enable row level security;
alter table public.events              enable row level security;
alter table public.active_emergencies  enable row level security;

drop policy if exists "read intersections" on public.intersections;
create policy "read intersections" on public.intersections
  for select to anon, authenticated using (true);

drop policy if exists "read events" on public.events;
create policy "read events" on public.events
  for select to anon, authenticated using (true);

drop policy if exists "read active emergencies" on public.active_emergencies;
create policy "read active emergencies" on public.active_emergencies
  for select to anon, authenticated using (true);

-- Live monitor data: signed-in, non-anonymous users only.
drop policy if exists "authorized read live" on public.intersection_live;
create policy "authorized read live" on public.intersection_live
  for select to authenticated
  using (coalesce((auth.jwt() ->> 'is_anonymous')::boolean, false) = false);

-- Belt and braces: remove write permissions from the app roles entirely.
revoke insert, update, delete, truncate
  on public.intersections, public.intersection_live,
     public.events, public.active_emergencies
  from anon, authenticated;

-- ---------------------------------------------------------------------------
-- Realtime: lets the app subscribe to changes instead of polling.
-- If you see "relation ... is already member of publication", that is fine.
-- ---------------------------------------------------------------------------

alter publication supabase_realtime add table public.intersections;
alter publication supabase_realtime add table public.intersection_live;
alter publication supabase_realtime add table public.events;
alter publication supabase_realtime add table public.active_emergencies;
