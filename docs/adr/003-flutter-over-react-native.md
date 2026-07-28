# ADR 003 — Flutter over React Native

**Status:** Accepted (user override of spec §8)
**Date:** 2026-07-26

## Context

Spec §8 specifies **React Native (Expo)** for the mobile app. The primary
developer's stronger stack is Flutter, and the spec's rationale for RN
("single iOS + Android codebase, Expo managed workflow, fast iteration") is
equally satisfied by Flutter. Overriding a spec choice is worth calling out
so the trade-off is explicit.

## What the spec's RN choice gets us

- One JS/TS codebase across iOS + Android.
- Expo's managed workflow — no native build headaches for solo dev.
- Familiar ecosystem for a JS-first team.

## What Flutter gets us instead

- One Dart codebase across iOS + Android + web (relevant for spec §7.2
  admin dashboard if we ever want to share widgets with the Next.js side,
  though we don't today).
- Compiled-to-native performance from day one — no bridge overhead. For a
  Realtime-heavy UI (bracket updates, live scoreboards), this matters.
- Stricter static typing than TypeScript — Dart's sound null safety +
  sealed classes catch bugs at compile time.
- The primary developer is faster in Flutter, which is the single biggest
  velocity lever for a solo-dev 16-week MVP.

## What we lose

- Fewer publicly-available components for niche use cases (though the
  Labaan HiFi is bespoke enough that we build everything from primitives
  anyway).
- No Expo — hot-reload / OTA-update / crash reporting all need first-party
  setup (Flutter DevTools + Firebase Crashlytics can cover this).

## Decision

**Use Flutter for the mobile app.** Every other layer of spec §8 stays
unchanged: Next.js admin, Supabase, PayMongo, Upstash, FCM, Vercel. Only
the client language differs.

## Consequences

- **Positive**: velocity gain from developer expertise, better perf ceiling
  for Realtime UIs, sharper type system.
- **Negative**: no Expo — need to set up native build once. Manageable.
- **Contract with backend**: unchanged. Supabase / PayMongo / FCM speak
  HTTP + WebSocket; Dart clients exist for all three. Backend engineers
  don't need to know the mobile stack.
