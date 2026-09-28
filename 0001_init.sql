-- ============================================================
-- Outreach Tool — Initial schema
-- Free-tier Supabase Postgres. Designed so Day 2+ features
-- (duplicate detection, suppression checks, follow-up logic,
-- analytics) slot in without altering this core shape.
-- ============================================================

create extension if not exists "uuid-ossp";

-- ------------------------------------------------------------
-- Prospects
-- ------------------------------------------------------------
create table prospects (
  id uuid primary key default uuid_generate_v4(),
  email text not null,
  domain text generated always as (split_part(email, '@', 2)) stored,
  first_name text,
  last_name text,
  company text,
  source text,
  status text not null default 'new', -- new, validated, invalid, suppressed
  created_at timestamptz not null default now()
);

-- Enforces duplicate detection at the database level.
create unique index prospects_email_unique on prospects (lower(email));

-- ------------------------------------------------------------
-- Templates
-- ------------------------------------------------------------
create table templates (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  subject text not null,
  body text not null,       -- HTML, supports {{variable}} placeholders
  variables jsonb default '[]'::jsonb,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- Campaigns
-- ------------------------------------------------------------
create table campaigns (
  id uuid primary key default uuid_generate_v4(),
  name text not null,
  status text not null default 'draft', -- draft, active, paused, completed
  sending_window jsonb,      -- e.g. {"start": "09:00", "end": "17:00", "days": [1,2,3,4,5]}
  daily_limit integer default 50,
  created_at timestamptz not null default now()
);

-- Ordered steps within a campaign (initial email + follow-ups).
create table campaign_steps (
  id uuid primary key default uuid_generate_v4(),
  campaign_id uuid not null references campaigns(id) on delete cascade,
  step_order integer not null,
  template_id uuid not null references templates(id),
  delay_days integer not null default 0, -- days after previous step
  created_at timestamptz not null default now(),
  unique (campaign_id, step_order)
);

-- ------------------------------------------------------------
-- Suppression list (unsubscribes / opt-outs / blacklist)
-- ------------------------------------------------------------
create table suppression_list (
  id uuid primary key default uuid_generate_v4(),
  email text not null,
  reason text, -- unsubscribed, bounced, manual, complaint
  added_at timestamptz not null default now()
);

create unique index suppression_email_unique on suppression_list (lower(email));

-- ------------------------------------------------------------
-- Send queue
-- ------------------------------------------------------------
create table send_queue (
  id uuid primary key default uuid_generate_v4(),
  campaign_id uuid not null references campaigns(id) on delete cascade,
  prospect_id uuid not null references prospects(id) on delete cascade,
  step_id uuid not null references campaign_steps(id) on delete cascade,
  scheduled_at timestamptz not null,
  status text not null default 'pending', -- pending, sent, error, cancelled
  sent_at timestamptz,
  error text,
  created_at timestamptz not null default now()
);

create index send_queue_status_scheduled_idx on send_queue (status, scheduled_at);

-- ------------------------------------------------------------
-- Inbox events (replies / bounces detected via IMAP sync)
-- ------------------------------------------------------------
create table inbox_events (
  id uuid primary key default uuid_generate_v4(),
  prospect_id uuid references prospects(id) on delete set null,
  type text not null, -- reply, bounce
  category text,       -- e.g. interested, not_interested, auto_reply, bounce
  raw_snippet text,
  detected_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- App logs (local logging, no external logging service required)
-- ------------------------------------------------------------
create table app_logs (
  id uuid primary key default uuid_generate_v4(),
  level text not null default 'info', -- info, warn, error
  message text not null,
  context jsonb,
  created_at timestamptz not null default now()
);

-- ------------------------------------------------------------
-- Row Level Security
-- Single-user personal app: enable RLS and allow the service role
-- full access; no anon/public policies are created, so the anon key
-- has no access to these tables by default.
-- ------------------------------------------------------------
alter table prospects enable row level security;
alter table templates enable row level security;
alter table campaigns enable row level security;
alter table campaign_steps enable row level security;
alter table suppression_list enable row level security;
alter table send_queue enable row level security;
alter table inbox_events enable row level security;
alter table app_logs enable row level security;
