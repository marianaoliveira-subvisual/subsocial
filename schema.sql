-- ── SubSocial schema ──
-- Run this in the Supabase SQL editor: https://supabase.com/dashboard/project/bgdyahjipkxwosbbkkqd/sql

-- 1. platforms
create table if not exists platforms (
  id    uuid primary key default gen_random_uuid(),
  slug  text unique not null,
  label text not null,
  color text not null
);

-- 2. reports
create table if not exists reports (
  id           uuid primary key default gen_random_uuid(),
  platform_id  uuid not null references platforms(id) on delete cascade,
  period_start date not null,
  period_end   date not null,
  source       text not null default 'manual',
  notes        text,
  created_at   timestamptz not null default now()
);

-- 3. metrics
create table if not exists metrics (
  id        uuid primary key default gen_random_uuid(),
  report_id uuid not null references reports(id) on delete cascade,
  key       text not null,
  value     text not null
);

-- Seed platforms
insert into platforms (slug, label, color) values
  ('linkedin', 'LinkedIn',    '#045CFC'),
  ('twitter',  'Twitter / X', '#403F4C'),
  ('bluesky',  'Bluesky',     '#9563FF'),
  ('youtube',  'YouTube',     '#D14040'),
  ('dribbble', 'Dribbble',    '#F3809C'),
  ('website',  'Website',     '#1B9A6A')
on conflict (slug) do nothing;

-- Enable Row Level Security
alter table platforms enable row level security;
alter table reports   enable row level security;
alter table metrics   enable row level security;

-- platforms: readable by anyone (anon + authenticated)
create policy "platforms_select"
  on platforms for select
  using (true);

-- reports: authenticated users only
create policy "reports_select"
  on reports for select
  to authenticated using (true);

create policy "reports_insert"
  on reports for insert
  to authenticated with check (true);

-- metrics: authenticated users only
create policy "metrics_select"
  on metrics for select
  to authenticated using (true);

create policy "metrics_insert"
  on metrics for insert
  to authenticated with check (true);
