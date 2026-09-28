# Outreach Tool — Day 1 Starter

A personal cold-outreach/campaign management app. Built free-first and
host-portable: it runs the same on Vercel, a plain VPS, or Hostinger
Business Web Hosting (Node.js) without rewriting anything.

## Stack

- **Next.js (App Router)** — Node.js runtime only, no Edge Runtime, no
  platform-specific adapters
- **Supabase (free tier)** — Postgres + Auth + RLS
- **Nodemailer** — sends through your own SMTP mailbox
- **imapflow / mailparser** — reads your own IMAP mailbox for replies/bounces
- **node-cron** — in-process scheduling (or trigger via your host's own
  cron-to-URL feature instead — see below)
- **Native `dns` module** — MX record validation, no paid verification API
- **Claude API** — fully optional; the app runs completely fine without it

## Getting started

```bash
npm install
cp .env.example .env   # fill in your Supabase + SMTP + IMAP credentials
```

Run the Supabase migration (`supabase/migrations/0001_init.sql`) against
your project — either via the Supabase SQL editor or the Supabase CLI.

```bash
npm run dev
```

## Running background jobs (queue processing, inbox sync)

Two portable options, pick whichever fits your host:

**Option A — standalone process** (good for a VPS or any host that lets
you keep a process running):

```bash
npm run jobs
```

This runs `lib/jobs/runner.ts`, which schedules itself every 5 minutes
using `node-cron` — no external scheduler needed.

**Option B — HTTP-triggered** (good for shared hosting, like Hostinger,
that offers a "hit this URL every N minutes" cron feature instead of a
persistent process):

Point your host's cron feature at `POST /api/internal/run-jobs` with
header `x-internal-secret: <INTERNAL_JOBS_SECRET from .env>`.

Neither option depends on Vercel Cron or any other platform-specific
scheduler, so switching hosts later doesn't require touching this logic.

## Architecture: swappable service interfaces

Every component that could someday involve a paid service is written
against a plain interface, with a free implementation as the default:

```
lib/services/
  email-sender/   -> EmailSender interface, SMTP implementation (Day 1)
  inbox-reader/   -> InboxReader interface, IMAP implementation (Day 1)
  validation/     -> EmailValidator interface, DNS/MX + disposable-list (Day 1)
  ai/             -> AIProvider interface, no-op by default, Claude if
                     ANTHROPIC_API_KEY is set
```

The rest of the app (job scripts, future UI, API routes) only ever
imports the interface, never a concrete vendor class. Adding a paid
provider later — or replacing your mailbox with a transactional email
service — means adding one new file and changing a factory function,
not touching the rest of the codebase.

## What's intentionally NOT built yet

This is a Day 1 scaffold, not a full app. Deliberately deferred:

- UI for managing prospects/campaigns/templates (currently DB + jobs only)
- Sending-window / daily-limit / random-delay enforcement in the queue
  processor (the loop structure is there; the checks are marked as
  Day 2 in code comments)
- Matching inbox replies back to a specific prospect/campaign
- CSV import/export
- Duplicate detection UI (the DB already enforces it via a unique index)
- Follow-up auto-cancellation on reply
- Analytics/dashboards

All of these were designed for in the schema and service boundaries
above so they can be added without restructuring what's here.

## Environment variables

See `.env.example` — it separates:

1. **Required, free** — Supabase + your own SMTP/IMAP mailbox
2. **Optional** — `ANTHROPIC_API_KEY` (AI features, app works without it)
3. **Notes on third-party limits** — DNS/MX lookups and the disposable
   domain list, both free but worth being aware of at scale
