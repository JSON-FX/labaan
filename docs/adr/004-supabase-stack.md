# ADR 004 — Firebase Auth + Supabase + PayMongo + Upstash serverless stack

**Status:** Accepted (mirrors spec §8)
**Date:** 2026-07-27

## Context

Spec §8 defines a serverless-first stack: Supabase for DB + Auth +
Realtime + Storage + Edge Functions, PayMongo for BSP-registered payments
(GCash / Maya / card), Upstash for Redis cache + QStash job queue, FCM
for push, Vercel for the admin dashboard hosting. Estimated MVP infra
cost: 0–3,200 ₱/mo.

We ratify the stack here (rather than re-litigating it) and record the
non-obvious mobile-side consequences.

## What each layer buys us

| Layer | Tech | Mobile-side impact |
|---|---|---|
| DB | Supabase Postgres | Row-Level Security (spec §11) enforced at DB — the mobile client can hit the DB directly with the anon key and RLS blocks unauthorized reads. |
| Auth | Firebase Auth + Supabase third-party Auth | Firebase provides Google and phone sign-in. Its ID token is passed to Supabase; `profiles.firebase_uid` maps the Firebase subject to the UUID used by application tables and RLS. |
| Realtime | Supabase Realtime | Bracket updates via WebSocket, scoped per `tournament_id` (spec §9.3). Riverpod `StreamProvider.autoDispose` ensures we unsubscribe on nav. |
| Storage | Supabase Storage | Match screenshots. Client uses pre-signed URLs (spec §11) — API server never touches bytes. |
| Cache | Upstash Redis | Leaderboards + hot tournament lists. Mobile reads through an RPC or the materialized view; no direct Redis touch from Flutter. |
| Job queue | Upstash QStash | Rank recalc, prize disbursement, push, badge award. Mobile enqueues indirectly through the Next.js API or Supabase Edge Functions. |
| Payments | PayMongo | BSP-registered. Every payment call carries an idempotency key (spec §9.3) — mobile generates the key and passes it through. |
| Push | Firebase Cloud Messaging | Free unlimited. `firebase_messaging` Dart plugin. Post-MVP wire-up. |
| Hosting | Vercel | Admin only. Mobile app doesn't touch it directly except for OAuth redirect. |

## Non-obvious constraints (spec §9.3)

- **Row-Level Security is mandatory**, not a nice-to-have. RLS policies
  live in `supabase/migrations/0003_rls.sql`. Any new table gets an
  `alter table … enable row level security` in the same migration that
  creates it.
- **Cursor-based pagination**, not offset. `SupabaseTournamentsRepo.browse`
  uses `(created_at, id)` seek pagination. Offset pagination breaks at
  thousands of records.
- **Realtime subs strictly per `tournament_id`.** Fan-out at scale kills
  the free tier. `bracketProvider` is `StreamProvider.autoDispose.family`
  so channels close on nav.
- **Financial records append-only.** `payments` + `disbursements` have
  triggers (`forbid_mutation`) that raise on any UPDATE/DELETE. The mobile
  app never mutates these directly — the register flow goes through an
  RPC that inserts a payment row inside a transaction.
- **Idempotency keys on every PayMongo call.** Client generates a UUID at
  Pay-CTA press time; server passes it through unchanged.

## Decision

**Ratify the stack in spec §8.** Mobile-side responsibilities land in this
repo; server-side responsibilities land in the Next.js admin repo. Both
sides speak Postgres + HTTP.

## Consequences

- **Positive**: minimal ops, generous free tiers cover MVP, one auth story
  across web + mobile.
- **Negative**: PayMongo Dart SDK is thin — payment flow goes through
  Next.js API routes rather than a native SDK. Adds one hop but keeps
  secrets off the client (which was the goal anyway).
- **Scale path**: spec §9.2 already lays out the Stage 2 (10k–500k users)
  and Stage 3 (millions) upgrades. Nothing in this ADR precludes those.
