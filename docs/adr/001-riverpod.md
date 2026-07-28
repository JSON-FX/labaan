# ADR 001 — Riverpod for state management

**Status:** Accepted
**Date:** 2026-07-27

## Context

The mobile app is stateful in every non-trivial way: current auth session,
tournament lists that stream from the server, in-flight registration
payments, notification feed, per-screen filter/query state. We need one
state-management approach the whole codebase uses so screens compose
cleanly, testing is straightforward, and swapping the backend from mocks to
Supabase doesn't ripple through screen code.

## Options considered

- **Vanilla `setState` + InheritedWidgets** — fine for tiny apps, but
  passing repositories manually through 12 screens becomes rewrite-inducing
  boilerplate. No first-class support for async loading/error states.
- **Provider (the original `provider` package)** — solid, but no
  `.family` variants, awkward for parameterized queries (e.g. tournament by
  slug), and its API pushes toward Change­Notifier which we don't need.
- **Bloc / flutter_bloc** — great for large teams with strict
  event-sourcing needs, but heavy ceremony for a solo-dev MVP.
- **Riverpod 3** — provider composition without BuildContext, first-class
  `AsyncValue` for loading/error/data, `.family` for parameterized
  providers, `autoDispose` for stream lifecycle (critical for
  per-tournament Realtime subscriptions per spec §9.3).

## Decision

**Riverpod 3.** Screens are `ConsumerWidget` / `ConsumerStatefulWidget`.
Every repository is exposed via a `Provider`. Every screen's data is a
`FutureProvider.autoDispose.family<T, Q>` or
`StreamProvider.autoDispose.family<T, Q>`. Overrides in
`ProviderScope(overrides: [...])` handle test injection.

## Consequences

- **Positive**: async state trivial via `AsyncValue.when`; test injection
  clean; `autoDispose` naturally satisfies spec §9.3 (Realtime channels
  release on nav-away); `.family` handles cursor-paginated + query-driven
  screens without global mutable state.
- **Negative**: Riverpod's API is idiosyncratic — new contributors need
  ~1 hour to grasp `ref.watch` vs `ref.read` and provider lifecycles. We
  accept this cost; the alternative (context.of<Bloc>) has its own learning
  curve of the same size.
