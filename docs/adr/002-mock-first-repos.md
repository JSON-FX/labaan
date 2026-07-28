# ADR 002 — Mock-first repositories

**Status:** Accepted
**Date:** 2026-07-27

## Context

We started the Flutter app before the Supabase backend existed. Two options:
build against a stubbed API surface that resembles what the backend will
eventually be, or build screens with hard-coded data and refactor later.
Choose one and commit — half-measures produce two rewrites.

## Options considered

- **Hard-code fixtures inside screen widgets.** Fast to start, painful to
  swap: every screen holds its own mutable state, no seams for real data,
  every migration touches N screens.
- **Repository interfaces + Mock implementations behind them from day one.**
  Screens depend on `TournamentsRepo`, `ProfileRepo`, ... — abstract Dart
  interfaces. `MockTournamentsRepo`, `MockProfileRepo`, ... implement them
  with in-memory fixture data + realistic latency. Riverpod binds
  `Provider<TournamentsRepo>((ref) => MockTournamentsRepo())`.
- **Type-generated OpenAPI client.** No spec yet; would gate frontend on
  backend. Rejected.

## Decision

**Repository interfaces + Mock implementations, from screen #1.**

- One interface per feature area (`AuthRepo`, `TournamentsRepo`,
  `MyTournamentsRepo`, `BracketRepo`, `RegistrationRepo`, `ResultsRepo`,
  `ProfileRepo`, `TeamsRepo`, `PlayersRepo`, `LeaderboardRepo`,
  `NotificationsRepo`).
- Live in [lib/core/data/repos.dart](../../lib/core/data/repos.dart).
- Mock impls in [lib/core/data/mock_repos.dart](../../lib/core/data/mock_repos.dart)
  return `Future`s and `Stream`s from
  [fixtures.dart](../../lib/core/data/fixtures.dart) with 320ms read /
  520ms write latency so screen loading states are visible in dev.
- Supabase impls in
  [lib/core/data/supabase_repos.dart](../../lib/core/data/supabase_repos.dart)
  hit the real DB via the Supabase Dart SDK.

Swap = one line per repo in
[providers.dart](../../lib/core/data/providers.dart).

## Consequences

- **Positive**: screens shipped and demoed before backend exists; every
  test runs against the mock impl offline; contract with backend team is
  literally the Dart interface file — easy to review.
- **Negative**: two impls to maintain per repo. Mitigated by keeping the
  mock impls small (~30 LOC each) and only enriching them when a new UX
  need demands it.
- **Positive side-effect**: forced the repo interfaces to be UX-shaped, not
  DB-shaped — the `LbHomeFeed` composed view, cursor pagination in
  `browse()`, etc. — which improves the real backend's query design too.
